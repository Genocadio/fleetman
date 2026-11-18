import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import 'auth_models.dart';

class AccessApiException implements Exception {
  const AccessApiException(
    this.message, {
    this.statusCode,
    this.isTransient = false,
  });

  final String message;
  final int? statusCode;
  final bool isTransient;

  @override
  String toString() => 'AccessApiException: $message';
}

class AccessApiUnauthorizedException extends AccessApiException {
  const AccessApiUnauthorizedException()
    : super('Your session has expired. Please sign in again.', statusCode: 401);
}

/// Result of GET /main/company-access-requests/my-status. HTTP 204 means the
/// user has never submitted a request; an error must NOT be treated as "none".
class AccessRequestLookup {
  const AccessRequestLookup._({
    this.request,
    this.error,
    required this.found,
  });

  final AccessRequestDto? request;
  final String? error;
  final bool found;

  factory AccessRequestLookup.none() =>
      const AccessRequestLookup._(found: false);
  factory AccessRequestLookup.found(AccessRequestDto request) =>
      AccessRequestLookup._(found: true, request: request);
  factory AccessRequestLookup.error(String message) =>
      AccessRequestLookup._(found: false, error: message);
}

/// Testable seam for the access API used by [FleetAccessController].
abstract class AccessApi {
  Future<SyncProfileDto> fetchSyncProfile(String accessToken);

  Future<AccessRequestLookup> fetchMyAccessRequest(String accessToken);

  Future<AccessRequestDto> requestFleetManagerAccess(
    String accessToken,
    String companyCode,
  );
}

class AccessApiClient implements AccessApi {
  AccessApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  static const String _noInternetMessage =
      'No internet connection. Please check your network and try again.';

  Map<String, String> _headers(String accessToken) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json; charset=utf-8',
    'Authorization': 'Bearer $accessToken',
  };

  Future<http.Response> _send(
    Future<http.Response> Function() send,
  ) async {
    try {
      return await send();
    } on SocketException {
      throw const AccessApiException(_noInternetMessage, isTransient: true);
    } catch (e) {
      final lower = e.toString().toLowerCase();
      if (lower.contains('failed host lookup') ||
          lower.contains('no address associated with hostname') ||
          lower.contains('network is unreachable')) {
        throw const AccessApiException(_noInternetMessage, isTransient: true);
      }
      rethrow;
    }
  }

  Map<String, dynamic> _decodeBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // fall through
    }
    return <String, dynamic>{};
  }

  void _throwForStatus(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const AccessApiUnauthorizedException();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final decoded = _decodeBody(response.body);
    final message = decoded['message'] as String? ??
        decoded['error'] as String? ??
        'Request failed (HTTP ${response.statusCode})';
    throw AccessApiException(
      message,
      statusCode: response.statusCode,
      isTransient: response.statusCode >= 500,
    );
  }

  /// Single current-user profile entry point for /main data.
  @override
  Future<SyncProfileDto> fetchSyncProfile(String accessToken) async {
    final response = await _send(() => _httpClient.post(
          Uri.parse('${AppConfig.baseUrl}/main/users/sync'),
          headers: _headers(accessToken),
          body: '{}',
        ));
    _throwForStatus(response);
    return SyncProfileDto.fromJson(_decodeBody(response.body));
  }

  /// GET /main/company-access-requests/my-status — 204 means no request.
  @override
  Future<AccessRequestLookup> fetchMyAccessRequest(String accessToken) async {
    final response = await _send(() => _httpClient.get(
          Uri.parse('${AppConfig.baseUrl}/main/company-access-requests/my-status'),
          headers: _headers(accessToken),
        ));
    if (response.statusCode == 204) return AccessRequestLookup.none();
    try {
      _throwForStatus(response);
    } on AccessApiException catch (e) {
      return AccessRequestLookup.error(e.message);
    }
    final decoded = _decodeBody(response.body);
    if (decoded.isEmpty) return AccessRequestLookup.none();
    return AccessRequestLookup.found(AccessRequestDto.fromJson(decoded));
  }

  /// POST /main/company-access-requests with the company code. Approval assigns
  /// the user to the company and grants the requested role in Nexxauth — the
  /// FLEET_MANAGER role is preserved only when the requester already holds a
  /// staff role in Nexxauth; other users are approved as WORKER.
  @override
  Future<AccessRequestDto> requestFleetManagerAccess(
    String accessToken,
    String companyCode,
  ) async {
    final response = await _send(() => _httpClient.post(
          Uri.parse('${AppConfig.baseUrl}/main/company-access-requests'),
          headers: _headers(accessToken),
          body: jsonEncode({'companyCode': companyCode.trim()}),
        ));
    _throwForStatus(response);
    final decoded = _decodeBody(response.body);
    if (decoded.isEmpty) {
      throw const AccessApiException('The access request was not accepted.');
    }
    return AccessRequestDto.fromJson(decoded);
  }
}
