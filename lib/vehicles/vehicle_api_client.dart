import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../auth/credentials_manager.dart';
import '../auth/token_refresher.dart';
import '../core/app_config.dart';
import 'vehicle_models.dart';

class VehicleApiException implements Exception {
  const VehicleApiException(this.message);

  final String message;

  @override
  String toString() => 'VehicleApiException: $message';
}

class VehicleApiClient {
  VehicleApiClient({http.Client? httpClient, TokenRefresher? onUnauthorized})
    : _httpClient = httpClient ?? http.Client(),
      _onUnauthorized =
          onUnauthorized ?? CredentialsManager.instance.refreshAccessTokenForRetry;

  final http.Client _httpClient;
  final TokenRefresher _onUnauthorized;
  static const String _noInternetMessage =
      'No internet connection. Please check your network and try again.';

  Map<String, String> _authHeaders(String? token) => {
    'Accept': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  /// Retries once with a freshly refreshed token after a 401. If the refresh
  /// fails, the original 401 response is returned and the caller's normal
  /// error handling applies (the session has already been cleared).
  Future<http.Response> _requestWithAuth({
    required String? accessToken,
    required Future<http.Response> Function(String? token) send,
  }) async {
    final response = await send(accessToken);
    if (response.statusCode != 401) return response;
    final refreshed = await _onUnauthorized();
    if (refreshed == null || refreshed.isEmpty || refreshed == accessToken) {
      return response;
    }
    return send(refreshed);
  }

  bool _isNoInternetError(Object e) {
    final lower = e.toString().toLowerCase();
    return e is SocketException ||
        lower.contains('failed host lookup') ||
        lower.contains('no address associated with hostname') ||
        lower.contains('network is unreachable');
  }

  Future<VehiclePageDto> fetchCompanyVehicles({
    required int companyId,
    required int page,
    required int size,
    String? plate,
    String? driverName,
    BackendVehicleStatus? status,
    String? accessToken,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'size': '$size',
      if (plate != null && plate.trim().isNotEmpty) 'plate': plate.trim(),
      if (driverName != null && driverName.trim().isNotEmpty)
        'driverName': driverName.trim(),
      if (status != null) 'status': backendVehicleStatusToApiValue(status),
    };

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/main/vehicles/company/$companyId',
    ).replace(queryParameters: query);

    try {
      final response = await _requestWithAuth(
        accessToken: accessToken,
        send: (token) => _httpClient.get(uri, headers: _authHeaders(token)),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw VehicleApiException(
          'Vehicle fetch failed with status ${response.statusCode}: ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const VehicleApiException('Unexpected vehicle page response shape');
      }

      return VehiclePageDto.fromJson(decoded);
    } catch (e) {
      if (_isNoInternetError(e)) {
        throw VehicleApiException(_noInternetMessage);
      }
      rethrow;
    }
  }

  Future<DriverPageDto> fetchCompanyDrivers({
    required int companyId,
    required int page,
    required int size,
    String? query,
    String? accessToken,
  }) async {
    final queryParams = <String, String>{
      'page': '$page',
      'size': '$size',
      if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
    };

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/main/staff/company/$companyId/drivers',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _requestWithAuth(
        accessToken: accessToken,
        send: (token) => _httpClient.get(uri, headers: _authHeaders(token)),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw VehicleApiException(
          'Driver fetch failed with status ${response.statusCode}: ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const VehicleApiException('Unexpected driver page response shape');
      }

      return DriverPageDto.fromJson(decoded);
    } catch (e) {
      if (_isNoInternetError(e)) {
        throw VehicleApiException(_noInternetMessage);
      }
      rethrow;
    }
  }

  Future<void> assignDriverToVehicle({
    required int vehicleId,
    required int driverId,
    String? notes,
    String? accessToken,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.baseUrl}/main/vehicles/$vehicleId/assign/$driverId',
    ).replace(
      queryParameters: {
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );

    try {
      final response = await _requestWithAuth(
        accessToken: accessToken,
        send: (token) => _httpClient.post(uri, headers: _authHeaders(token)),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw VehicleApiException(
          'Driver assignment failed with status ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      if (_isNoInternetError(e)) {
        throw VehicleApiException(_noInternetMessage);
      }
      rethrow;
    }
  }

  Future<void> swapDriverAssignment({
    required int vehicleId,
    required int newDriverId,
    String? accessToken,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.baseUrl}/main/vehicles/$vehicleId/swap/$newDriverId',
    );

    try {
      final response = await _requestWithAuth(
        accessToken: accessToken,
        send: (token) => _httpClient.put(uri, headers: _authHeaders(token)),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw VehicleApiException(
          'Driver swap failed with status ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      if (_isNoInternetError(e)) {
        throw VehicleApiException(_noInternetMessage);
      }
      rethrow;
    }
  }

  Future<void> unassignDriverFromVehicle({
    required int vehicleId,
    String? accessToken,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.baseUrl}/main/vehicles/$vehicleId/unassign',
    );

    try {
      final response = await _requestWithAuth(
        accessToken: accessToken,
        send: (token) => _httpClient.delete(uri, headers: _authHeaders(token)),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw VehicleApiException(
          'Driver unassign failed with status ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      if (_isNoInternetError(e)) {
        throw VehicleApiException(_noInternetMessage);
      }
      rethrow;
    }
  }
}
