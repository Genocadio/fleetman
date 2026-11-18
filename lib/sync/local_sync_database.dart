import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'sync_models.dart';

part 'local_sync_database.g.dart';

@DataClassName('DriftLocation')
class Locations extends Table {
  IntColumn get id => integer()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get code => text().nullable()();
  TextColumn get googlePlaceName => text().nullable()();
  TextColumn get customName => text().nullable()();
  TextColumn get province => text().nullable()();
  TextColumn get district => text().nullable()();
  TextColumn get placeId => text().nullable()();
  TextColumn get createdAt => text().nullable()();
  TextColumn get updatedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DriftRoute')
class Routes extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text().nullable()();
  IntColumn get distanceMeters => integer().nullable()();
  IntColumn get estimatedDurationSeconds => integer().nullable()();
  TextColumn get googleRouteId => text().nullable()();
  IntColumn get originId => integer().references(Locations, #id)();
  IntColumn get destinationId => integer().references(Locations, #id)();
  RealColumn get routePrice => real().nullable()();
  BoolColumn get cityRoute => boolean().nullable()();
  TextColumn get waypoints => text().nullable()();
  TextColumn get createdAt => text().nullable()();
  TextColumn get updatedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DriftSyncState')
class SyncStates extends Table {
  // Keep the old sqflite table name so existing on-device DBs aren't broken.
  @override
  String get tableName => 'sync_state';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('DriftTripTemplate')
class TripTemplates extends Table {
  TextColumn get id => text()();
  IntColumn get routeId => integer().nullable()();
  TextColumn get origin => text()();
  TextColumn get destination => text()();
  RealColumn get baseFare => real()();
  TextColumn get waypoints => text()();      // JSON array
  TextColumn get waypointPrices => text()(); // JSON map
  TextColumn get waypointIds => text()();    // JSON map
  IntColumn get savedAt => integer()();      // milliseconds since epoch
  BoolColumn get isReversed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'fleetman_sync.db'));
    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(tables: [Locations, Routes, SyncStates, TripTemplates])
class LocalSyncDatabase extends _$LocalSyncDatabase {
  LocalSyncDatabase._() : super(_openConnection());

  static final LocalSyncDatabase instance = LocalSyncDatabase._();

  void _log(String message) {
    print('[LocalSyncDatabase] $message');
    developer.log(message, name: 'LocalSyncDatabase', level: 800);
  }

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.addColumn(routes, routes.waypoints);
        }
        if (from < 3) {
          await m.createTable(tripTemplates);
        }
        if (from < 4) {
          await m.addColumn(tripTemplates, tripTemplates.isReversed);
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  // --- Mappers ---
  LocationEntity _mapLocation(DriftLocation row) {
    return LocationEntity(
      id: row.id,
      latitude: row.latitude,
      longitude: row.longitude,
      code: row.code,
      googlePlaceName: row.googlePlaceName,
      customName: row.customName,
      province: row.province,
      district: row.district,
      placeId: row.placeId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  RouteEntity _mapRoute(DriftRoute row) {
    List<dynamic>? decodedWaypoints;
    if (row.waypoints != null) {
      try {
        decodedWaypoints = jsonDecode(row.waypoints!) as List<dynamic>;
      } catch (_) {}
    }

    return RouteEntity(
      id: row.id,
      name: row.name,
      distanceMeters: row.distanceMeters,
      estimatedDurationSeconds: row.estimatedDurationSeconds,
      googleRouteId: row.googleRouteId,
      originId: row.originId,
      destinationId: row.destinationId,
      routePrice: row.routePrice,
      cityRoute: row.cityRoute,
      waypoints: decodedWaypoints,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  LocationsCompanion _locationToCompanion(LocationEntity e) {
    return LocationsCompanion.insert(
      id: Value(e.id),
      latitude: Value(e.latitude),
      longitude: Value(e.longitude),
      code: Value(e.code),
      googlePlaceName: Value(e.googlePlaceName),
      customName: Value(e.customName),
      province: Value(e.province),
      district: Value(e.district),
      placeId: Value(e.placeId),
      createdAt: Value(e.createdAt),
      updatedAt: Value(e.updatedAt),
    );
  }

  RoutesCompanion _routeToCompanion(RouteEntity e) {
    String? encodedWaypoints;
    if (e.waypoints != null) {
      encodedWaypoints = jsonEncode(e.waypoints);
    }
    return RoutesCompanion.insert(
      id: Value(e.id),
      name: Value(e.name),
      distanceMeters: Value(e.distanceMeters),
      estimatedDurationSeconds: Value(e.estimatedDurationSeconds),
      googleRouteId: Value(e.googleRouteId),
      originId: e.originId,
      destinationId: e.destinationId,
      routePrice: Value(e.routePrice),
      cityRoute: Value(e.cityRoute),
      waypoints: Value(encodedWaypoints),
      createdAt: Value(e.createdAt),
      updatedAt: Value(e.updatedAt),
    );
  }

  // --- Operations ---
  Future<void> upsertLocations(List<LocationEntity> locs) async {
    if (locs.isEmpty) return;
    _log('Upserting ${locs.length} location(s)');
    for (final location in locs) {
      _log(
        'Location upsert id=${location.id} customName=${location.customName} googlePlace=${location.googlePlaceName} code=${location.code}',
      );
    }
    await batch((b) {
      b.insertAll(
        locations,
        locs.map(_locationToCompanion).toList(),
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<void> upsertRoutes(List<RouteEntity> rts) async {
    if (rts.isEmpty) return;
    _log('Upserting ${rts.length} route(s)');
    for (final route in rts) {
      _log(
        'Route upsert id=${route.id} originId=${route.originId} destinationId=${route.destinationId} name=${route.name}',
      );
    }
    await batch((b) {
      b.insertAll(
        routes,
        rts.map(_routeToCompanion).toList(),
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<void> deleteLocationsByIds(List<int> ids) async {
    if (ids.isEmpty) return;
    await (delete(locations)..where((tbl) => tbl.id.isIn(ids))).go();
  }

  Future<void> deleteRoutesByIds(List<int> ids) async {
    if (ids.isEmpty) return;
    await (delete(routes)..where((tbl) => tbl.id.isIn(ids))).go();
  }

  Future<List<LocationEntity>> getLocations({
    int limit = 100,
    int offset = 0,
  }) async {
    final query = select(locations)
      ..orderBy([(t) => OrderingTerm.asc(t.id)])
      ..limit(limit, offset: offset);
    final rows = await query.get();
    return rows.map(_mapLocation).toList();
  }

  Future<List<RouteWithLocations>> getRoutesWithLocations({
    int limit = 100,
    int offset = 0,
  }) async {
    final originLoc = alias(locations, 'o');
    final destLoc = alias(locations, 'd');

    final query = select(routes).join([
      leftOuterJoin(originLoc, routes.originId.equalsExp(originLoc.id)),
      leftOuterJoin(destLoc, routes.destinationId.equalsExp(destLoc.id)),
    ])
      ..orderBy([OrderingTerm.asc(routes.id)])
      ..limit(limit, offset: offset);

    final results = await query.get();

    return results.map((row) {
      final routeRow = row.readTable(routes);
      final oRow = row.readTableOrNull(originLoc);
      final dRow = row.readTableOrNull(destLoc);

      return RouteWithLocations(
        route: _mapRoute(routeRow),
        origin: oRow == null ? null : _mapLocation(oRow),
        destination: dRow == null ? null : _mapLocation(dRow),
      );
    }).toList();
  }

  Future<int> countLocations() async {
    final countExp = locations.id.count();
    final query = selectOnly(locations)..addColumns([countExp]);
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  Future<int> countRoutes() async {
    final countExp = routes.id.count();
    final query = selectOnly(routes)..addColumns([countExp]);
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  Future<int> countLocationsByIds(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final countExp = locations.id.count();
    final query = selectOnly(locations)
      ..addColumns([countExp])
      ..where(locations.id.isIn(ids));
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  Future<int> countRoutesByIds(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final countExp = routes.id.count();
    final query = selectOnly(routes)
      ..addColumns([countExp])
      ..where(routes.id.isIn(ids));
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }
  Future<LocationEntity?> getLocationById(int id) async {
    final query = select(locations)..where((tbl) => tbl.id.equals(id));
    final result = await query.getSingleOrNull();
    return result == null ? null : _mapLocation(result);
  }

  Future<int> countAllLocations() async {
    return countLocations();
  }

  Future<int> countAllRoutes() async {
    return countRoutes();
  }
  Future<void> setStateValue(String key, String value) async {
    await into(syncStates).insert(
      SyncStatesCompanion.insert(key: key, value: value),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<String?> getStateValue(String key) async {
    final query = select(syncStates)..where((tbl) => tbl.key.equals(key));
    final result = await query.getSingleOrNull();
    return result?.value;
  }

  Future<void> deleteStateValue(String key) async {
    await (delete(syncStates)..where((tbl) => tbl.key.equals(key))).go();
  }

  Future<Map<String, String>> getAllStateValues() async {
    final rows = await select(syncStates).get();
    return {for (final row in rows) row.key: row.value};
  }

  Future<void> clearSyncProgressState() async {
    final keysToDelete = [
      'pending_hash',
      'initial_locations_next_page',
      'initial_routes_next_page',
      'delta_locations_next_page',
      'delta_routes_next_page',
      'delta_source_hash',
      'delta_pending_hash',
    ];
    await (delete(syncStates)..where((tbl) => tbl.key.isIn(keysToDelete))).go();
  }

  String _normalizeSearchValue(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  bool _containsNormalized(String? target, String normalizedQuery) {
    if (target == null || target.isEmpty || normalizedQuery.isEmpty) {
      return false;
    }
    return _normalizeSearchValue(target).contains(normalizedQuery);
  }

  bool _waypointsMatch(List<dynamic>? waypoints, String normalizedQuery) {
    if (waypoints == null || waypoints.isEmpty || normalizedQuery.isEmpty) {
      return false;
    }

    for (final rawWaypoint in waypoints) {
      if (rawWaypoint is Map) {
        final waypoint = rawWaypoint.cast<String, dynamic>();
        final location = waypoint['location'] is Map
            ? (waypoint['location'] as Map).cast<String, dynamic>()
            : null;

        if (_containsNormalized(waypoint['location_id']?.toString(), normalizedQuery) ||
            _containsNormalized(waypoint['price']?.toString(), normalizedQuery) ||
            _containsNormalized(location?['custom_name']?.toString(), normalizedQuery) ||
            _containsNormalized(location?['google_place_name']?.toString(), normalizedQuery) ||
            _containsNormalized(location?['code']?.toString(), normalizedQuery) ||
            _containsNormalized(location?['id']?.toString(), normalizedQuery)) {
          return true;
        }
      } else if (_containsNormalized(rawWaypoint.toString(), normalizedQuery)) {
        return true;
      }
    }

    return false;
  }

  Future<List<LocationEntity>> searchLocations(String queryStr, {int limit = 20}) async {
    final normalizedQuery = _normalizeSearchValue(queryStr.trim());
    if (normalizedQuery.isEmpty) {
      return getLocations(limit: limit);
    }

    final allLocations = await getLocations(limit: 10000);
    final results = allLocations.where((loc) {
      return _containsNormalized(loc.customName, normalizedQuery) ||
          _containsNormalized(loc.googlePlaceName, normalizedQuery) ||
          _containsNormalized(loc.code, normalizedQuery) ||
          _containsNormalized(loc.province, normalizedQuery) ||
          _containsNormalized(loc.district, normalizedQuery) ||
          _containsNormalized(loc.id.toString(), normalizedQuery) ||
          _containsNormalized(loc.displayName, normalizedQuery);
    }).take(limit).toList();

    _log('searchLocations query="$queryStr" returned ${results.length} row(s)');
    return results;
  }

  Future<List<RouteWithLocations>> searchRoutes(String queryStr, {int limit = 20}) async {
    final normalizedQuery = _normalizeSearchValue(queryStr.trim());
    if (normalizedQuery.isEmpty) {
      return getRoutesWithLocations(limit: limit);
    }

    final allRoutes = await getRoutesWithLocations(limit: 10000);
    final results = allRoutes.where((rw) {
      return _containsNormalized(rw.route.id.toString(), normalizedQuery) ||
          _containsNormalized(rw.route.name, normalizedQuery) ||
          _containsNormalized(rw.origin?.displayName, normalizedQuery) ||
          _containsNormalized(rw.origin?.customName, normalizedQuery) ||
          _containsNormalized(rw.origin?.googlePlaceName, normalizedQuery) ||
          _containsNormalized(rw.origin?.code, normalizedQuery) ||
          _containsNormalized(rw.destination?.displayName, normalizedQuery) ||
          _containsNormalized(rw.destination?.customName, normalizedQuery) ||
          _containsNormalized(rw.destination?.googlePlaceName, normalizedQuery) ||
          _containsNormalized(rw.destination?.code, normalizedQuery) ||
          _waypointsMatch(rw.route.waypoints, normalizedQuery);
    }).take(limit).toList();

    _log('searchRoutes query="$queryStr" returned ${results.length} row(s)');
    return results;
  }

  Future<void> clearAllData() async {
    _log('Clearing all sync data from local database');
    await transaction(() async {
      await delete(routes).go();
      await delete(locations).go();
      // Keep auth/session keys (stored in sync_state) intact.
      final syncKeysToDelete = [
        'active_hash',
        'pending_hash',
        'initial_locations_next_page',
        'initial_routes_next_page',
        'delta_locations_next_page',
        'delta_routes_next_page',
        'delta_source_hash',
        'delta_pending_hash',
        'last_success_sync_at',
      ];
      await (delete(syncStates)..where((tbl) => tbl.key.isIn(syncKeysToDelete))).go();
    });
  }

  // --- Trip Template CRUD ---

  Future<List<DriftTripTemplate>> getAllTemplates() async {
    return (select(tripTemplates)
          ..orderBy([(t) => OrderingTerm.desc(t.savedAt)]))
        .get();
  }

  Future<void> insertTemplate(DriftTripTemplate t) async {
    await into(tripTemplates).insert(
      TripTemplatesCompanion.insert(
        id: t.id,
        routeId: Value(t.routeId),
        origin: t.origin,
        destination: t.destination,
        baseFare: t.baseFare,
        waypoints: t.waypoints,
        waypointPrices: t.waypointPrices,
        waypointIds: t.waypointIds,
        savedAt: t.savedAt,
        isReversed: Value(t.isReversed),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> updateTemplate(DriftTripTemplate t) async {
    await (update(tripTemplates)..where((tbl) => tbl.id.equals(t.id))).write(
      TripTemplatesCompanion(
        routeId: Value(t.routeId),
        origin: Value(t.origin),
        destination: Value(t.destination),
        baseFare: Value(t.baseFare),
        waypoints: Value(t.waypoints),
        waypointPrices: Value(t.waypointPrices),
        waypointIds: Value(t.waypointIds),
        isReversed: Value(t.isReversed),
      ),
    );
  }

  Future<void> deleteTemplate(String id) async {
    await (delete(tripTemplates)..where((tbl) => tbl.id.equals(id))).go();
  }
}
