import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../auth/credentials_manager.dart';
import '../auth/token_refresher.dart';
import '../core/app_config.dart';
import 'trip_models.dart';

abstract class RemoteResult<T> {
  const RemoteResult();
}

class RemoteResultSuccess<T> extends RemoteResult<T> {
  const RemoteResultSuccess(this.data);
  final T data;
}

class RemoteResultError<T> extends RemoteResult<T> {
  const RemoteResultError(this.message);
  final String message;
}

class TripApiClient {
  TripApiClient({http.Client? httpClient, TokenRefresher? onUnauthorized})
    : _httpClient = httpClient ?? http.Client(),
      _onUnauthorized =
          onUnauthorized ?? CredentialsManager.instance.refreshAccessTokenForRetry;

  static const String tripsBaseUrl = '${AppConfig.baseUrl}/navig/trips';
  static const String _noInternetMessage =
      'No internet connection. Please check your network and try again.';
  final http.Client _httpClient;
  final TokenRefresher _onUnauthorized;

  Map<String, String> _authHeaders(String? token, {bool jsonBody = false}) => {
    if (jsonBody) 'Content-Type': 'application/json',
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

  Future<VehicleTripsResponse> fetchVehicleTrips({
    required int vehicleId,
    List<String>? statuses,
    int limit = 20,
    int offset = 0,
    String? sessionUuid,
    String? accessToken,
  }) async {
    final query = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (statuses != null && statuses.isNotEmpty) 'status': statuses.join(','),
      if (sessionUuid != null && sessionUuid.trim().isNotEmpty)
        'session_uuid': sessionUuid.trim(),
    };

    final uri = Uri.parse(
      '$tripsBaseUrl/vehicle/$vehicleId',
    ).replace(queryParameters: query);

    debugPrint('[TripApiClient] fetchVehicleTrips start');
    debugPrint(
      '[TripApiClient] vehicleId=$vehicleId limit=$limit offset=$offset',
    );
    debugPrint('[TripApiClient] statuses=${statuses?.join(',') ?? '(none)'}');
    debugPrint(
      '[TripApiClient] sessionUuid=${sessionUuid?.trim().isNotEmpty == true ? sessionUuid : '(none)'}',
    );
    debugPrint('[TripApiClient] uri=$uri');
    debugPrint(
      '[TripApiClient] hasAuthToken=${accessToken != null && accessToken.isNotEmpty}',
    );

    http.Response response;
    try {
      response = await _requestWithAuth(
        accessToken: accessToken,
        send: (token) => _httpClient.get(uri, headers: _authHeaders(token)),
      );
    } catch (e) {
      if (_isNoInternetError(e)) {
        throw const RemoteResultError(_noInternetMessage);
      }
      rethrow;
    }
    debugPrint('[TripApiClient] response status=${response.statusCode}');
    final bodyPreview = response.body.length > 600
        ? '${response.body.substring(0, 600)}...'
        : response.body;
    debugPrint('[TripApiClient] response body preview=$bodyPreview');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('[TripApiClient] fetchVehicleTrips failed');
      throw RemoteResultError(
        'Vehicle trips fetch failed with status ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      debugPrint(
        '[TripApiClient] fetchVehicleTrips invalid response shape: ${decoded.runtimeType}',
      );
      throw const RemoteResultError('Unexpected vehicle trips response shape');
    }

    final parsed = VehicleTripsResponse.fromJson(decoded);
    final statusCounts = <String, int>{};
    for (final trip in parsed.trips) {
      final status = trip.status.trim().toUpperCase();
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    debugPrint(
      '[TripApiClient] parsed trips=${parsed.trips.length} total=${parsed.total} page=${parsed.page}/${parsed.totalPages}',
    );
    debugPrint('[TripApiClient] parsed statusCounts=$statusCounts');
    debugPrint('[TripApiClient] fetchVehicleTrips done');

    return parsed;
  }

