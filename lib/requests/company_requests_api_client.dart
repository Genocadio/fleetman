import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../auth/access_api_client.dart';
import '../core/app_config.dart';
import 'request_models.dart';

/// Fleet-Manager-facing client for the request queues of their own company.
///
/// The gateway enforces company scope on every call and restricts approve /
/// reject to FLEET_MANAGER, SUPERVISOR and ADMIN roles; self-approval is
/// rejected by the backend as well.
abstract class CompanyRequestsApi {
  Future<List<CompanyRequestItem>> fetchRequests(
    String accessToken, {
    required int companyId,
    bool pendingOnly = false,
  });

  Future<CompanyRequestItem> approve(
    String accessToken,
    CompanyRequestItem request,
  );

  Future<CompanyRequestItem> reject(
    String accessToken,
    CompanyRequestItem request, {
    String? reason,
  });
}

class CompanyRequestsApiClient implements CompanyRequestsApi {
  CompanyRequestsApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  static const String _noInternetMessage =
      'No internet connection. Please check your network and try again.';

  Map<String, String> _headers(String token) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json; charset=utf-8',
    'Authorization': 'Bearer $token',
  };

  /// Every transport failure is normalised into an [AccessApiException] so the
  /// controller never has to guess how to display an error. There is no retry
  /// here: a failed action stays failed until the user acts again.
  Future<http.Response> _send(Future<http.Response> Function() send) async {
    try {
      return await send();
    } on AccessApiException {
      rethrow;
    } catch (e) {
      final lower = e.toString().toLowerCase();
      final noInternet =
          e is SocketException ||
          lower.contains('failed host lookup') ||
          lower.contains('no address associated with hostname') ||
          lower.contains('network is unreachable') ||
          lower.contains('connection timed out') ||
          lower.contains('clientexception');
      throw AccessApiException(
        noInternet
            ? _noInternetMessage
            : 'Could not reach the server. ${e.toString()}',
        isTransient: true,
      );
    }
  }

  dynamic _decode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  String _errorMessage(http.Response response) {
    final decoded = _decode(response.body);
    if (decoded is Map<String, dynamic>) {
      final message =
          decoded['message'] ?? decoded['error'] ?? decoded['detail'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
      if (message is List && message.isNotEmpty) {
        return message.map((e) => e.toString()).join(', ');
      }
    }
    if (decoded is String && decoded.trim().isNotEmpty) {
      return decoded.trim();
    }
    return _statusMessage(response.statusCode);
  }

  String _statusMessage(int status) {
    return switch (status) {
      400 =>
        'The request could not be completed. Please check the details and try again.',
      403 => 'You do not have permission to perform this action.',
      404 => 'This request no longer exists.',
      409 => 'This request was already handled by another manager.',
      >= 500 =>
        'The server is temporarily unavailable. Please try again later.',
      _ => 'Request failed (HTTP $status)',
    };
  }

  /// 401 means the session expired and must be signed out. 403 is a permission
  /// problem — signing the manager out would hide the real cause.
  void _throwForStatus(http.Response response) {
    if (response.statusCode == 401) {
      throw const AccessApiUnauthorizedException();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw AccessApiException(
      _errorMessage(response),
      statusCode: response.statusCode,
      isTransient: response.statusCode >= 500,
    );
  }

  @override
  Future<List<CompanyRequestItem>> fetchRequests(
    String accessToken, {
    required int companyId,
    bool pendingOnly = false,
  }) async {
    final path = pendingOnly
        ? '/main/company-access-requests/company/$companyId/pending'
        : '/main/company-access-requests/company/$companyId';
    final access = await _send(
      () => _httpClient.get(
          Uri.parse('${AppConfig.baseUrl}$path'),
          headers: _headers(accessToken),
      ),
    );
    _throwForStatus(access);

    final pathDriver = pendingOnly
        ? '/main/driver-requests/company/$companyId/pending'
        : '/main/driver-requests/company/$companyId';
    http.Response? driver;
    try {
      driver = await _send(
        () => _httpClient.get(
            Uri.parse('${AppConfig.baseUrl}$pathDriver'),
            headers: _headers(accessToken),
        ),
      );
      _throwForStatus(driver);
    } on AccessApiException {
      // Driver requests are a separate queue; if that endpoint is unavailable
      // the role-access queue must still be usable. An expired session still
      // propagates from the first (role-access) call above.
      driver = null;
    }

    final items = <CompanyRequestItem>[];
    final accessBody = _decode(access.body);
    if (accessBody is List) {
      for (final raw in accessBody) {
        if (raw is Map) {
          items.add(
            CompanyRequestItem.fromAccessJson(raw.cast<String, dynamic>()),
          );
        }
      }
    }
    if (driver != null) {
      final driverBody = _decode(driver.body);
      if (driverBody is List) {
        for (final raw in driverBody) {
          if (raw is Map) {
            items.add(
              CompanyRequestItem.fromDriverJson(raw.cast<String, dynamic>()),
            );
          }
        }
      }
    }

    items.sort((a, b) {
      final aDate =
          DateTime.tryParse(a.createdAt ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          DateTime.tryParse(b.createdAt ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return items;
  }

  @override
  Future<CompanyRequestItem> approve(
    String accessToken,
    CompanyRequestItem request,
  ) async {
    final path = _actionPath(request, 'approve');
    final response = await _send(
      () => _httpClient.post(
          Uri.parse('${AppConfig.baseUrl}$path'),
          headers: _headers(accessToken),
      ),
    );
    _throwForStatus(response);
    return _parseSingle(response.body, request);
  }

  @override
  Future<CompanyRequestItem> reject(
    String accessToken,
    CompanyRequestItem request, {
    String? reason,
  }) async {
    final path = _actionPath(request, 'reject');
    final response = await _send(
      () => _httpClient.post(
          Uri.parse('${AppConfig.baseUrl}$path'),
          headers: _headers(accessToken),
          body: jsonEncode({'reason': reason?.trim() ?? ''}),
      ),
    );
    _throwForStatus(response);
    return _parseSingle(response.body, request);
  }

  String _actionPath(CompanyRequestItem request, String action) {
    final base = request.kind == CompanyRequestKind.driver
        ? '/main/driver-requests'
        : '/main/company-access-requests';
    return '$base/${request.id}/$action';
  }

  CompanyRequestItem _parseSingle(String body, CompanyRequestItem fallback) {
    final decoded = _decode(body);
    if (decoded is! Map<String, dynamic>) return fallback;
    return fallback.kind == CompanyRequestKind.driver
        ? CompanyRequestItem.fromDriverJson(decoded)
        : CompanyRequestItem.fromAccessJson(decoded);
  }
}
