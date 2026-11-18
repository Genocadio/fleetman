import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../auth/access_api_client.dart';
import '../core/app_config.dart';
import 'office_models.dart';

/// Company-scoped office operations for the signed-in Fleet Manager.
///
/// The backend requires `name`, `locationId` and a resolvable company. The
/// company id is passed in explicitly so it can only come from the session.
abstract class OfficesApi {
  Future<List<OfficeItem>> fetchOffices(
    String accessToken, {
    required int companyId,
  });

  Future<OfficeItem> createOffice(
    String accessToken, {
    required int companyId,
    required OfficeDraft draft,
  });
}

class OfficesApiClient implements OfficesApi {
  OfficesApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  static const String _noInternetMessage =
      'No internet connection. Please check your network and try again.';

  Map<String, String> _headers(String token) => <String, String>{
    'Accept': 'application/json',
    'Content-Type': 'application/json; charset=utf-8',
    'Authorization': 'Bearer $token',
  };

  Future<http.Response> _send(Future<http.Response> Function() send) async {
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
      final message = decoded['message'] ?? decoded['error'];
      if (message != null) return message.toString();
    }
    return 'Request failed (HTTP ${response.statusCode})';
  }

  void _throwForStatus(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
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
  Future<List<OfficeItem>> fetchOffices(
    String accessToken, {
    required int companyId,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/main/offices').replace(
      queryParameters: <String, String>{'companyId': '$companyId'},
    );
    final response = await _send(
      () => _httpClient.get(uri, headers: _headers(accessToken)),
    );
    _throwForStatus(response);

    final decoded = _decode(response.body);
    if (decoded is! List) return const <OfficeItem>[];
    return decoded
        .whereType<Map>()
        .map((raw) => OfficeItem.fromJson(raw.cast<String, dynamic>()))
        .toList(growable: false);
  }

  @override
  Future<OfficeItem> createOffice(
    String accessToken, {
    required int companyId,
    required OfficeDraft draft,
  }) async {
    final response = await _send(
      () => _httpClient.post(
        Uri.parse('${AppConfig.baseUrl}/main/offices'),
        headers: _headers(accessToken),
        body: jsonEncode(draft.toJson(companyId: companyId)),
      ),
    );
    _throwForStatus(response);

    final decoded = _decode(response.body);
    if (decoded is Map<String, dynamic>) {
      return OfficeItem.fromJson(decoded);
    }
    // A 2xx with an empty body is still a success; the caller refreshes the
    // list from the backend to get the authoritative record.
    return OfficeItem(id: 0, name: draft.name, companyId: companyId);
  }
}