  Future<RemoteResult<TripResponse>> createTrip(
    CreateTripRequest request, {
    String? accessToken,
  }
  ) async {
    try {
      debugPrint("=== CREATING TRIP FROM REMOTE ===");
      final requestBody = jsonEncode(request.toJson());
      debugPrint("Trip request payload: $requestBody");

      final uri = Uri.parse(tripsBaseUrl);
      debugPrint('[TripApiClient] createTrip uri=$uri');
      final response = await _requestWithAuth(
        accessToken: accessToken,
        send: (token) => _httpClient.post(
          uri,
          headers: _authHeaders(token, jsonBody: true),
          body: requestBody,
        ),
      );
      debugPrint('[TripApiClient] createTrip status=${response.statusCode}');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String errorMessage =
            'Trip create failed with status ${response.statusCode}';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['error'] != null) {
            errorMessage = decoded['error'].toString();
          } else if (response.body.trim().isNotEmpty) {
            errorMessage = '$errorMessage: ${response.body}';
          }
        } catch (_) {
          if (response.body.trim().isNotEmpty) {
            errorMessage = '$errorMessage: ${response.body}';
          }
        }
        return RemoteResultError(errorMessage);
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const RemoteResultError('Unexpected create trip response shape');
      }

      return RemoteResultSuccess(TripResponse.fromJson(decoded));
    } catch (e) {
      debugPrint("Failed to create trip: $e");
      if (_isNoInternetError(e)) {
        return const RemoteResultError(_noInternetMessage);
      }
      return RemoteResultError("Failed to create trip: $e");
    }
  }

  Future<RemoteResult<TripResponse>> toggleLatestVehicleTripAutoReturn({
    required int vehicleId,
    required bool autoReturn,
    String? accessToken,
  }) async {
    try {
      final uri = Uri.parse('$tripsBaseUrl/vehicle/$vehicleId/auto-return');
      final body = jsonEncode(<String, dynamic>{'auto_return': autoReturn});
      final response = await _requestWithAuth(
        accessToken: accessToken,
        send: (token) => _httpClient.put(
          uri,
          headers: _authHeaders(token, jsonBody: true),
          body: body,
        ),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String errorMessage =
            'Auto-return toggle failed with status ${response.statusCode}';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['error'] != null) {
            errorMessage = decoded['error'].toString();
          } else if (response.body.trim().isNotEmpty) {
            errorMessage = '$errorMessage: ${response.body}';
          }
        } catch (_) {
          if (response.body.trim().isNotEmpty) {
            errorMessage = '$errorMessage: ${response.body}';
          }
        }
        return RemoteResultError(errorMessage);
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const RemoteResultError('Unexpected auto-return response shape');
      }

      return RemoteResultSuccess(TripResponse.fromJson(decoded));
    } catch (e) {
      if (_isNoInternetError(e)) {
        return const RemoteResultError(_noInternetMessage);
      }
      return RemoteResultError('Failed to toggle auto-return: $e');
    }
  }

  Future<RemoteResult<void>> deleteTripById({
    required int tripId,
    String? accessToken,
  }) async {
    try {
      final uri = Uri.parse('$tripsBaseUrl/$tripId');
      final response = await _requestWithAuth(
        accessToken: accessToken,
        send: (token) => _httpClient.delete(uri, headers: _authHeaders(token)),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String errorMessage =
            'Trip delete failed with status ${response.statusCode}';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['error'] != null) {
            errorMessage = decoded['error'].toString();
          } else if (response.body.trim().isNotEmpty) {
            errorMessage = '$errorMessage: ${response.body}';
          }
        } catch (_) {
          if (response.body.trim().isNotEmpty) {
            errorMessage = '$errorMessage: ${response.body}';
          }
        }
        return RemoteResultError(errorMessage);
      }

      return const RemoteResultSuccess(null);
    } catch (e) {
      if (_isNoInternetError(e)) {
        return const RemoteResultError(_noInternetMessage);
      }
      return RemoteResultError('Failed to delete trip: $e');
    }
  }
}
