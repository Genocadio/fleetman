import 'dart:async';
import 'dart:developer' as developer;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'local_sync_database.dart';
import 'sync_api_client.dart';
import 'sync_models.dart';

enum SyncStage {
  idle,
  checkingInternet,
  syncingLocations,
  syncingRoutes,
  done,
  failed,
}

class SyncProgress {
  const SyncProgress({
    required this.stage,
    required this.percentage,
    required this.message,
    this.currentPage,
    this.totalPages,
    this.itemsInCurrentPage,
  });

  final SyncStage stage;
  final double percentage;
  final String message;
  final int? currentPage;
  final int? totalPages;
  final int? itemsInCurrentPage;

  bool get isActive =>
      stage != SyncStage.idle &&
      stage != SyncStage.done &&
      stage != SyncStage.failed;

  SyncProgress copyWith({
    SyncStage? stage,
    double? percentage,
    String? message,
    int? currentPage,
    int? totalPages,
    int? itemsInCurrentPage,
    bool clearPageInfo = false,
  }) {
    return SyncProgress(
      stage: stage ?? this.stage,
      percentage: percentage ?? this.percentage,
      message: message ?? this.message,
      currentPage: clearPageInfo ? null : (currentPage ?? this.currentPage),
      totalPages: clearPageInfo ? null : (totalPages ?? this.totalPages),
      itemsInCurrentPage: clearPageInfo
          ? null
          : (itemsInCurrentPage ?? this.itemsInCurrentPage),
    );
  }
}

class SyncCoordinator {
  SyncCoordinator._();

  static final SyncCoordinator instance = SyncCoordinator._();

  static const String activeHashKey = 'active_hash';
  static const String pendingHashKey = 'pending_hash';
  static const String initialLocationsPageKey = 'initial_locations_next_page';
  static const String initialRoutesPageKey = 'initial_routes_next_page';
  static const String deltaLocationsPageKey = 'delta_locations_next_page';
  static const String deltaRoutesPageKey = 'delta_routes_next_page';
  static const String deltaSourceHashKey = 'delta_source_hash';
  static const String deltaPendingHashKey = 'delta_pending_hash';
  static const String lastSuccessSyncAtKey = 'last_success_sync_at';

  final LocalSyncDatabase _db = LocalSyncDatabase.instance;
  final SyncApiClient _api = SyncApiClient();

  void _log(String message, {Object? error}) {
    print('[SyncCoordinator] $message${error == null ? '' : ' | error=$error'}');
    developer.log(message, name: 'SyncCoordinator', error: error, level: 800);
  }

  bool _syncInProgress = false;
  bool _syncPending = false;
  bool _isListeningConnectivity = false;
  
  final ValueNotifier<SyncProgress> progress = ValueNotifier<SyncProgress>(
    const SyncProgress(stage: SyncStage.idle, percentage: 0, message: 'Idle'),
  );

  void syncOnAppOpenInBackground() {
    _setupConnectivityListener();
    unawaited(syncNow());
  }

