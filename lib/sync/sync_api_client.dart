import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import 'sync_models.dart';

class SyncApiClient {
  SyncApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  static const String tripsApiBaseUrl = '${AppConfig.baseUrl}/navig/';

  final http.Client _httpClient;

  void _log(String message, {Object? error}) {
    print('[SyncApiClient] $message${error == null ? '' : ' | error=$error'}');
    developer.log(message, name: 'SyncApiClient', error: error, level: 800);
  }

  Uri _buildUri(String path, Map<String, String> queryParameters) {
    return Uri.parse(
      '$tripsApiBaseUrl$path',
    ).replace(queryParameters: queryParameters);
  }

  Future<SyncPage<LocationEntity>> fetchLocationsPage({
    String? hash,
    required int page,
    int limit = 100,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'limit': '$limit',
      if (hash != null && hash.isNotEmpty) 'hash': hash,
    };

    final response = await _httpClient.get(
      _buildUri('locations/hash', query),
      headers: const {'Accept': 'application/json'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SyncApiException(
        'Locations sync failed with status ${response.statusCode}: ${response.body}',
      );
    }

    final payload = _decodeBody(response.body);
    final rawLocations = payload['locations'] as List<dynamic>? ?? const <dynamic>[];
    _log('Locations API raw response: ${rawLocations.length} items in payload');
    final items = rawLocations
        .map((e) => LocationEntity.fromJson((e as Map).cast<String, dynamic>()))
        .toList();

    _log('Locations page fetched page=${payload['page'] ?? page} count=${items.length}');

    final changes = _parseLocationChanges(payload['changes'] as List<dynamic>?);

    return SyncPage<LocationEntity>(
      hash: payload['hash']?.toString() ?? '',
      changed: payload['changed'] == true,
      items: items,
      changes: changes,
      deletedIds:
          (payload['deleted_ids'] as List<dynamic>? ?? const <dynamic>[])
              .map((e) => (e as num).toInt())
              .toList(),
      page: (payload['page'] as num?)?.toInt() ?? page,
      limit: (payload['limit'] as num?)?.toInt() ?? limit,
      total: (payload['total'] as num?)?.toInt() ?? items.length,
      message: payload['message']?.toString() ?? '',
    );
  }

  Future<SyncPage<RouteEntity>> fetchRoutesPage({
    String? hash,
    required int page,
    int limit = 100,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'limit': '$limit',
      if (hash != null && hash.isNotEmpty) 'hash': hash,
    };

    final response = await _httpClient.get(
      _buildUri('routes/hash', query),
      headers: const {'Accept': 'application/json'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SyncApiException(
        'Routes sync failed with status ${response.statusCode}: ${response.body}',
      );
    }

    final payload = _decodeBody(response.body);
    final rawRoutes = payload['routes'] as List<dynamic>? ?? const <dynamic>[];
    final parsedRoutes = rawRoutes
        .map((e) => RouteEntity.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    final items = parsedRoutes
        .where((route) => route.originId > 0 && route.destinationId > 0)
        .toList();

    final filteredOut = parsedRoutes.length - items.length;
    if (filteredOut > 0) {
      _log(
        'Filtered $filteredOut route(s) with missing origin/destination ids on page $page',
      );
    }

    final changes = _parseRouteChanges(payload['changes'] as List<dynamic>?);

    return SyncPage<RouteEntity>(
      hash: payload['hash']?.toString() ?? '',
      changed: payload['changed'] == true,
      items: items,
      changes: changes,
      deletedIds:
          (payload['deleted_ids'] as List<dynamic>? ?? const <dynamic>[])
              .map((e) => (e as num).toInt())
              .toList(),
      page: (payload['page'] as num?)?.toInt() ?? page,
      limit: (payload['limit'] as num?)?.toInt() ?? limit,
      total: (payload['total'] as num?)?.toInt() ?? items.length,
      message: payload['message']?.toString() ?? '',
    );
  }

  Map<String, dynamic> _decodeBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const SyncApiException('Unexpected API response shape');
    }
    return decoded;
  }

  List<SyncChange<LocationEntity>> _parseLocationChanges(
    List<dynamic>? changes,
  ) {
    if (changes == null) {
      return const <SyncChange<LocationEntity>>[];
    }

    return changes.map((raw) {
      final entry = (raw as Map).cast<String, dynamic>();
      final op = parseSyncOperation(
        entry['operation']?.toString() ?? 'updated',
      );
      final rawLocation = entry['location'];
      final location = rawLocation is Map<String, dynamic>
          ? LocationEntity.fromJson(rawLocation)
          : (rawLocation is Map
                ? LocationEntity.fromJson(rawLocation.cast<String, dynamic>())
                : null);
      return SyncChange<LocationEntity>(
        id: (entry['id'] as num).toInt(),
        operation: op,
        entity: location,
        changedAt: entry['changed_at']?.toString(),
      );
    }).toList();
  }

  List<SyncChange<RouteEntity>> _parseRouteChanges(List<dynamic>? changes) {
    if (changes == null) {
      return const <SyncChange<RouteEntity>>[];
    }

    return changes.map((raw) {
      final entry = (raw as Map).cast<String, dynamic>();
      final op = parseSyncOperation(
        entry['operation']?.toString() ?? 'updated',
      );
      final rawRoute = entry['route'];
      final route = rawRoute is Map<String, dynamic>
          ? RouteEntity.fromJson(rawRoute)
          : (rawRoute is Map
                ? RouteEntity.fromJson(rawRoute.cast<String, dynamic>())
                : null);
      return SyncChange<RouteEntity>(
        id: (entry['id'] as num).toInt(),
        operation: op,
        entity: route,
        changedAt: entry['changed_at']?.toString(),
      );
    }).toList();
  }
}

class SyncApiException implements Exception {
  const SyncApiException(this.message);

  final String message;

  @override
  String toString() => 'SyncApiException: $message';
}
