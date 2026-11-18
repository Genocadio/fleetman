import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../auth/access_api_client.dart';
import '../core/app_config.dart';
import 'vehicle_registration_models.dart';

/// Single, non-retried call used to register a vehicle for the signed-in
/// Fleet Manager's company.
abstract class VehicleRegistrationApi {
  Future<RegisteredVehicle> register(
    String accessToken, {
    required VehicleRegistrationDraft draft,
  });
}

class VehicleRegistrationApiClient implements VehicleRegistrationApi {
  VehicleRegistrationApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const String _noInternetMessage =
      'No internet connection. Please check your network and try again.';

  Map<String, String> _headers(String token) => <String, String>{
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  /// Transport failures are normalised so the controller can display them
  /// without guessing exception types. Nothing is refreshed or replayed here:
  /// a failed registration stays failed until the manager submits again.
  Future<http.Response> _send(Future<http.Response> Function() send) async {
    try {
      return await send();
    } on AccessApiException {
      rethrow;
    } catch (e) {
      final lower = e.toString().toLowerCase();
      final noInternet =
          e is SocketException ||
          e is TimeoutException ||
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
      // Spring bean validation returns field errors in `errors`. Show them
      // instead of the generic "Validation error" wrapper.
      final errors = decoded['errors'];
      if (errors is List && errors.isNotEmpty) {
        final messages = errors
            .whereType<Map>()
            .map(
              (raw) => raw['defaultMessage'] ?? raw['message'] ?? raw['field'],
            )
            .map((value) => value?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .toList(growable: false);
        if (messages.isNotEmpty) return messages.join('; ');
      }

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
        'The vehicle details could not be accepted. Please check the form and try again.',
      403 =>
        'You do not have permission to register a vehicle for your company.',
      404 => 'The vehicle registration service is unavailable.',
      409 =>
        'A vehicle with this license plate already exists. Please use a different license plate.',
      >= 500 =>
        'The server is temporarily unavailable. Please try again later.',
      _ => 'Vehicle registration failed (HTTP $status).',
    };
  }

  /// 401 means the session expired; 403 is a company/permission problem and
  /// must not sign the manager out or hide the real reason.
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
  Future<RegisteredVehicle> register(
    String accessToken, {
    required VehicleRegistrationDraft draft,
  }) async {
    final response = await _send(
      () => _httpClient.post(
        Uri.parse('${AppConfig.baseUrl}/main/vehicles'),
        headers: _headers(accessToken),
        body: jsonEncode(draft.toJson()),
      ),
    );
    _throwForStatus(response);

    final decoded = _decode(response.body);
    if (decoded is Map<String, dynamic>) {
      return RegisteredVehicle.fromJson(decoded);
    }
    // A 2xx with no parseable body is still a success. The initial password is
    // unknown in that case; the UI reports that it was not returned.
    return RegisteredVehicle.fromDraft(draft);
  }
}