  void _setupConnectivityListener() {
    if (_isListeningConnectivity) return;
    _isListeningConnectivity = true;
    Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        if (_syncPending && !_syncInProgress) {
          unawaited(syncNow());
        }
      }
    });
  }

  Future<void> syncNow() async {
    if (_syncInProgress) {
      return;
    }

    _syncInProgress = true;
    try {
      _setProgress(
        const SyncProgress(
          stage: SyncStage.checkingInternet,
          percentage: 0,
          message: 'Checking internet connection...',
        ),
      );
      final hasInternet = await _hasInternet();
      if (!hasInternet) {
        _syncPending = true;
        _setProgress(
          const SyncProgress(
            stage: SyncStage.failed,
            percentage: 0,
            message: 'No internet connection.',
          ),
        );
        return;
      }

      final activeHash = await _db.getStateValue(activeHashKey);
      if (activeHash == null || activeHash.isEmpty) {
        await _runInitialSync();
      } else {
        await _runDeltaSync(activeHash);
      }

      await _db.setStateValue(
        lastSuccessSyncAtKey,
        DateTime.now().toUtc().toIso8601String(),
      );

      _syncPending = false;
      _setProgress(
        const SyncProgress(
          stage: SyncStage.done,
          percentage: 100,
          message: 'Sync complete.',
        ),
      );
    } catch (error) {
      _syncPending = true;
      _log('Sync failed', error: error);
      rethrow;
    } finally {
      _syncInProgress = false;
    }
  }

  Future<void> forceFullResync() async {
    if (_syncInProgress) {
      return;
    }

    _syncInProgress = true;
    try {
      _log('Starting full resync');
      await _db.clearAllData();
      await _db.deleteStateValue(activeHashKey);
      await _db.deleteStateValue(pendingHashKey);
      await _db.clearSyncProgressState();
      await _runInitialSync();
      await _db.setStateValue(
        lastSuccessSyncAtKey,
        DateTime.now().toUtc().toIso8601String(),
      );
      _syncPending = false;
      _setProgress(
        const SyncProgress(
          stage: SyncStage.done,
          percentage: 100,
          message: 'Full resync complete.',
        ),
      );
    } catch (error) {
      _syncPending = true;
      _log('Full resync failed', error: error);
      _setProgress(
        SyncProgress(
          stage: SyncStage.failed,
          percentage: progress.value.percentage,
          message: 'Full resync failed: $error',
        ),
      );
      rethrow;
    } finally {
      _syncInProgress = false;
    }
  }

  Future<bool> _hasInternet() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((value) => value != ConnectivityResult.none);
  }

  Future<void> _runInitialSync() async {
    var pendingHash = await _db.getStateValue(pendingHashKey);

    var locationPage = _readStoredPage(
      await _db.getStateValue(initialLocationsPageKey),
    );
    _log('Starting location fetch loop from page=$locationPage');
    while (true) {
      _log('Fetching locations page $locationPage...');
      final response = await _api.fetchLocationsPage(page: locationPage);
      _updatePageProgress(
        stage: SyncStage.syncingLocations,
        isLocationPhase: true,
        messagePrefix: 'Initial sync: locations',
        response: response,
      );
      for (final location in response.items) {
        _log(
          'Fetched location page=${response.page} id=${location.id} customName=${location.customName} googlePlace=${location.googlePlaceName} code=${location.code}',
        );
      }
      if (response.items.isEmpty) {
        _log('WARNING: Location page $locationPage returned 0 items!');
      }
      await _db.upsertLocations(response.items);
      final locationIds = response.items.map((e) => e.id).toList();
      final persistedLocations = await _db.countLocationsByIds(locationIds);
      _log(
        'Initial locations page ${response.page}: fetched=${response.items.length}, persistedForPage=$persistedLocations',
      );

      if (response.hash.isNotEmpty) {
        pendingHash = response.hash;
        await _db.setStateValue(pendingHashKey, response.hash);
      }

      final done = _isPageDone(response);
      if (done) {
        await _db.deleteStateValue(initialLocationsPageKey);
        break;
      }

      locationPage += 1;
      await _db.setStateValue(initialLocationsPageKey, '$locationPage');
    }

    var routePage = _readStoredPage(
      await _db.getStateValue(initialRoutesPageKey),
    );
    while (true) {
      final response = await _api.fetchRoutesPage(page: routePage);
      _updatePageProgress(
        stage: SyncStage.syncingRoutes,
        isLocationPhase: false,
        messagePrefix: 'Initial sync: routes',
        response: response,
      );
      for (final route in response.items) {
        _log(
          'Fetched route page=${response.page} id=${route.id} originId=${route.originId} destinationId=${route.destinationId} name=${route.name}',
        );
      }
      await _db.upsertRoutes(response.items);
      final routeIds = response.items.map((e) => e.id).toList();
      final persistedRoutes = await _db.countRoutesByIds(routeIds);
      _log(
        'Initial routes page ${response.page}: fetched=${response.items.length}, persistedForPage=$persistedRoutes',
      );

      if (response.hash.isNotEmpty) {
        pendingHash = response.hash;
        await _db.setStateValue(pendingHashKey, response.hash);
      }

      final done = _isPageDone(response);
      if (done) {
        await _db.deleteStateValue(initialRoutesPageKey);
        break;
      }

      routePage += 1;
      await _db.setStateValue(initialRoutesPageKey, '$routePage');
    }

    if (pendingHash != null && pendingHash.isNotEmpty) {
      await _db.setStateValue(activeHashKey, pendingHash);
    }
    await _db.clearSyncProgressState();
    
    // Diagnostic: Show what's actually in the database after sync
    final totalLocations = await _db.countAllLocations();
    final totalRoutes = await _db.countAllRoutes();
    _log('SYNC COMPLETE - Database state: $totalLocations locations, $totalRoutes routes');
    final location165 = await _db.getLocationById(165);
    if (location165 != null) {
      _log('✓ Location 165 found: customName=${location165.customName}, googlePlace=${location165.googlePlaceName}, code=${location165.code}');
    } else {
      _log('✗ Location 165 NOT FOUND in database after sync');
    }
  }

  Future<void> _runDeltaSync(String activeHash) async {
    final sourceHashInProgress = await _db.getStateValue(deltaSourceHashKey);
    if (sourceHashInProgress != null && sourceHashInProgress != activeHash) {
      await _db.deleteStateValue(deltaLocationsPageKey);
      await _db.deleteStateValue(deltaRoutesPageKey);
      await _db.deleteStateValue(deltaPendingHashKey);
    }
    await _db.setStateValue(deltaSourceHashKey, activeHash);

    var pendingHash = await _db.getStateValue(deltaPendingHashKey);

    var locationPage = _readStoredPage(
      await _db.getStateValue(deltaLocationsPageKey),
    );
    while (true) {
      final response = await _api.fetchLocationsPage(
        hash: activeHash,
        page: locationPage,
      );
      _updatePageProgress(
        stage: SyncStage.syncingLocations,
        isLocationPhase: true,
        messagePrefix: 'Delta sync: locations',
        response: response,
      );

      if (response.indicatesInvalidHash) {
        await _handleInvalidHashAndResync();
        return;
      }

      await _applyLocationDelta(response);

      if (response.hash.isNotEmpty) {
        pendingHash = response.hash;
        await _db.setStateValue(deltaPendingHashKey, response.hash);
      }

      final done = _isPageDone(response);
      if (done) {
        await _db.deleteStateValue(deltaLocationsPageKey);
        break;
      }

      locationPage += 1;
      await _db.setStateValue(deltaLocationsPageKey, '$locationPage');
    }

    var routePage = _readStoredPage(
      await _db.getStateValue(deltaRoutesPageKey),
    );
    while (true) {
      final response = await _api.fetchRoutesPage(
        hash: activeHash,
        page: routePage,
      );
      _updatePageProgress(
        stage: SyncStage.syncingRoutes,
        isLocationPhase: false,
        messagePrefix: 'Delta sync: routes',
        response: response,
      );

      if (response.indicatesInvalidHash) {
        await _handleInvalidHashAndResync();
        return;
      }

      await _applyRouteDelta(response);

      if (response.hash.isNotEmpty) {
        pendingHash = response.hash;
        await _db.setStateValue(deltaPendingHashKey, response.hash);
      }

      final done = _isPageDone(response);
      if (done) {
        await _db.deleteStateValue(deltaRoutesPageKey);
        break;
      }

      routePage += 1;
      await _db.setStateValue(deltaRoutesPageKey, '$routePage');
    }

    if (pendingHash != null && pendingHash.isNotEmpty) {
      await _db.setStateValue(activeHashKey, pendingHash);
    }

    await _db.deleteStateValue(deltaPendingHashKey);
    await _db.deleteStateValue(deltaSourceHashKey);
  }

  Future<void> _applyLocationDelta(SyncPage<LocationEntity> page) async {
    if (page.changes.isNotEmpty) {
      final upserts = <LocationEntity>[];
      final deletes = <int>[];

      for (final change in page.changes) {
        if (change.operation == SyncOperation.deleted) {
          deletes.add(change.id);
        } else if (change.entity != null) {
          upserts.add(change.entity!);
        }
      }

      await _db.upsertLocations(upserts);
      await _db.deleteLocationsByIds(
        <int>{...deletes, ...page.deletedIds}.toList(),
      );
      final persisted = await _db.countLocationsByIds(
        upserts.map((e) => e.id).toList(),
      );
      _log(
        'Delta locations page ${page.page}: upserts=${upserts.length}, deletes=${deletes.length + page.deletedIds.length}, persistedUpserts=$persisted',
      );
      return;
    }

    await _db.upsertLocations(page.items);
    await _db.deleteLocationsByIds(page.deletedIds);
    final persisted = await _db.countLocationsByIds(
      page.items.map((e) => e.id).toList(),
    );
    _log(
      'Delta locations page ${page.page}: items=${page.items.length}, deletes=${page.deletedIds.length}, persistedItems=$persisted',
    );
  }

  Future<void> _applyRouteDelta(SyncPage<RouteEntity> page) async {
    if (page.changes.isNotEmpty) {
      final upserts = <RouteEntity>[];
      final deletes = <int>[];

      for (final change in page.changes) {
        if (change.operation == SyncOperation.deleted) {
          deletes.add(change.id);
        } else if (change.entity != null) {
          upserts.add(change.entity!);
        }
      }

      await _db.upsertRoutes(upserts);
      await _db.deleteRoutesByIds(
        <int>{...deletes, ...page.deletedIds}.toList(),
      );
      return;
    }

    await _db.upsertRoutes(page.items);
    await _db.deleteRoutesByIds(page.deletedIds);
  }

  Future<void> _handleInvalidHashAndResync() async {
    await _db.deleteStateValue(activeHashKey);
    await _db.clearSyncProgressState();
    await _runInitialSync();
  }

  int _readStoredPage(String? rawPage) {
    final parsed = int.tryParse(rawPage ?? '');
    if (parsed == null || parsed < 1) {
      return 1;
    }
    return parsed;
  }

  bool _isPageDone<T>(SyncPage<T> page) {
    if (page.limit <= 0) {
      return true;
    }
    final totalPages = (page.total / page.limit).ceil();
    if (totalPages <= 1) {
      return true;
    }
    return page.page >= totalPages;
  }

  void _setProgress(SyncProgress value) {
    progress.value = value;
  }

  void _updatePageProgress<T>({
    required SyncStage stage,
    required bool isLocationPhase,
    required String messagePrefix,
    required SyncPage<T> response,
  }) {
    final totalPages = response.limit <= 0
        ? 1
        : (response.total / response.limit).ceil().clamp(1, 1000000);
    final pageCompletion = (response.page / totalPages).clamp(0.0, 1.0);
    final percentage = isLocationPhase
        ? pageCompletion * 50
        : 50 + (pageCompletion * 50);

    _setProgress(
      SyncProgress(
        stage: stage,
        percentage: percentage,
        message:
            '$messagePrefix (${response.page}/$totalPages) - ${response.items.length} items',
        currentPage: response.page,
        totalPages: totalPages,
        itemsInCurrentPage: response.items.length,
      ),
    );
  }
}
