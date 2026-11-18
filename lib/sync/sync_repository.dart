import 'local_sync_database.dart';
import 'sync_api_client.dart';
import 'sync_coordinator.dart';
import 'sync_models.dart';

class SyncSnapshot {
  const SyncSnapshot({
    required this.baseUrl,
    required this.activeHash,
    required this.state,
    required this.locationCount,
    required this.routeCount,
    required this.locations,
    required this.routes,
  });

  final String baseUrl;
  final String? activeHash;
  final Map<String, String> state;
  final int locationCount;
  final int routeCount;
  final List<LocationEntity> locations;
  final List<RouteWithLocations> routes;
}

class SyncRepository {
  SyncRepository._();

  static final SyncRepository instance = SyncRepository._();

  final LocalSyncDatabase _db = LocalSyncDatabase.instance;

  Future<SyncSnapshot> readSnapshot({
    int locationLimit = 50,
    int routeLimit = 50,
  }) async {
    final results = await Future.wait<Object?>(<Future<Object?>>[
      _db.getStateValue(SyncCoordinator.activeHashKey),
      _db.getAllStateValues(),
      _db.countLocations(),
      _db.countRoutes(),
      _db.getLocations(limit: locationLimit),
      _db.getRoutesWithLocations(limit: routeLimit),
    ]);

    return SyncSnapshot(
      baseUrl: SyncApiClient.tripsApiBaseUrl,
      activeHash: results[0] as String?,
      state: results[1] as Map<String, String>,
      locationCount: results[2] as int,
      routeCount: results[3] as int,
      locations: results[4] as List<LocationEntity>,
      routes: results[5] as List<RouteWithLocations>,
    );
  }

  Future<List<LocationEntity>> readLocationsPage({
    required int limit,
    required int offset,
  }) {
    return _db.getLocations(limit: limit, offset: offset);
  }

  Future<List<RouteWithLocations>> readRoutesPage({
    required int limit,
    required int offset,
  }) {
    return _db.getRoutesWithLocations(limit: limit, offset: offset);
  }

  Future<List<LocationEntity>> searchLocations(String query, {int limit = 20}) {
    return _db.searchLocations(query, limit: limit);
  }

  Future<List<RouteWithLocations>> searchRoutes(String query, {int limit = 20}) {
    return _db.searchRoutes(query, limit: limit);
  }
}
