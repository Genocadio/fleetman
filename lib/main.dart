import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth/auth_screen.dart';
import 'auth/credentials_manager.dart';
import 'auth/fleet_access_gate.dart';
import 'core/app_toast.dart' as app_toast;
import 'offices/offices_page.dart';
import 'requests/company_requests_page.dart';
import 'sync/local_sync_database.dart';
import 'sync/sync_coordinator.dart';
import 'sync/sync_debug_page.dart';
import 'sync/sync_models.dart';
import 'sync/sync_repository.dart';
import 'trips/trip_api_client.dart';
import 'trips/trip_models.dart';
import 'vehicles/vehicle_api_client.dart';
import 'vehicles/vehicle_models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TripTemplateStore.load();
  await CredentialsManager.instance.init();
  runApp(const FleetmanApp());
}

String _formatMoney(double value) {
  return 'RWF ${value.toStringAsFixed(2)}';
}

Future<bool> _hasInternetConnection() async {
  final results = await Connectivity().checkConnectivity();
  return results.any((r) => r != ConnectivityResult.none);
}

bool _isNoInternetErrorMessage(String message) {
  final lower = message.toLowerCase();
  return lower.contains('no internet connection') ||
      lower.contains('failed host lookup') ||
      lower.contains('no address associated with hostname') ||
      lower.contains('network is unreachable') ||
      lower.contains('socketexception');
}

void _showTopToast(
  BuildContext context, {
  required String message,
  bool isSuccess = true,
}) {
  app_toast.showTopToast(context, message: message, isSuccess: isSuccess);
}

class _RouteSearchFilters {
  const _RouteSearchFilters({this.origin, this.destination, this.cityRoute});

  final String? origin;
  final String? destination;
  final bool? cityRoute;
}

class _RouteMatchEvaluation {
  const _RouteMatchEvaluation(this.rank, this.matchType);

  final int rank;
  final String matchType;
}

class _RankedRouteSuggestion {
  const _RankedRouteSuggestion({
    required this.route,
    required this.rank,
    required this.matchType,
  });

  final RouteSuggestion route;
  final int rank;
  final String matchType;
}

String _normalizeSearchValue(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
}

bool _containsNormalized(String target, String query) {
  final normalizedQuery = _normalizeSearchValue(query);
  if (normalizedQuery.isEmpty) {
    return false;
  }
  return _normalizeSearchValue(target).contains(normalizedQuery);
}

String? _sanitizeSearchPart(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool? _extractCityRouteFilter(String text) {
  final lower = text.toLowerCase();
  final hasCity = lower.contains('@c');
  final hasProvince = lower.contains('@p');
  if (hasCity && hasProvince) {
    return null;
  }
  if (hasCity) {
    return true;
  }
  if (hasProvince) {
    return false;
  }
  return null;
}

String _removeCityRouteFilter(String text) {
  return text
      .replaceAll(RegExp('@c', caseSensitive: false), '')
      .replaceAll(RegExp('@p', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

    bool _routeSearchNeedsFullSource(String query) {
      final text = query.toLowerCase();
      return text.contains('!') ||
      text.contains(',') ||
      text.contains('@c') ||
      text.contains('@p');
    }

_RouteSearchFilters _parseRouteSearchText(String searchText) {
  if (searchText.trim().isEmpty) {
    return const _RouteSearchFilters();
  }

  final cityRoute = _extractCityRouteFilter(searchText);
  final text = _removeCityRouteFilter(searchText.trim());
  if (text.isEmpty) {
    return _RouteSearchFilters(cityRoute: cityRoute);
  }

  if (text.contains(',')) {
    final commaIndex = text.indexOf(',');
    final first = text.substring(0, commaIndex).trim();
    final second = text.substring(commaIndex + 1).trim();
    final firstIsDestinationMarker = first.startsWith('!');
    final secondIsDestinationMarker = second.startsWith('!');
    final firstValue = _sanitizeSearchPart(first.replaceFirst(RegExp('^!'), ''));
    final secondValue = _sanitizeSearchPart(
      second.replaceFirst(RegExp('^!'), ''),
    );

    if (firstIsDestinationMarker && secondValue != null) {
      return _RouteSearchFilters(
        origin: secondValue,
        destination: firstValue,
        cityRoute: cityRoute,
      );
    }
    if (firstIsDestinationMarker && secondValue == null) {
      return _RouteSearchFilters(
        origin: null,
        destination: firstValue,
        cityRoute: cityRoute,
      );
    }
    if (!firstIsDestinationMarker && secondIsDestinationMarker) {
      return _RouteSearchFilters(
        origin: firstValue,
        destination: secondValue,
        cityRoute: cityRoute,
      );
    }
    if (firstValue == null && secondValue != null) {
      return _RouteSearchFilters(
        origin: null,
        destination: secondValue,
        cityRoute: cityRoute,
      );
    }
    if (firstValue != null && secondValue == null) {
      return _RouteSearchFilters(
        origin: firstValue,
        destination: null,
        cityRoute: cityRoute,
      );
    }

    return _RouteSearchFilters(
      origin: firstValue,
      destination: secondValue,
      cityRoute: cityRoute,
    );
  }

  if (text.startsWith('!')) {
    return _RouteSearchFilters(
      destination: _sanitizeSearchPart(text.replaceFirst(RegExp('^!'), '')),
      cityRoute: cityRoute,
    );
  }

  return _RouteSearchFilters(origin: _sanitizeSearchPart(text), cityRoute: cityRoute);
}

_RouteMatchEvaluation? _evaluateRouteSuggestion(
  RouteSuggestion route,
  _RouteSearchFilters filters,
) {
  if (filters.cityRoute != null) {
    if (route.cityRoute == null || route.cityRoute != filters.cityRoute) {
      return null;
    }
  }

  final originQuery = filters.origin?.trim() ?? '';
  final destinationQuery = filters.destination?.trim() ?? '';

  final hasOriginQuery = originQuery.isNotEmpty;
  final hasDestinationQuery = destinationQuery.isNotEmpty;

  final originMatches = hasOriginQuery && _containsNormalized(route.origin, originQuery);
  final destinationMatches = hasDestinationQuery &&
      _containsNormalized(route.destination, destinationQuery);
  final originWaypointMatches = hasOriginQuery &&
      route.waypoints.any((wp) => _containsNormalized(wp, originQuery));
  final destinationWaypointMatches = hasDestinationQuery &&
      route.waypoints.any((wp) => _containsNormalized(wp, destinationQuery));

  if (hasOriginQuery && hasDestinationQuery) {
    if (originMatches && destinationMatches) {
      return const _RouteMatchEvaluation(0, 'origin+destination');
    }
    if (originMatches && destinationWaypointMatches) {
      return const _RouteMatchEvaluation(1, 'origin+destination_waypoint');
    }
    if (originWaypointMatches && destinationMatches) {
      return const _RouteMatchEvaluation(2, 'origin_waypoint+destination');
    }
    if (originWaypointMatches && destinationWaypointMatches) {
      return const _RouteMatchEvaluation(
        3,
        'origin_waypoint+destination_waypoint',
      );
    }
    return null;
  }

  if (hasOriginQuery) {
    if (originMatches) {
      return const _RouteMatchEvaluation(0, 'origin');
    }
    if (originWaypointMatches) {
      return const _RouteMatchEvaluation(1, 'origin_waypoint');
    }
    return null;
  }

  if (hasDestinationQuery) {
    if (destinationMatches) {
      return const _RouteMatchEvaluation(0, 'destination');
    }
    if (destinationWaypointMatches) {
      return const _RouteMatchEvaluation(1, 'destination_waypoint');
    }
    return null;
  }

  return const _RouteMatchEvaluation(0, 'no_filter');
}

List<_RankedRouteSuggestion> _rankRouteSuggestions(
  List<RouteSuggestion> source,
  String rawSearchText,
) {
  final filters = _parseRouteSearchText(rawSearchText);
  return source
      .map((route) {
        final evaluation = _evaluateRouteSuggestion(route, filters);
        if (evaluation == null) {
          return null;
        }
        return _RankedRouteSuggestion(
          route: route,
          rank: evaluation.rank,
          matchType: evaluation.matchType,
        );
      })
      .whereType<_RankedRouteSuggestion>()
      .toList()
    ..sort((a, b) {
      final rankCompare = a.rank.compareTo(b.rank);
      if (rankCompare != 0) {
        return rankCompare;
      }
      return (a.route.routeId ?? 0).compareTo(b.route.routeId ?? 0);
    });
}

// Removed _seedRouteSuggestions since we'll use active database search

class TripTemplate {
  const TripTemplate({
    required this.id,
    this.routeId,
    required this.origin,
    required this.destination,
    required this.baseFare,
    required this.waypoints,
    required this.waypointPrices,
    required this.waypointIds,
    required this.savedAt,
    this.isReversed = false,
  });

  final String id;
  final int? routeId;
  final String origin;
  final String destination;
  final double baseFare;
  final List<String> waypoints;
  final Map<String, double> waypointPrices;
  final Map<String, int> waypointIds;
  final DateTime savedAt;
  final bool isReversed;

  RouteSuggestion toRouteSuggestion() {
    return RouteSuggestion(
      routeId: routeId,
      origin: origin,
      destination: destination,
      departureTime: '',
      baseFare: baseFare,
      waypoints: List<String>.from(waypoints),
      waypointPrices: Map<String, double>.from(waypointPrices),
      waypointIds: Map<String, int>.from(waypointIds),
      isReversed: isReversed,
    );
  }
}

class TripTemplateStore {
  static final ValueNotifier<List<TripTemplate>> templates =
      ValueNotifier<List<TripTemplate>>(<TripTemplate>[]);

  /// Load all persisted templates from Drift on startup.
  static Future<void> load() async {
    final rows = await LocalSyncDatabase.instance.getAllTemplates();
    templates.value = rows.map(_fromDrift).toList();
  }

  static Future<void> add(TripTemplate template) async {
    await LocalSyncDatabase.instance.insertTemplate(_toDrift(template));
    await load();
  }

  static Future<void> update(TripTemplate template) async {
    await LocalSyncDatabase.instance.updateTemplate(_toDrift(template));
    await load();
  }

  static Future<void> delete(String id) async {
    await LocalSyncDatabase.instance.deleteTemplate(id);
    templates.value = templates.value.where((t) => t.id != id).toList();
  }

  // --- Mappers ---
  static TripTemplate _fromDrift(DriftTripTemplate row) {
    return TripTemplate(
      id: row.id,
      routeId: row.routeId,
      origin: row.origin,
      destination: row.destination,
      baseFare: row.baseFare,
      waypoints: (jsonDecode(row.waypoints) as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      waypointPrices: (jsonDecode(row.waypointPrices) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
      waypointIds: (jsonDecode(row.waypointIds) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      ),
      savedAt: DateTime.fromMillisecondsSinceEpoch(row.savedAt),
      isReversed: row.isReversed,
    );
  }

  static DriftTripTemplate _toDrift(TripTemplate t) {
    return DriftTripTemplate(
      id: t.id,
      routeId: t.routeId,
      origin: t.origin,
      destination: t.destination,
      baseFare: t.baseFare,
      waypoints: jsonEncode(t.waypoints),
      waypointPrices: jsonEncode(t.waypointPrices),
      waypointIds: jsonEncode(t.waypointIds),
      savedAt: t.savedAt.millisecondsSinceEpoch,
      isReversed: t.isReversed,
    );
  }
}

class FleetmanApp extends StatefulWidget {
  const FleetmanApp({super.key});

  @override
  State<FleetmanApp> createState() => _FleetmanAppState();
}

class _FleetmanAppState extends State<FleetmanApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleThemeMode() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFE7EFF0);
    const primary = Color(0xFF0E5A57);
    const secondary = Color(0xFF4EA5A1);
    const darkBackground = Color(0xFF0E1517);
    const darkSurface = Color(0xFF162224);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fleetman',
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          secondary: secondary,
          surface: Colors.white,
          brightness: Brightness.light,
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: Color(0xFF143333),
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF143333),
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF4D6269),
            height: 1.35,
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: darkBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          secondary: secondary,
          surface: darkSurface,
          brightness: Brightness.dark,
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: Color(0xFFF0F7F7),
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF0F7F7),
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFFB7C9CB),
            height: 1.35,
          ),
        ),
      ),
      home: ValueListenableBuilder<bool>(
        valueListenable: CredentialsManager.instance.isLoggedInNotifier,
        builder: (context, isLoggedIn, child) {
          if (!isLoggedIn) return const AuthScreen();
          return const FleetAccessGate(child: HomeScreen());
        },
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';
  VehicleFilter _activeFilter = VehicleFilter.all;
  _DockMenuType _openDockMenu = _DockMenuType.none;
  final ScrollController _scrollController = ScrollController();
  final VehicleApiClient _vehicleApiClient = VehicleApiClient();
  final List<Vehicle> _vehicles = [];
  Timer? _searchDebounce;
  bool _isInitialHydrating = true;
  bool _isLoadingMore = false;
  bool _isFetchingVehicles = false;
  bool _hasMorePages = true;
  int _currentPage = 0;
  int _totalPages = 1;
  String _effectiveQuery = '';
  String _effectivePlateQuery = '';
  String _effectiveDriverQuery = '';

  static const int _pageSize = 20;
  static const Duration _cacheTtl = Duration(minutes: 5);
  static final Map<String, _VehicleCacheEntry> _vehicleCacheByKey =
      <String, _VehicleCacheEntry>{};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    SyncCoordinator.instance.syncOnAppOpenInBackground();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchVehicles(reset: true, preferCache: true);
    });
  }

  BackendVehicleStatus? get _activeBackendStatus {
    switch (_activeFilter) {
      case VehicleFilter.all:
        return null;
      case VehicleFilter.occupied:
        return BackendVehicleStatus.occupied;
      case VehicleFilter.available:
        return BackendVehicleStatus.available;
      case VehicleFilter.maintenance:
        return BackendVehicleStatus.maintenance;
      case VehicleFilter.outOfService:
        return BackendVehicleStatus.outOfService;
    }
  }

  String _cacheKeyFor({required int companyId}) {
    return '$companyId|${_activeBackendStatus?.name ?? 'all'}|${_effectiveQuery.toLowerCase()}|$_pageSize';
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      final normalized = _searchQuery.trim();
      if (normalized == _effectiveQuery) {
        return;
      }
      _effectiveQuery = normalized;
      
      // Parse search query: if starts with @, search by driver name
      if (normalized.startsWith('@')) {
        _effectivePlateQuery = '';
        _effectiveDriverQuery = normalized.substring(1); // Remove @
      } else {
        _effectivePlateQuery = normalized;
        _effectiveDriverQuery = '';
      }
      
      _fetchVehicles(reset: true, preferCache: false);
    });
  }

  void _onFilterSelected(VehicleFilter filter) {
    if (_activeFilter == filter) {
      setState(() => _openDockMenu = _DockMenuType.none);
      return;
    }

    setState(() {
      _activeFilter = filter;
      _openDockMenu = _DockMenuType.none;
    });

    unawaited(_fetchVehicles(reset: true, preferCache: true));
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _toggleTheme() {
    final state = context.findAncestorStateOfType<_FleetmanAppState>();
    state?._toggleThemeMode();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMorePages) {
      return;
    }

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 220) {
      _fetchVehicles(reset: false);
    }
  }

  Future<void> _onRefresh() async {
    await _fetchVehicles(reset: true, forceRefresh: true);
  }

  void _applyVehicleUpdate(Vehicle updatedVehicle) {
    final updatedVehicles = List<Vehicle>.from(_vehicles);
    final index = updatedVehicles.indexWhere(
      (vehicle) => vehicle.backendId == updatedVehicle.backendId,
    );

    if (index == -1) {
      return;
    }

    updatedVehicles[index] = updatedVehicle;

    setState(() {
      _vehicles
        ..clear()
        ..addAll(updatedVehicles);
    });

    for (final entry in _vehicleCacheByKey.entries) {
      final cachedVehicles = List<Vehicle>.from(entry.value.vehicles);
      final cachedIndex = cachedVehicles.indexWhere(
        (vehicle) => vehicle.backendId == updatedVehicle.backendId,
      );
      if (cachedIndex == -1) {
        continue;
      }

      cachedVehicles[cachedIndex] = updatedVehicle;
      _vehicleCacheByKey[entry.key] = _VehicleCacheEntry(
        vehicles: cachedVehicles,
        currentPage: entry.value.currentPage,
        totalPages: entry.value.totalPages,
        hasMorePages: entry.value.hasMorePages,
        cachedAt: DateTime.now(),
      );
    }
  }

  void _applyVehiclePatch({
    required int backendId,
    String? driverName,
    BackendVehicleStatus? backendStatus,
    bool? isOccupied,
    int? usedSeats,
  }) {
    Vehicle patchVehicle(Vehicle vehicle) {
      return vehicle.copyWith(
        driverName: driverName,
        backendStatus: backendStatus,
        isOccupied: isOccupied,
        usedSeats: usedSeats,
      );
    }

    final updatedVehicles = List<Vehicle>.from(_vehicles);
    final index = updatedVehicles.indexWhere(
      (vehicle) => vehicle.backendId == backendId,
    );
    if (index != -1) {
      updatedVehicles[index] = patchVehicle(updatedVehicles[index]);
      setState(() {
        _vehicles
          ..clear()
          ..addAll(updatedVehicles);
      });
    }

    for (final entry in _vehicleCacheByKey.entries) {
      final cachedVehicles = List<Vehicle>.from(entry.value.vehicles);
      final cachedIndex = cachedVehicles.indexWhere(
        (vehicle) => vehicle.backendId == backendId,
      );
      if (cachedIndex == -1) {
        continue;
      }

      cachedVehicles[cachedIndex] = patchVehicle(cachedVehicles[cachedIndex]);
      _vehicleCacheByKey[entry.key] = _VehicleCacheEntry(
        vehicles: cachedVehicles,
        currentPage: entry.value.currentPage,
        totalPages: entry.value.totalPages,
        hasMorePages: entry.value.hasMorePages,
        cachedAt: DateTime.now(),
      );
    }
  }

  void _applyVehicleSyncResult(VehicleConfigSyncResult result) {
    _applyVehicleUpdate(result.primaryVehicle);
    final patch = result.secondaryVehiclePatch;
    if (patch == null) {
      return;
    }

    _applyVehiclePatch(
      backendId: patch.backendId,
      driverName: patch.driverName,
      backendStatus: patch.backendStatus,
      isOccupied: patch.isOccupied,
      usedSeats: patch.usedSeats,
    );
  }

  Future<void> _fetchVehicles({
    required bool reset,
    bool preferCache = false,
    bool forceRefresh = false,
  }) async {
    if (_isFetchingVehicles) {
      return;
    }

    if (!reset && (!_hasMorePages || _isInitialHydrating)) {
      return;
    }

    final companyId = await CredentialsManager.instance.getCompanyId();
    if (companyId == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isInitialHydrating = false;
        _isLoadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing company ID. Please log in again.'),
        ),
      );
      return;
    }

    final cacheKey = _cacheKeyFor(companyId: companyId);
    final now = DateTime.now();
    if (reset && preferCache && !forceRefresh) {
      final cached = _vehicleCacheByKey[cacheKey];
      if (cached != null && now.difference(cached.cachedAt) < _cacheTtl) {
        if (!mounted) {
          return;
        }
        setState(() {
          _vehicles
            ..clear()
            ..addAll(cached.vehicles);
          _currentPage = cached.currentPage;
          _totalPages = cached.totalPages;
          _hasMorePages = cached.hasMorePages;
          _isInitialHydrating = false;
          _isLoadingMore = false;
        });
        return;
      }
    }

    final hasInternet = await _hasInternetConnection();
    if (!hasInternet) {
      final cached = _vehicleCacheByKey[cacheKey];
      if (cached != null) {
        if (mounted) {
          setState(() {
            _vehicles
              ..clear()
              ..addAll(cached.vehicles);
            _currentPage = cached.currentPage;
            _totalPages = cached.totalPages;
            _hasMorePages = cached.hasMorePages;
            _isInitialHydrating = false;
            _isLoadingMore = false;
          });
          _showTopToast(
            context,
            message: 'No internet connection. Showing cached vehicles.',
            isSuccess: false,
          );
        }
        return;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _isInitialHydrating = false;
        _isLoadingMore = false;
      });
      _showTopToast(
        context,
        message: 'No internet connection and no cached vehicles available.',
        isSuccess: false,
      );
      return;
    }

    _isFetchingVehicles = true;
    if (!mounted) {
      _isFetchingVehicles = false;
      return;
    }

    setState(() {
      if (reset) {
        _isInitialHydrating = true;
      } else {
        _isLoadingMore = true;
      }
    });

    final token = await CredentialsManager.instance.getAccessToken();
    final requestedPage = reset ? 0 : (_currentPage + 1);

    try {
      final page = await _vehicleApiClient.fetchCompanyVehicles(
        companyId: companyId,
        page: requestedPage,
        size: _pageSize,
        plate: _effectivePlateQuery.isEmpty ? null : _effectivePlateQuery,
        driverName: _effectiveDriverQuery.isEmpty ? null : _effectiveDriverQuery,
        status: _activeBackendStatus,
        accessToken: token,
      );

      final incomingVehicles = page.content.map(Vehicle.fromSummary).toList();

      if (!mounted) {
        _isFetchingVehicles = false;
        return;
      }

      setState(() {
        if (reset) {
          _vehicles
            ..clear()
            ..addAll(incomingVehicles);
        } else {
          _vehicles.addAll(incomingVehicles);
        }
        _currentPage = page.number;
        _totalPages = page.totalPages;
        _hasMorePages = !page.last;
        _isInitialHydrating = false;
        _isLoadingMore = false;
      });

      _vehicleCacheByKey[cacheKey] = _VehicleCacheEntry(
        vehicles: List<Vehicle>.from(_vehicles),
        currentPage: _currentPage,
        totalPages: _totalPages,
        hasMorePages: _hasMorePages,
        cachedAt: now,
      );
    } catch (e) {
      if (!mounted) {
        _isFetchingVehicles = false;
        return;
      }
      setState(() {
        _isInitialHydrating = false;
        _isLoadingMore = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load vehicles: $e')));
    } finally {
      _isFetchingVehicles = false;
    }
  }

  List<Vehicle> get _filteredVehicles => _vehicles;

  int get _occupiedCount => _vehicles
      .where((v) => v.backendStatus == BackendVehicleStatus.occupied)
      .length;

  int get _availableCount => _vehicles
      .where((v) => v.backendStatus == BackendVehicleStatus.available)
      .length;

  int get _maintenanceCount => _vehicles
      .where((v) => v.backendStatus == BackendVehicleStatus.maintenance)
      .length;

  int get _outOfServiceCount => _vehicles
      .where((v) => v.backendStatus == BackendVehicleStatus.outOfService)
      .length;

  @override
  Widget build(BuildContext context) {
    final filteredVehicles = _filteredVehicles;
    final horizontalInset = (MediaQuery.sizeOf(context).width * 0.02).clamp(
      8.0,
      10.0,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topListPadding = EdgeInsets.fromLTRB(
      horizontalInset,
      MediaQuery.paddingOf(context).top + 12,
      horizontalInset,
      0,
    );

    return Scaffold(
      extendBody: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFF111A1D), Color(0xFF1A282C)]
                  : const [Color(0xFFF2F8F7), Color(0xFFD9E8E8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: ScrollConfiguration(
            behavior: const MaterialScrollBehavior().copyWith(
              overscroll: false,
            ),
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  horizontalInset,
                  0,
                  horizontalInset,
                  24,
                ),
                itemCount:
                    2 +
                    filteredVehicles.length +
                    ((_isInitialHydrating || filteredVehicles.isEmpty)
                        ? 1
                        : 0) +
                    (_isLoadingMore ? 1 : 0) +
                    (!_hasMorePages ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: topListPadding,
                      child: Center(
                        child: Text(
                          'Fleet Manager',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    );
                  }

                  if (index == 1) {
                    return const SizedBox(height: 12);
                  }

                  final vehicleStartIndex = 2;
                  final vehicleEndIndex =
                      vehicleStartIndex + filteredVehicles.length;

                  if (index >= vehicleStartIndex && index < vehicleEndIndex) {
                    final vehicle = filteredVehicles[index - vehicleStartIndex];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _VehicleCard(
                        vehicle: vehicle,
                        onTap: () async {
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute<VehicleConfigSyncResult>(
                              builder: (_) =>
                                  VehicleConfigPage(vehicle: vehicle),
                            ),
                          );
                          if (result is VehicleConfigSyncResult && mounted) {
                            _applyVehicleSyncResult(result);
                          }
                        },
                      ),
                    );
                  }

                  var tailCursor = vehicleEndIndex;

                  if (_isInitialHydrating) {
                    if (index == tailCursor) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      );
                    }
                    tailCursor += 1;
                  } else if (filteredVehicles.isEmpty) {
                    if (index == tailCursor) {
                      return const _EmptyState();
                    }
                    tailCursor += 1;
                  }

                  if (_isLoadingMore) {
                    if (index == tailCursor) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      );
                    }
                    tailCursor += 1;
                  }

                  if (!_hasMorePages && index == tailCursor) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text(
                          'You have reached the end',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(horizontalInset, 8, horizontalInset, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_openDockMenu != _DockMenuType.none)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _DockMenuPanel(
                    menuType: _openDockMenu,
                    selected: _activeFilter,
                    allCount: _vehicles.length,
                    occupiedCount: _occupiedCount,
                    availableCount: _availableCount,
                    maintenanceCount: _maintenanceCount,
                    outOfServiceCount: _outOfServiceCount,
                    onFilterSelected: _onFilterSelected,
                    onThemeToggle: () {
                      _toggleTheme();
                      setState(() => _openDockMenu = _DockMenuType.none);
                    },
                    onTemplatesTap: () {
                      setState(() => _openDockMenu = _DockMenuType.none);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const TripTemplatesPage(),
                        ),
                      );
                    },
                    onAccessRequestsTap: () {
                      setState(() => _openDockMenu = _DockMenuType.none);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const CompanyRequestsPage(),
                        ),
                      );
                    },
                    onOfficesTap: () {
                      setState(() => _openDockMenu = _DockMenuType.none);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const OfficesPage(),
                        ),
                      );
                    },
                    onSyncStorageTap: () {
                      setState(() => _openDockMenu = _DockMenuType.none);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SyncDebugPage(),
                        ),
                      );
                    },
                    onLogout: () async {
                      setState(() => _openDockMenu = _DockMenuType.none);
                      await CredentialsManager.instance.signOut();
                    },
                  ),
                ),
              _FloatingDock(
                selected: _activeFilter,
                onSearchChanged: _onSearchChanged,
                openMenuType: _openDockMenu,
                onProfileTap: () {
                  setState(() {
                    _openDockMenu = _openDockMenu == _DockMenuType.profile
                        ? _DockMenuType.none
                        : _DockMenuType.profile;
                  });
                },
                onFilterTap: () {
                  setState(() {
                    _openDockMenu = _openDockMenu == _DockMenuType.filter
                        ? _DockMenuType.none
                        : _DockMenuType.filter;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleCacheEntry {
  const _VehicleCacheEntry({
    required this.vehicles,
    required this.currentPage,
    required this.totalPages,
    required this.hasMorePages,
    required this.cachedAt,
  });

  final List<Vehicle> vehicles;
  final int currentPage;
  final int totalPages;
  final bool hasMorePages;
  final DateTime cachedAt;
}

enum VehicleFilter { all, occupied, available, maintenance, outOfService }

enum _DockMenuType { none, profile, filter }

class _FloatingDock extends StatelessWidget {
  const _FloatingDock({
    required this.selected,
    required this.onSearchChanged,
    required this.openMenuType,
    required this.onProfileTap,
    required this.onFilterTap,
  });

  final VehicleFilter selected;
  final ValueChanged<String> onSearchChanged;
  final _DockMenuType openMenuType;
  final VoidCallback onProfileTap;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _DockShell(
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: isDark
                ? const Color(0xFF26373C)
                : const Color(0xFFE1ECEB),
            child: IconButton(
              tooltip: 'Profile',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
              onPressed: onProfileTap,
              icon: Icon(
                Icons.account_circle_outlined,
                size: 18,
                color: openMenuType == _DockMenuType.profile
                    ? const Color(0xFF2CBDA8)
                    : (isDark
                          ? const Color(0xFF9FD9D1)
                          : const Color(0xFF0E5A57)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _SearchBox(onChanged: onSearchChanged)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onFilterTap,
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: openMenuType == _DockMenuType.filter
                    ? (isDark
                          ? const Color(0xFF284A46)
                          : const Color(0xFFD8ECE8))
                    : (isDark
                          ? const Color(0xFF213136)
                          : const Color(0xFFEAF3F2)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF3C575D)
                      : const Color(0xFFBFD0D5),
                ),
              ),
              child: Icon(
                Icons.tune_rounded,
                size: 19,
                color: isDark
                    ? const Color(0xFF9FD9D1)
                    : const Color(0xFF0E5A57),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DockMenuPanel extends StatelessWidget {
  const _DockMenuPanel({
    required this.menuType,
    required this.selected,
    required this.allCount,
    required this.occupiedCount,
    required this.availableCount,
    required this.maintenanceCount,
    required this.outOfServiceCount,
    required this.onFilterSelected,
    required this.onThemeToggle,
    required this.onTemplatesTap,
    required this.onAccessRequestsTap,
    required this.onOfficesTap,
    required this.onSyncStorageTap,
    required this.onLogout,
  });

  final _DockMenuType menuType;
  final VehicleFilter selected;
  final int allCount;
  final int occupiedCount;
  final int availableCount;
  final int maintenanceCount;
  final int outOfServiceCount;
  final ValueChanged<VehicleFilter> onFilterSelected;
  final VoidCallback onThemeToggle;
  final VoidCallback onTemplatesTap;
  final VoidCallback onAccessRequestsTap;
  final VoidCallback onOfficesTap;
  final VoidCallback? onSyncStorageTap;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    if (menuType == _DockMenuType.profile) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Align(
        alignment: Alignment.bottomLeft,
        child: _DockShell(
          borderRadius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: SizedBox(
            width: 196,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        CredentialsManager.instance.currentUsername.value,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (CredentialsManager
                          .instance
                          .currentCompanyName
                          .value
                          .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            CredentialsManager
                                .instance
                                .currentCompanyName
                                .value,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                Divider(
                  height: 16,
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
                _DockActionItem(
                  icon: Icons.contrast_rounded,
                  label: 'Switch theme',
                  onTap: onThemeToggle,
                ),
                _DockActionItem(
                  icon: Icons.bookmark_outline_rounded,
                  label: 'Templates',
                  onTap: onTemplatesTap,
                ),
                _DockActionItem(
                  icon: Icons.approval_rounded,
                  label: 'Requests',
                  onTap: onAccessRequestsTap,
                ),
                _DockActionItem(
                  icon: Icons.add_business_rounded,
                  label: 'Offices',
                  onTap: onOfficesTap,
                ),
                if (kDebugMode && onSyncStorageTap != null)
                  _DockActionItem(
                    icon: Icons.sync_alt_rounded,
                    label: 'Sync storage',
                    onTap: onSyncStorageTap!,
                  ),
                _DockActionItem(
                  icon: Icons.logout_rounded,
                  label: 'Logout',
                  onTap: onLogout,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.bottomRight,
      child: _DockShell(
        borderRadius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: SizedBox(
          width: 220,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DockFilterItem(
                label: 'All ($allCount)',
                active: selected == VehicleFilter.all,
                onTap: () => onFilterSelected(VehicleFilter.all),
              ),
              _DockFilterItem(
                label: 'Occupied ($occupiedCount)',
                active: selected == VehicleFilter.occupied,
                onTap: () => onFilterSelected(VehicleFilter.occupied),
              ),
              _DockFilterItem(
                label: 'Available ($availableCount)',
                active: selected == VehicleFilter.available,
                onTap: () => onFilterSelected(VehicleFilter.available),
              ),
              _DockFilterItem(
                label: 'Maintenance ($maintenanceCount)',
                active: selected == VehicleFilter.maintenance,
                onTap: () => onFilterSelected(VehicleFilter.maintenance),
              ),
              _DockFilterItem(
                label: 'Out of service ($outOfServiceCount)',
                active: selected == VehicleFilter.outOfService,
                onTap: () => onFilterSelected(VehicleFilter.outOfService),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockActionItem extends StatelessWidget {
  const _DockActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isDark ? const Color(0xFF8ED0C6) : const Color(0xFF0E5A57),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? const Color(0xFFE4F1F1)
                    : const Color(0xFF1B4548),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockFilterItem extends StatelessWidget {
  const _DockFilterItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              child: active
                  ? Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: isDark
                          ? const Color(0xFF8ED0C6)
                          : const Color(0xFF0E5A57),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active
                    ? (isDark
                          ? const Color(0xFF8ED0C6)
                          : const Color(0xFF0E5A57))
                    : (isDark
                          ? const Color(0xFFC1D5D8)
                          : const Color(0xFF2A4A50)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _GlassShell(
      borderRadius: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      child: TextField(
        maxLines: 1,
        textAlignVertical: TextAlignVertical.center,
        scrollPadding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom + 72,
        ),
        onChanged: onChanged,
        decoration: InputDecoration(
          isDense: true,
          alignLabelWithHint: true,
          border: InputBorder.none,
          hintText: 'Search by plate or driver name',
          hintStyle: TextStyle(
            color: isDark ? const Color(0xFF9AB5B9) : const Color(0xFF54666B),
          ),
          contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          prefixIconConstraints: const BoxConstraints.tightFor(
            width: 38,
            height: 38,
          ),
          prefixIcon: Center(
            child: Icon(
              Icons.search_rounded,
              color: isDark ? const Color(0xFF8AAEB2) : const Color(0xFF51666A),
            ),
          ),
        ),
        style: TextStyle(
          color: isDark ? const Color(0xFFE5F2F2) : const Color(0xFF2A4144),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _GlassShell(
      borderRadius: 18,
      child: Text(
        'No vehicles match this filter.',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFB8CDD0) : const Color(0xFF35545A),
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle, required this.onTap});

  final Vehicle vehicle;
  final VoidCallback onTap;

  String _statusLabel() {
    switch (vehicle.backendStatus) {
      case BackendVehicleStatus.available:
        return 'Available';
      case BackendVehicleStatus.maintenance:
        return 'Maintenance';
      case BackendVehicleStatus.outOfService:
        return 'Out of service';
      case BackendVehicleStatus.occupied:
        return 'Occupied';
    }
  }

  Color _indicatorColor() {
    switch (vehicle.backendStatus) {
      case BackendVehicleStatus.available:
        return const Color(0xFF2E9F8D);
      case BackendVehicleStatus.maintenance:
        return const Color(0xFFE3A13B);
      case BackendVehicleStatus.outOfService:
        return const Color(0xFFA44B4B);
      case BackendVehicleStatus.occupied:
        return const Color(0xFFE26D5A);
    }
  }

  void _showVehicleDetails(BuildContext context) {
    final statusLabel = _statusLabel();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          child: _GlassShell(
            borderRadius: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0x33545F63),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  statusLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF143333),
                  ),
                ),
                const SizedBox(height: 12),
                _DetailLine(label: 'Plate', value: vehicle.plate),
                _DetailLine(label: 'Driver', value: vehicle.driverDisplayName),
                _DetailLine(
                  label: 'Available seats',
                  value: '${vehicle.remainingSeats}',
                ),
                const _DetailLine(label: 'Trip data', value: 'Unavailable'),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusLabel = _statusLabel();
    final indicatorColor = _indicatorColor();

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showVehicleDetails(context),
      child: _GlassShell(
        borderRadius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Plate: ${vehicle.plate}  •  Driver: ${vehicle.driverDisplayName}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFFC4D6D8)
                                    : const Color(0xFF4D6269),
                              ),
                            ),
                          ),
                          if (!vehicle.hasDriver)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.person_outline_rounded,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Available seats: ${vehicle.remainingSeats}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFAFC5C8)
                              : const Color(0xFF35545A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: indicatorColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: indicatorColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              vehicle.backendStatus == BackendVehicleStatus.available
                  ? 'Ready for dispatch.'
                  : 'Trip details hidden on main view.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFFAFC5C8)
                    : const Color(0xFF35545A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VehicleConfigPage extends StatefulWidget {
  const VehicleConfigPage({super.key, required this.vehicle});

  final Vehicle vehicle;

  @override
  State<VehicleConfigPage> createState() => _VehicleConfigPageState();
}

class VehicleSyncPatch {
  const VehicleSyncPatch({
    required this.backendId,
    required this.driverName,
    required this.backendStatus,
    required this.isOccupied,
    required this.usedSeats,
  });

  final int backendId;
  final String driverName;
  final BackendVehicleStatus backendStatus;
  final bool isOccupied;
  final int usedSeats;
}

class VehicleConfigSyncResult {
  const VehicleConfigSyncResult({
    required this.primaryVehicle,
    this.secondaryVehiclePatch,
  });

  final Vehicle primaryVehicle;
  final VehicleSyncPatch? secondaryVehiclePatch;
}

class _VehicleConfigPageState extends State<VehicleConfigPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _departureTimeController =
      TextEditingController();
  final TextEditingController _routeSearchController = TextEditingController();
  final TextEditingController _waypointSearchController =
      TextEditingController();
  final TextEditingController _waypointsController = TextEditingController();
  final TextEditingController _driverSearchController = TextEditingController();
  late final TabController _tripTabController;
  final TripApiClient _tripApiClient = TripApiClient();
  final VehicleApiClient _vehicleApiClient = VehicleApiClient();

  RouteSuggestion? _selectedRoute;
  double _selectedRouteFare = 0;
  final List<String> _selectedWaypoints = [];
  final Map<String, double> _selectedWaypointPrices = {};
  final Map<String, int> _selectedWaypointIds = {};
  final List<String> _initialRouteWaypoints = [];
  final Map<String, double> _initialRouteWaypointPrices = {};
  final List<CompletedTrip> _recentTrips = [];
  final List<PlannedTrip> _queuedTrips = [];
  PlannedTrip? _apiCurrentTrip;
  bool _isTripsLoading = false;
  String? _tripsLoadError;
  late List<DriverProfile> _driverDirectory;
  late String _assignedDriverName;
  List<RouteSuggestion> _cachedSearchedRoutes = [];
  List<String> _cachedLocations = [];
  final Map<String, int> _cachedLocationIds = {};
  bool _selectedRouteFromTemplate = false;
  bool _searchTemplatesInScheduler = false;
  bool _driverAssignmentChanged = false;
  VehicleSyncPatch? _secondaryVehiclePatch;

  VehicleConfigSyncResult get _resultSync {
    return VehicleConfigSyncResult(
      primaryVehicle: widget.vehicle.copyWith(driverName: _assignedDriverName),
      secondaryVehiclePatch: _secondaryVehiclePatch,
    );
  }

  @override
  void initState() {
    super.initState();
    _tripTabController = TabController(length: 2, vsync: this);
    _assignedDriverName = widget.vehicle.driverName;
    _driverDirectory = [];
    _loadVehicleTrips();
  }

  @override
  void dispose() {
    _tripTabController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _departureTimeController.dispose();
    _routeSearchController.dispose();
    _waypointSearchController.dispose();
    _waypointsController.dispose();
    _driverSearchController.dispose();
    super.dispose();
  }

  void _clearDraftRoute() {
    setState(() {
      _selectedRoute = null;
      _selectedRouteFare = 0;
      _selectedWaypoints.clear();
      _selectedWaypointPrices.clear();
      _selectedWaypointIds.clear();
      _initialRouteWaypoints.clear();
      _initialRouteWaypointPrices.clear();
      _originController.clear();
      _destinationController.clear();
      _departureTimeController.clear();
      _waypointsController.clear();
      _routeSearchController.clear();
      _waypointSearchController.clear();
      _cachedLocationIds.clear();
      _selectedRouteFromTemplate = false;
    });
  }

  void _selectRoute(RouteSuggestion route, {bool fromTemplate = false}) {
    setState(() {
      _selectedRoute = route;
      _selectedRouteFromTemplate = fromTemplate;
      _selectedRouteFare = route.baseFare;
      _originController.text = route.origin;
      _destinationController.text = route.destination;
      _departureTimeController.text = route.departureTime;
      _selectedWaypoints
        ..clear()
        ..addAll(route.waypoints);
      _selectedWaypointPrices
        ..clear()
        ..addAll(route.waypointPrices);
      _selectedWaypointIds
        ..clear()
        ..addAll(route.waypointIds);
      _initialRouteWaypoints
        ..clear()
        ..addAll(route.waypoints);
      _initialRouteWaypointPrices
        ..clear()
        ..addAll(route.waypointPrices);
      _waypointsController.text = _selectedWaypoints.join(', ');
      _routeSearchController.clear();
    });
  }

  void _addWaypoint(String location, {int? locationId}) {
    if (_selectedWaypoints.contains(location)) {
      return;
    }

    setState(() {
      _selectedWaypoints.add(location);
      if (locationId != null) {
        _selectedWaypointIds[location] = locationId;
      }
      _waypointsController.text = _selectedWaypoints.join(', ');
    });
  }

  bool _hasCustomWaypointConfiguration() {
    if (_selectedRouteFromTemplate) {
      return true;
    }

    if (_selectedWaypoints.length != _initialRouteWaypoints.length) {
      return true;
    }

    for (int i = 0; i < _selectedWaypoints.length; i++) {
      if (_selectedWaypoints[i] != _initialRouteWaypoints[i]) {
        return true;
      }
    }

    for (final waypoint in _selectedWaypoints) {
      final selectedPrice = _selectedWaypointPrices[waypoint];
      final initialPrice = _initialRouteWaypointPrices[waypoint];
      if (!_sameOptionalPrice(selectedPrice, initialPrice)) {
        return true;
      }
    }

    return false;
  }

  bool _sameOptionalPrice(double? a, double? b) {
    if (a == null && b == null) {
      return true;
    }
    if (a == null || b == null) {
      return false;
    }
    return (a - b).abs() < 0.0001;
  }

  Future<double?> _openPriceEditorDialog({
    required String title,
    double? initialPrice,
  }) async {
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) =>
          _PriceEditorDialog(title: title, initialPrice: initialPrice),
    );
    return result;
  }

  Future<void> _loadCompanyDrivers() async {
    try {
      final hasInternet = await _hasInternetConnection();
      if (!hasInternet) {
        if (mounted) {
          _showTopToast(
            context,
            message: _driverDirectory.isEmpty
                ? 'No internet connection and no cached drivers available.'
                : 'No internet connection. Showing cached drivers.',
            isSuccess: false,
          );
        }
        return;
      }

      final companyId = await CredentialsManager.instance.getCompanyId();
      if (companyId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Missing company ID. Please log in again.'),
            ),
          );
        }
        return;
      }

      final token = await CredentialsManager.instance.getAccessToken();
      final vehicleApiClient = VehicleApiClient();

      final driverPage = await vehicleApiClient.fetchCompanyDrivers(
        companyId: companyId,
        page: 0,
        size: 100,
        accessToken: token,
      );

      if (!mounted) return;

      final drivers = driverPage.content
          .map(
            (dto) => DriverProfile(
              id: dto.id,
              name: dto.fullName,
              phone: dto.phone,
              assignedVehicleId: dto.vehicle?.id,
              assignedVehiclePlate: dto.vehicle?.licensePlate,
              hasActiveTrips: dto.vehicle != null,
              assignedVehicleStatus: dto.vehicle?.status,
            ),
          )
          .where(
            (driver) =>
                driver.name.trim().isNotEmpty &&
                driver.name.trim().toLowerCase() != 'unassigned',
          )
          .toList();

      debugPrint(
        '[DRIVER_LOAD] Loaded ${drivers.length} drivers. Details:',
      );
      for (final driver in drivers) {
        debugPrint(
          '  - "${driver.name}": plate=${driver.assignedVehiclePlate}, status=${driver.assignedVehicleStatus}, hasTrips=${driver.hasActiveTrips}',
        );
      }

      final currentHasTrips = _currentTrip != null || _queuedTrips.isNotEmpty;
      var updatedDrivers = List<DriverProfile>.from(drivers);
      if (widget.vehicle.hasDriver) {
        final normalizedCurrentName = widget.vehicle.driverName
            .trim()
            .toLowerCase();
        final currentIndex = updatedDrivers.indexWhere(
          (driver) =>
              driver.assignedVehiclePlate == widget.vehicle.plate ||
              driver.name.trim().toLowerCase() == normalizedCurrentName,
        );

        if (currentIndex > 0) {
          final current = updatedDrivers.removeAt(currentIndex);
          updatedDrivers.insert(0, current);
        } else if (currentIndex == -1 && normalizedCurrentName.isNotEmpty) {
          updatedDrivers.insert(
            0,
            DriverProfile(
              id: -1,
              name: widget.vehicle.driverName,
              phone: '',
              assignedVehicleId: widget.vehicle.backendId,
              assignedVehiclePlate: widget.vehicle.plate,
              hasActiveTrips: currentHasTrips,
              assignedVehicleStatus: widget.vehicle.backendStatus,
            ),
          );
        }
      }

      setState(() {
        _driverDirectory = updatedDrivers;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load drivers: $e')));
      }
    }
  }

  Future<void> _loadVehicleTrips() async {
    debugPrint(
      '[VehicleConfigPage] _loadVehicleTrips start vehicleId=${widget.vehicle.backendId} plate=${widget.vehicle.plate}',
    );

    final hasInternet = await _hasInternetConnection();
    if (!hasInternet) {
      if (mounted) {
        _showTopToast(
          context,
          message: (_queuedTrips.isNotEmpty ||
                  _recentTrips.isNotEmpty ||
                  _apiCurrentTrip != null)
              ? 'No internet connection. Showing cached trips.'
              : 'No internet connection and no cached trips available.',
          isSuccess: false,
        );
        setState(() {
          _isTripsLoading = false;
          _tripsLoadError = (_queuedTrips.isNotEmpty ||
                  _recentTrips.isNotEmpty ||
                  _apiCurrentTrip != null)
              ? null
              : 'No internet connection.';
        });
      }
      return;
    }

    setState(() {
      _isTripsLoading = true;
      _tripsLoadError = null;
    });

    try {
      final token = await CredentialsManager.instance.getAccessToken();
      debugPrint(
        '[VehicleConfigPage] _loadVehicleTrips tokenPresent=${token != null && token.isNotEmpty}',
      );

      final response = await _tripApiClient.fetchVehicleTrips(
        vehicleId: widget.vehicle.backendId,
        accessToken: token,
        limit: 100,
        offset: 0,
      );

      final scheduled = <PlannedTrip>[];
      final history = <CompletedTrip>[];
      PlannedTrip? inProgress;

      for (final trip in response.trips) {
        final status = trip.status.trim().toUpperCase();
        if (status == 'IN_PROGRESS') {
          inProgress ??= _toPlannedTrip(trip);
          continue;
        }

        if (status == 'SCHEDULED') {
          scheduled.add(_toPlannedTrip(trip));
          continue;
        }

        history.add(_toCompletedTrip(trip));
      }

      debugPrint(
        '[VehicleConfigPage] _loadVehicleTrips grouped current=${inProgress != null ? 1 : 0} scheduled=${scheduled.length} history=${history.length}',
      );

      if (!mounted) {
        debugPrint(
          '[VehicleConfigPage] _loadVehicleTrips skipped setState: unmounted',
        );
        return;
      }

      setState(() {
        _apiCurrentTrip = inProgress;
        _queuedTrips
          ..clear()
          ..addAll(scheduled);
        _recentTrips
          ..clear()
          ..addAll(history);
        _isTripsLoading = false;
      });

      debugPrint('[VehicleConfigPage] _loadVehicleTrips success');
    } catch (e) {
      debugPrint('[VehicleConfigPage] _loadVehicleTrips error=$e');

      if (!mounted) {
        debugPrint(
          '[VehicleConfigPage] _loadVehicleTrips catch skipped setState: unmounted',
        );
        return;
      }

      setState(() {
        _isTripsLoading = false;
        _tripsLoadError = e.toString();
      });

      debugPrint('[VehicleConfigPage] _loadVehicleTrips failed');
    }
  }

  PlannedTrip? get _currentTrip {
    return _apiCurrentTrip;
  }

  PlannedTrip? get _latestVehicleTrip {
    return _apiCurrentTrip ?? (_queuedTrips.isNotEmpty ? _queuedTrips.first : null);
  }

  bool get _latestTripAutoReturnEnabled {
    return _latestVehicleTrip?.autoReturn == true;
  }

  PlannedTrip _toPlannedTrip(VehicleTrip trip) {
    final route = trip.route;
    final waypoints = List<VehicleTripWaypoint>.from(trip.waypoints)
      ..sort((a, b) => (a.order ?? 9999).compareTo(b.order ?? 9999));

    return PlannedTrip(
      id: trip.id,
      origin: route?.origin?.displayName ?? 'Unknown origin',
      destination: route?.destination?.displayName ?? 'Unknown destination',
      waypoints: waypoints
          .map((w) => w.locationName)
          .where((name) => name.trim().isNotEmpty)
          .toList(),
      autoReturn: trip.autoReturn,
      rawStatus: trip.status.trim().toUpperCase(),
      statusLabel: _formatStatusLabel(trip.status),
      departureTime: _formatTripDateTime(
        trip.departureTime ?? trip.createdAt ?? trip.updatedAt,
      ),
    );
  }

  CompletedTrip _toCompletedTrip(VehicleTrip trip) {
    final route = trip.route;
    return CompletedTrip(
      id: trip.id,
      origin: route?.origin?.displayName ?? 'Unknown origin',
      destination: route?.destination?.displayName ?? 'Unknown destination',
      rawStatus: trip.status.trim().toUpperCase(),
      completedAt:
          '${_formatStatusLabel(trip.status)} • ${_formatTripDateTime(trip.updatedAt ?? trip.createdAt ?? trip.departureTime)}',
    );
  }

  String _formatStatusLabel(String rawStatus) {
    final normalized = rawStatus.trim().toUpperCase();
    if (normalized.isEmpty) {
      return 'Unknown';
    }

    return normalized
        .split('_')
        .map(
          (token) => token.isEmpty
              ? token
              : '${token[0]}${token.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _formatTripDateTime(int? unixValue) {
    if (unixValue == null || unixValue <= 0) {
      return 'Unknown time';
    }

    final milliseconds = unixValue < 1000000000000
        ? unixValue * 1000
        : unixValue;
    final dateTime = DateTime.fromMillisecondsSinceEpoch(
      milliseconds,
    ).toLocal();
    return _formatDateTimeLabel(dateTime);
  }

  Widget _buildUpcomingTripsTab(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isTripsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tripsLoadError != null) {
      return Center(
        child: Text(
          'Failed to load trips.',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFB7C9CB) : const Color(0xFF35545A),
          ),
        ),
      );
    }

    if (_queuedTrips.isEmpty) {
      return Center(
        child: Text(
          'No upcoming trips yet.',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFB7C9CB) : const Color(0xFF35545A),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _queuedTrips.length,
      separatorBuilder: (_, separatorIndex) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final trip = _queuedTrips[index];
        final status = trip.rawStatus;
        return _TripCard(
          trip: trip,
          indexLabel: '#${index + 1}',
          onDelete: (status == 'SCHEDULED' || status == 'CANCELLED')
              ? () => _deleteTripById(
                  tripId: trip.id,
                  rawStatus: status,
                )
              : null,
          onCancel: status == 'IN_PROGRESS'
              ? () => _cancelTripById(
                  tripId: trip.id,
                )
              : null,
        );
      },
    );
  }

  Widget _buildCompletedTripsTab(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isTripsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tripsLoadError != null) {
      return Center(
        child: Text(
          'Failed to load trips.',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFB7C9CB) : const Color(0xFF35545A),
          ),
        ),
      );
    }

    if (_recentTrips.isEmpty) {
      return Center(
        child: Text(
          'No completed trips yet.',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFB7C9CB) : const Color(0xFF35545A),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _recentTrips.length,
      separatorBuilder: (_, separatorIndex) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _CompletedTripCard(trip: _recentTrips[index]);
      },
    );
  }

  Future<void> _cancelTripById({
    required int tripId,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel trip'),
          content: const Text('This trip is in progress. Cancel it now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cancel Trip'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final token = await CredentialsManager.instance.getAccessToken();
    if (token == null || token.isEmpty) {
      if (mounted) {
        _showTopToast(
          context,
          message: 'Missing access token. Please log in again.',
          isSuccess: false,
        );
      }
      return;
    }

    final cancelResult = await _tripApiClient.deleteTripById(
      tripId: tripId,
      accessToken: token,
    );
    if (cancelResult is RemoteResultError<void>) {
      if (mounted) {
        _showTopToast(
          context,
          message: cancelResult.message,
          isSuccess: false,
        );
      }
      return;
    }

    await _loadVehicleTrips();
    if (mounted) {
      _showTopToast(context, message: 'Trip canceled successfully.');
    }
  }

  Future<void> _deleteTripById({
    required int tripId,
    required String rawStatus,
  }) async {
    if (rawStatus == 'IN_PROGRESS') {
      await _cancelTripById(tripId: tripId);
      return;
    }
    if (rawStatus == 'COMPLETED') {
      if (mounted) {
        _showTopToast(
          context,
          message: 'Completed trips cannot be deleted.',
          isSuccess: false,
        );
      }
      return;
    }
    if (rawStatus != 'SCHEDULED' && rawStatus != 'CANCELLED') {
      if (mounted) {
        _showTopToast(
          context,
          message: 'Only scheduled and cancelled trips can be deleted.',
          isSuccess: false,
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete trip'),
          content: const Text('Are you sure you want to delete this trip?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final token = await CredentialsManager.instance.getAccessToken();
    if (token == null || token.isEmpty) {
      if (mounted) {
        _showTopToast(
          context,
          message: 'Missing access token. Please log in again.',
          isSuccess: false,
        );
      }
      return;
    }

    final deleteResult = await _tripApiClient.deleteTripById(
      tripId: tripId,
      accessToken: token,
    );
    if (deleteResult is RemoteResultError<void>) {
      if (mounted) {
        _showTopToast(
          context,
          message: deleteResult.message,
          isSuccess: false,
        );
      }
      return;
    }

    await _loadVehicleTrips();
    if (mounted) {
      _showTopToast(context, message: 'Trip deleted successfully.');
    }
  }

  Future<void> _commitScheduledRoute({
    required DateTime departureDateTime,
    required bool autoReturn,
    bool isReversed = false,
  }) async {
    final route = _selectedRoute;
    if (route == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a saved route first.')),
      );
      return;
    }

    if (route.routeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot create trip from a dummy route without an ID.'),
        ),
      );
      return;
    }

    final waypoints = _selectedWaypoints.toList();

    if (route.origin.isEmpty || route.destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Route origin and destination are required.'),
        ),
      );
      return;
    }

    final hasInternet = await _hasInternetConnection();
    if (!hasInternet) {
      if (mounted) {
        _showTopToast(
          context,
          message: 'No internet connection. Unable to create trip.',
          isSuccess: false,
        );
      }
      return;
    }

    // --- API Payload Construction ---
    final hasCustomWaypointConfig = _hasCustomWaypointConfiguration();
    final noWaypoints = hasCustomWaypointConfig && waypoints.isEmpty;

    final customWaypoints = <CreateCustomWaypoint>[];
    if (hasCustomWaypointConfig && !noWaypoints) {
      for (int i = 0; i < waypoints.length; i++) {
        final waypointName = waypoints[i];
        final locationId =
            _selectedWaypointIds[waypointName] ?? route.waypointIds[waypointName];

        if (locationId == null || locationId <= 0) {
          if (mounted) {
            _showTopToast(
              context,
              message:
                  'Unable to send waypoint "$waypointName" because its location ID is missing. Re-select it and try again.',
              isSuccess: false,
            );
          }
          return;
        }

        customWaypoints.add(
          CreateCustomWaypoint(
            locationId: locationId,
            order: i + 1,
            price: _selectedWaypointPrices[waypointName],
          ),
        );
      }
    }

    final req = CreateTripRequest(
      routeId: route.routeId!,
      vehicleId: widget.vehicle.backendId,
      price: _selectedRouteFare,
      departureTime: departureDateTime.millisecondsSinceEpoch ~/ 1000,
      connectionMode: 'ONLINE',
      customWaypoints: customWaypoints,
      noWaypoints: noWaypoints,
      isReversed: isReversed,
      autoReturn: autoReturn,
    );

    final token = await CredentialsManager.instance.getAccessToken();
    final result = await TripApiClient().createTrip(req, accessToken: token);

    if (result is RemoteResultError) {
      if (mounted) {
        final message = (result as RemoteResultError).message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isNoInternetErrorMessage(message)
                  ? 'No internet connection. Unable to create trip.'
                  : 'Failed: $message',
            ),
          ),
        );
      }
      return;
    }

    await _loadVehicleTrips();

    if (mounted) {
      _showTopToast(context, message: 'Trip created successfully.');
    }

    _clearDraftRoute();
  }

  String _driverInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  DriverProfile? get _currentDriverProfile {
    final driverName = _assignedDriverName.trim();
    if (driverName.isEmpty) {
      return null;
    }

    final normalizedDriverName = driverName.toLowerCase();
    for (final driver in _driverDirectory) {
      if (driver.name.trim().toLowerCase() == normalizedDriverName) {
        return driver;
      }
    }

    return DriverProfile(
      id: -1,
      name: driverName,
      phone: 'No phone available',
      assignedVehicleId: widget.vehicle.backendId,
      assignedVehiclePlate: widget.vehicle.plate,
      hasActiveTrips: widget.vehicle.isOccupied,
      assignedVehicleStatus: widget.vehicle.backendStatus,
    );
  }

  Future<void> _callDriver(DriverProfile driver) async {
    final uri = Uri(scheme: 'tel', path: driver.phone);
    if (!await canLaunchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dialer is not available on this device.'),
          ),
        );
      }
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openDriverProfileModal() {
    // Don't show modal for occupied vehicles with drivers
    if (widget.vehicle.isOccupied && widget.vehicle.hasDriver) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot change driver for occupied vehicle. Wait for trip to complete.',
          ),
        ),
      );
      return;
    }

    final driver = _currentDriverProfile;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            0,
            12,
            12 + MediaQuery.paddingOf(context).bottom,
          ),
          child: _GlassShell(
            borderRadius: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Driver Profile',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      child: Text(
                        driver == null ? 'U' : _driverInitials(driver.name),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driver?.name ?? 'Unassigned',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            driver?.phone ?? 'No driver assigned',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFFBBD0D3)
                                  : const Color(0xFF35545A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (driver == null)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        unawaited(_openDriverModal());
                      },
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Assign Driver'),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _callDriver(driver),
                          icon: const Icon(Icons.call_rounded),
                          label: const Text('Call'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            unawaited(_openDriverModal());
                          },
                          icon: const Icon(Icons.swap_horiz_rounded),
                          label: const Text('Change Driver'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openScheduleTripModal() async {
    _routeSearchController.clear();
    _waypointSearchController.clear();
    _searchTemplatesInScheduler = false;

    final initialResults = await SyncRepository.instance.searchRoutes(
      '',
      limit: 5000,
    );
    if (mounted) {
      setState(() {
        _cachedSearchedRoutes = initialResults
            .map(_routeSuggestionFromRouteWithLocations)
            .toList();
      });
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            final routeQuery = _routeSearchController.text;
            final baseSuggestions = _searchTemplatesInScheduler
                ? TripTemplateStore.templates.value
                      .map((template) => template.toRouteSuggestion())
                      .toList()
                : _cachedSearchedRoutes;
            final rankedSuggestions = _rankRouteSuggestions(
              baseSuggestions,
              routeQuery,
            );
            final routeSuggestions = _selectedRoute == null
                ? rankedSuggestions.map((e) => e.route).toList()
                : const <RouteSuggestion>[];

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.fromLTRB(
                12,
                0,
                12,
                12 +
                    MediaQuery.paddingOf(context).bottom +
                    MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: _GlassShell(
                borderRadius: 20,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Schedule New Trip',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Save template',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 24,
                              height: 24,
                            ),
                            onPressed: _selectedRoute == null
                                ? null
                                : () {
                                    _saveCurrentSelectionAsTemplate();
                                    modalSetState(() {});
                                  },
                            icon: const Icon(Icons.save_outlined, size: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_selectedRoute == null) ...[
                        _TripInputField(
                          controller: _routeSearchController,
                          label: _searchTemplatesInScheduler
                              ? 'Search templates (supports ! , @c @p)'
                              : 'Search saved route (supports ! , @c @p)',
                          hint: 'e.g. musanze, rubavu or !musanze or @c kigali',
                          onChanged: (text) async {
                            final query = text.trim();
                            if (!_searchTemplatesInScheduler) {
                              final sourceQuery = _routeSearchNeedsFullSource(
                                query,
                              )
                                  ? ''
                                  : query;
                              final results = await SyncRepository.instance
                                  .searchRoutes(sourceQuery, limit: 5000);
                              if (mounted &&
                                  _routeSearchController.text.trim() == query) {
                                _cachedSearchedRoutes = results
                                    .map(_routeSuggestionFromRouteWithLocations)
                                    .toList();
                                modalSetState(() {});
                              }
                            } else {
                              modalSetState(() {});
                            }
                          },
                        ),
                        CheckboxListTile.adaptive(
                          value: _searchTemplatesInScheduler,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Search from templates'),
                          subtitle: Text(
                            _searchTemplatesInScheduler
                                ? 'Showing reusable trip templates.'
                                : 'Showing default saved routes.',
                          ),
                          onChanged: (value) {
                            _searchTemplatesInScheduler = value ?? false;
                            modalSetState(() {});
                          },
                        ),
                        const SizedBox(height: 8),
                        if (_searchTemplatesInScheduler &&
                            TripTemplateStore.templates.value.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              'No templates yet. Save one from this screen or from Templates.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFFB7CFD1)
                                    : const Color(0xFF35545A),
                              ),
                            ),
                          ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: routeSuggestions.length,
                            itemBuilder: (context, index) {
                              final route = routeSuggestions[index];
                              return _RouteSuggestionTile(
                                route: route,
                                onTap: () {
                                  _selectRoute(
                                    route,
                                    fromTemplate: _searchTemplatesInScheduler,
                                  );
                                  modalSetState(() {});
                                },
                              );
                            },
                          ),
                        ),
                      ] else ...[
                        _SelectedRouteCard(
                          route: _selectedRoute!,
                          routeFare: _selectedRouteFare,
                          waypoints: _selectedWaypoints,
                          waypointPrices: _selectedWaypointPrices,
                          onEditRouteFare: () async {
                            final price = await _openPriceEditorDialog(
                              title: 'Edit route fare',
                              initialPrice: _selectedRouteFare,
                            );
                            if (price == null) {
                              return;
                            }
                            setState(() => _selectedRouteFare = price);
                            modalSetState(() {});
                          },
                          onEditWaypointPrice: (waypoint) async {
                            final price = await _openPriceEditorDialog(
                              title: 'Edit price for $waypoint',
                              initialPrice: _selectedWaypointPrices[waypoint],
                            );
                            if (price == null) {
                              return;
                            }
                            setState(
                              () => _selectedWaypointPrices[waypoint] = price,
                            );
                            modalSetState(() {});
                          },
                          onMoveWaypoint: (fromIndex, toIndex) {
                            _moveWaypoint(fromIndex, toIndex);
                            modalSetState(() {});
                          },
                          onRemoveWaypoint: (waypoint) {
                            _removeWaypoint(waypoint);
                            modalSetState(() {});
                          },
                          onClear: () {
                            _clearDraftRoute();
                            modalSetState(() {});
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await _openWaypointSelectorModal();
                                  modalSetState(() {});
                                },
                                icon: const Icon(
                                  Icons.add_location_alt_outlined,
                                ),
                                label: const Text('Add Waypoints'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.outlined(
                              tooltip: 'Reverse route',
                              onPressed: _selectedRoute == null
                                  ? null
                                  : () {
                                      _reverseSelectedRoute();
                                      modalSetState(() {});
                                    },
                              style: IconButton.styleFrom(
                                foregroundColor:
                                    _selectedRoute?.isReversed == true
                                    ? const Color(0xFF0E5A57)
                                    : null,
                                backgroundColor:
                                    _selectedRoute?.isReversed == true
                                    ? const Color(0x1F2CBDA8)
                                    : null,
                              ),
                              icon: Icon(
                                Icons.swap_vert_rounded,
                                color: _selectedRoute?.isReversed == true
                                    ? const Color(0xFF0E5A57)
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: Opacity(
                            opacity: _latestTripAutoReturnEnabled ? 0.45 : 1,
                            child: FilledButton.icon(
                              onPressed: _latestTripAutoReturnEnabled
                                  ? null
                                  : () async {
                                      final confirmation =
                                          await _openDepartureTimeConfirmDialog();
                                      if (confirmation == null) {
                                        return;
                                      }
                                      _commitScheduledRoute(
                                        departureDateTime:
                                            confirmation.departureDateTime,
                                        autoReturn: confirmation.autoReturn,
                                        isReversed: confirmation.isReversed,
                                      );
                                      if (mounted) {
                                        Navigator.of(context).pop();
                                      }
                                    },
                              icon: const Icon(Icons.route_rounded),
                              label: const Text('Route Complete'),
                            ),
                          ),
                        ),
                        if (_latestTripAutoReturnEnabled) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Disable auto-return on the latest trip before scheduling another route.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color:
                                  Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFFB7CFD1)
                                  : const Color(0xFF35545A),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveCurrentSelectionAsTemplate() async {
    final route = _selectedRoute;
    if (route == null) {
      return;
    }

    final orderedWaypoints = List<String>.from(_selectedWaypoints);
    final prices = <String, double>{
      for (final waypoint in orderedWaypoints)
        waypoint: _selectedWaypointPrices[waypoint] ?? 0,
    };
    final waypointIds = <String, int>{
      for (final waypoint in orderedWaypoints)
        if ((_selectedWaypointIds[waypoint] ?? route.waypointIds[waypoint]) !=
            null)
          waypoint:
              (_selectedWaypointIds[waypoint] ?? route.waypointIds[waypoint])!,
    };

    await TripTemplateStore.add(
      TripTemplate(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        origin: route.origin,
        destination: route.destination,
        baseFare: _selectedRouteFare,
        waypoints: orderedWaypoints,
        waypointPrices: prices,
        waypointIds: waypointIds,
        savedAt: DateTime.now(),
        isReversed: route.isReversed,
      ),
    );

    if (mounted) {
      _showTopToast(context, message: 'Template saved for reuse.');
    }
  }

  void _removeWaypoint(String waypoint) {
    setState(() {
      _selectedWaypoints.remove(waypoint);
      _selectedWaypointPrices.remove(waypoint);
      _waypointsController.text = _selectedWaypoints.join(', ');
    });
  }

  void _moveWaypoint(int fromIndex, int toIndex) {
    if (fromIndex < 0 || fromIndex >= _selectedWaypoints.length) {
      return;
    }
    if (toIndex < 0 || toIndex >= _selectedWaypoints.length) {
      return;
    }

    setState(() {
      final waypoint = _selectedWaypoints.removeAt(fromIndex);
      _selectedWaypoints.insert(toIndex, waypoint);
      _waypointsController.text = _selectedWaypoints.join(', ');
    });
  }

  void _reverseSelectedRoute() {
    if (_selectedRoute == null) {
      return;
    }

    setState(() {
      final reversedWaypoints = _selectedWaypoints.reversed.toList();
      final currentRoute = _selectedRoute!;
      _selectedWaypoints
        ..clear()
        ..addAll(reversedWaypoints);
      _initialRouteWaypoints
        ..clear()
        ..addAll(reversedWaypoints);
      _waypointsController.text = _selectedWaypoints.join(', ');
      _selectedRoute = RouteSuggestion(
        routeId: currentRoute.routeId,
        origin: currentRoute.destination,
        destination: currentRoute.origin,
        departureTime: currentRoute.departureTime,
        baseFare: _selectedRouteFare,
        waypoints: reversedWaypoints,
        waypointPrices: Map<String, double>.from(_selectedWaypointPrices),
        waypointIds: Map<String, int>.from(currentRoute.waypointIds),
        isReversed: !currentRoute.isReversed,
      );
    });
  }

  Future<void> _openWaypointSelectorModal() async {
    _waypointSearchController.clear();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            final query = _waypointSearchController.text.trim().toLowerCase();
            final suggestions = _cachedLocations.where((location) {
              final matches =
                  query.isEmpty || location.toLowerCase().contains(query);
              final alreadySelected = _selectedWaypoints.contains(location);
              return matches && !alreadySelected;
            }).toList();

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.fromLTRB(
                12,
                0,
                12,
                12 +
                    MediaQuery.paddingOf(context).bottom +
                    MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: _GlassShell(
                borderRadius: 20,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Waypoints',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _TripInputField(
                        controller: _waypointSearchController,
                        label: 'Search area or waypoint',
                        hint: 'e.g. Museum Gate',
                        onChanged: (text) async {
                          final query = text.trim().toLowerCase();
                          final locs = await SyncRepository.instance
                              .searchLocations(query);
                          if (mounted &&
                              _waypointSearchController.text
                                      .trim()
                                      .toLowerCase() ==
                                  query) {
                            _cachedLocations = locs
                                .map((e) => e.displayName)
                                .toList();
                            _cachedLocationIds
                              ..clear()
                              ..addEntries(
                                locs.map((e) => MapEntry(e.displayName, e.id)),
                              );
                            modalSetState(() {});
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: suggestions.length,
                          itemBuilder: (context, index) {
                            final location = suggestions[index];
                            return _WaypointSuggestionTile(
                              location: location,
                              onTap: () async {
                                final price = await _openPriceEditorDialog(
                                  title: 'Set price for $location',
                                  initialPrice: _selectedWaypointPrices[location],
                                );
                                if (price == null) {
                                  return;
                                }
                                _addWaypoint(
                                  location,
                                  locationId: _cachedLocationIds[location],
                                );
                                setState(() {
                                  _selectedWaypointPrices[location] = price;
                                });
                                modalSetState(() {});
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Done'),
                        ),
                      ),
                  ],
                ),
              ),
              ),
            );
          },
        );
      },
    );
    _waypointSearchController.clear();
  }

  Future<TripConfirmationResult?> _openDepartureTimeConfirmDialog() async {
    final routeFallback = _selectedRoute?.departureTime ?? '';
    DateTime selectedDateTime =
        _parseDateTimeHint(routeFallback) ??
        DateTime.now().add(const Duration(hours: 1));
    bool autoReturn = false;

    final result = await showDialog<TripConfirmationResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            return AlertDialog(
              title: const Text('Select departure time and confirm'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDateTimeLabel(selectedDateTime),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final pickedDate = await showDatePicker(
                              context: dialogContext,
                              initialDate: selectedDateTime,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 1),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (pickedDate == null) {
                              return;
                            }

                            selectedDateTime = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              selectedDateTime.hour,
                              selectedDateTime.minute,
                            );
                            modalSetState(() {});
                          },
                          icon: const Icon(Icons.event_outlined),
                          label: const Text('Select date'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final pickedTime = await showTimePicker(
                              context: dialogContext,
                              initialTime: TimeOfDay.fromDateTime(
                                selectedDateTime,
                              ),
                            );
                            if (pickedTime == null) {
                              return;
                            }

                            selectedDateTime = DateTime(
                              selectedDateTime.year,
                              selectedDateTime.month,
                              selectedDateTime.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                            modalSetState(() {});
                          },
                          icon: const Icon(Icons.schedule_outlined),
                          label: const Text('Select time'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    value: autoReturn,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto-return after completion'),
                    subtitle: const Text(
                      'Create the reverse trip automatically on confirm',
                    ),
                    onChanged: (value) =>
                        modalSetState(() => autoReturn = value),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(
                    TripConfirmationResult(
                      departureDateTime: selectedDateTime,
                      autoReturn: autoReturn,
                      isReversed: _selectedRoute?.isReversed ?? false,
                    ),
                  ),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  Future<void> _toggleLatestTripAutoReturn(bool enabled) async {
    final token = await CredentialsManager.instance.getAccessToken();
    if (token == null || token.isEmpty) {
      if (mounted) {
        _showTopToast(
          context,
          message: 'Missing access token. Please log in again.',
          isSuccess: false,
        );
      }
      return;
    }

    final result = await _tripApiClient.toggleLatestVehicleTripAutoReturn(
      vehicleId: widget.vehicle.backendId,
      autoReturn: enabled,
      accessToken: token,
    );

    if (result is RemoteResultError<TripResponse>) {
      if (mounted) {
        _showTopToast(
          context,
          message: result.message,
          isSuccess: false,
        );
      }
      return;
    }

    if (mounted) {
      _showTopToast(
        context,
        message: enabled
            ? 'Auto-return enabled for latest trip.'
            : 'Auto-return disabled for latest trip.',
      );
    }

    await _loadVehicleTrips();
  }

  DateTime? _parseDateTimeHint(String hint) {
    final cleaned = hint.trim();
    if (cleaned.isEmpty) {
      return null;
    }

    final timeMatch = RegExp(
      r'^(\d{1,2}):(\d{2})(?:\s*([AaPp][Mm]))?$',
    ).firstMatch(cleaned);
    if (timeMatch == null) {
      return null;
    }

    var hour = int.parse(timeMatch.group(1)!);
    final minute = int.parse(timeMatch.group(2)!);
    final meridiem = timeMatch.group(3)?.toUpperCase();

    if (meridiem == 'AM' && hour == 12) {
      hour = 0;
    } else if (meridiem == 'PM' && hour < 12) {
      hour += 12;
    }

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  String _formatDateTimeLabel(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final meridiem = value.hour < 12 ? 'AM' : 'PM';
    return '${months[value.month - 1]} ${value.day}, ${value.year}  ${hour.toString().padLeft(2, '0')}:$minute $meridiem';
  }

  List<DriverProfile> get _filteredDrivers {
    final query = _driverSearchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _driverDirectory
            .where(
              (driver) => driver.assignedVehiclePlate != widget.vehicle.plate,
            )
            .toList()
        : _driverDirectory.where((driver) {
          if (driver.assignedVehiclePlate == widget.vehicle.plate) {
            return false;
          }
          return driver.name.toLowerCase().contains(query) ||
              (driver.assignedVehiclePlate ?? '').toLowerCase().contains(query);
        }).toList();

    // Log assignability for debug
    debugPrint(
      '[FILTERED_DRIVERS] Query="$query", Found ${filtered.length} drivers:',
    );
    for (final driver in filtered) {
      final assignable = _isDriverAssignableToVehicle(driver);
      debugPrint(
        '  → "${driver.name}" - ${assignable ? "✅ ENABLED" : "❌ DISABLED"}',
      );
    }

    return filtered;
  }

  bool _isDriverAssignableToVehicle(DriverProfile driver) {
    // Driver is assignable if not already on this vehicle.
    // For drivers already assigned to other vehicles: only swappable if their vehicle is AVAILABLE.
    
    if (driver.assignedVehiclePlate == widget.vehicle.plate) {
      debugPrint(
        '❌ [DRIVER_AVAILABILITY] "${driver.name}" - NOT assignable: already on current vehicle (${widget.vehicle.plate})',
      );
      return false; // Can't re-assign to same vehicle
    }
    
    if (driver.assignedVehiclePlate == null) {
      debugPrint(
        '✅ [DRIVER_AVAILABILITY] "${driver.name}" - ASSIGNABLE: unassigned driver (no vehicle)',
      );
      return true; // Unassigned drivers are always swappable
    }
    
    // Only swappable if assigned vehicle status is AVAILABLE
    final isAvailable =
        driver.assignedVehicleStatus == BackendVehicleStatus.available;
    if (isAvailable) {
      debugPrint(
        '✅ [DRIVER_AVAILABILITY] "${driver.name}" - ASSIGNABLE: on vehicle ${driver.assignedVehiclePlate} (status: AVAILABLE)',
      );
    } else {
      debugPrint(
        '❌ [DRIVER_AVAILABILITY] "${driver.name}" - NOT assignable: on vehicle ${driver.assignedVehiclePlate} (status: ${driver.assignedVehicleStatus})',
      );
    }
    return isAvailable;
  }

  Future<void> _handleDriverTap(DriverProfile selected) async {
    debugPrint(
      '[DRIVER_TAP] "${selected.name}" tapped for vehicle ${widget.vehicle.plate}. Current assigned: "$_assignedDriverName"',
    );

    if (selected.name == _assignedDriverName) {
      Navigator.of(context).pop();
      return;
    }

    final selectedIndex = _driverDirectory.indexWhere(
      (d) => d.name == selected.name,
    );
    if (selectedIndex == -1) {
      return;
    }

    final currentIndex = _driverDirectory.indexWhere(
      (d) => d.name == _assignedDriverName,
    );
    final selectedVehicleId = selected.assignedVehicleId;
    final currentVehicleId = currentIndex != -1
        ? (_driverDirectory[currentIndex].assignedVehicleId ?? widget.vehicle.backendId)
        : widget.vehicle.backendId;
    final selectedHasVehicle = selectedVehicleId != null;
    final currentHasDriver = _assignedDriverName.isNotEmpty;
    debugPrint(
      '[DRIVER_TAP_ANALYSIS] selectedHasVehicle=$selectedHasVehicle, currentHasDriver=$currentHasDriver, selectedVehicleId=$selectedVehicleId, currentVehicleId=$currentVehicleId',
    );
    final token = await CredentialsManager.instance.getAccessToken();

    if (token == null || token.isEmpty) {
      if (mounted) {
        _showTopToast(
          context,
          message: 'Missing access token. Please log in again.',
          isSuccess: false,
        );
      }
      return;
    }

    Future<void> assignSelectedToCurrentVehicle() async {
      if (selectedHasVehicle) {
        await _vehicleApiClient.unassignDriverFromVehicle(
          vehicleId: selectedVehicleId,
          accessToken: token,
        );
      }

      if (currentHasDriver) {
        await _vehicleApiClient.unassignDriverFromVehicle(
          vehicleId: currentVehicleId,
          accessToken: token,
        );
      }

      try {
        await _vehicleApiClient.assignDriverToVehicle(
          vehicleId: widget.vehicle.backendId,
          driverId: selected.id,
          accessToken: token,
        );
      } catch (e) {
        if (mounted) {
          _showTopToast(
            context,
            message: 'Failed to assign driver: $e',
            isSuccess: false,
          );
        }
        return;
      }

      setState(() {
        if (currentIndex != -1) {
          _driverDirectory[currentIndex] = _driverDirectory[currentIndex]
              .copyWith(clearAssignedVehiclePlate: true, hasActiveTrips: false);
        }
        _driverDirectory[selectedIndex] = _driverDirectory[selectedIndex]
            .copyWith(
              assignedVehiclePlate: widget.vehicle.plate,
              hasActiveTrips: _currentTrip != null || _queuedTrips.isNotEmpty,
            );
        _assignedDriverName = selected.name;
        _driverAssignmentChanged = true;
        _secondaryVehiclePatch = selectedHasVehicle
            ? VehicleSyncPatch(
                backendId: selectedVehicleId,
                driverName: '',
                backendStatus: BackendVehicleStatus.available,
                isOccupied: false,
                usedSeats: 0,
              )
            : null;
      });

      await _loadCompanyDrivers();
      _showTopToast(context, message: 'Driver assigned successfully.');
      if (mounted) {
        Navigator.of(context).pop(_resultSync);
      }
      return;
    }

    if (!selectedHasVehicle || !currentHasDriver) {
      await assignSelectedToCurrentVehicle();
      return;
    }

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Driver already assigned'),
          content: Text(
            '${selected.name} is on ${selected.assignedVehiclePlate}. Choose how to proceed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('remove'),
              child: const Text('Remove & Assign'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop('swap'),
              child: const Text('Swap'),
            ),
          ],
        );
      },
    );

    if (action == null || action == 'cancel') {
      return;
    }

    if (action == 'swap') {
      try {
        await _vehicleApiClient.swapDriverAssignment(
          vehicleId: widget.vehicle.backendId,
          newDriverId: selected.id,
          accessToken: token,
        );
      } catch (e) {
        if (mounted) {
          _showTopToast(
            context,
            message: 'Failed to swap driver: $e',
            isSuccess: false,
          );
        }
        return;
      }

      setState(() {
        if (currentIndex != -1) {
          _driverDirectory[currentIndex] = _driverDirectory[currentIndex]
              .copyWith(clearAssignedVehiclePlate: true, hasActiveTrips: false);
        }

        _driverDirectory[selectedIndex] = _driverDirectory[selectedIndex]
            .copyWith(
              assignedVehicleId: widget.vehicle.backendId,
              assignedVehiclePlate: widget.vehicle.plate,
              assignedVehicleStatus: widget.vehicle.backendStatus,
              hasActiveTrips: _currentTrip != null || _queuedTrips.isNotEmpty,
            );
        _assignedDriverName = selected.name;
        _driverAssignmentChanged = true;
            _secondaryVehiclePatch = selectedHasVehicle
                ? VehicleSyncPatch(
                    backendId: selectedVehicleId,
                    driverName: '',
                    backendStatus: BackendVehicleStatus.available,
                    isOccupied: false,
                    usedSeats: 0,
                  )
                : null;
      });

      await _loadCompanyDrivers();
      _showTopToast(context, message: 'Driver swapped successfully.');

      if (mounted) {
            Navigator.of(context).pop(_resultSync);
      }
      return;
    }

    try {
      if (selectedHasVehicle) {
        await _vehicleApiClient.unassignDriverFromVehicle(
          vehicleId: selectedVehicleId,
          accessToken: token,
        );
      }
      if (currentHasDriver) {
        await _vehicleApiClient.unassignDriverFromVehicle(
          vehicleId: currentVehicleId,
          accessToken: token,
        );
      }
      await _vehicleApiClient.assignDriverToVehicle(
        vehicleId: widget.vehicle.backendId,
        driverId: selected.id,
        accessToken: token,
      );
    } catch (e) {
      if (mounted) {
        _showTopToast(
          context,
          message: 'Failed to remove and assign driver: $e',
          isSuccess: false,
        );
      }
      return;
    }

    setState(() {
      if (currentIndex != -1) {
        _driverDirectory[currentIndex] = _driverDirectory[currentIndex]
            .copyWith(clearAssignedVehiclePlate: true, hasActiveTrips: false);
      }

      _driverDirectory[selectedIndex] = _driverDirectory[selectedIndex]
          .copyWith(
            assignedVehicleId: widget.vehicle.backendId,
            assignedVehiclePlate: widget.vehicle.plate,
            assignedVehicleStatus: widget.vehicle.backendStatus,
            hasActiveTrips: _currentTrip != null || _queuedTrips.isNotEmpty,
          );
      _assignedDriverName = selected.name;
      _driverAssignmentChanged = true;
          _secondaryVehiclePatch = selectedHasVehicle
              ? VehicleSyncPatch(
                  backendId: selectedVehicleId,
                  driverName: '',
                  backendStatus: BackendVehicleStatus.available,
                  isOccupied: false,
                  usedSeats: 0,
                )
              : null;
    });

    await _loadCompanyDrivers();

    _showTopToast(
      context,
      message: 'Driver removed and assigned successfully.',
    );

    if (mounted) {
      Navigator.of(context).pop(_resultSync);
    }
  }

  Future<void> _openDriverModal() async {
    debugPrint(
      '[MODAL_OPEN] Opening driver modal for vehicle: ${widget.vehicle.plate} (backendId: ${widget.vehicle.backendId})',
    );
    await _loadCompanyDrivers();
    if (!mounted) {
      return;
    }

    _driverSearchController.clear();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            final isAssigned = _assignedDriverName.isNotEmpty;
            final vehicleDrivers = _driverDirectory
                .where(
                  (driver) =>
                      driver.assignedVehiclePlate == widget.vehicle.plate,
                )
                .toList();

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.fromLTRB(
                12,
                0,
                12,
                12 +
                    MediaQuery.paddingOf(context).bottom +
                    MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: _GlassShell(
                borderRadius: 20,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAssigned ? 'Driver & Contacts' : 'Assign Driver',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (vehicleDrivers.isNotEmpty)
                        ...vehicleDrivers.map(
                          (driver) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _DriverContactTile(driver: driver),
                          ),
                        ),
                      TextField(
                        controller: _driverSearchController,
                        onChanged: (_) => modalSetState(() {}),
                        scrollPadding: EdgeInsets.only(
                          bottom: MediaQuery.viewInsetsOf(context).bottom + 72,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search driver name',
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _filteredDrivers.length,
                          itemBuilder: (context, index) {
                            final driver = _filteredDrivers[index];
                            return _DriverSuggestionTile(
                              driver: driver,
                              currentVehiclePlate: widget.vehicle.plate,
                              enabled: _isDriverAssignableToVehicle(driver),
                              onTap: () => _handleDriverTap(driver),
                            );
                          },
                        ),
                      ),
                      if (!isAssigned)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Vehicle has no driver. Only assign action is available.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final latestTrip = _latestVehicleTrip;

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(
          context,
        ).pop(_driverAssignmentChanged ? _resultSync : null);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.vehicle.plate),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              Navigator.of(
                context,
              ).pop(_driverAssignmentChanged ? _resultSync : null);
            },
          ),
        ),
        body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [Color(0xFF111A1D), Color(0xFF1A282C)]
                    : const [Color(0xFFF2F8F7), Color(0xFFD9E8E8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 90),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GlassShell(
                      borderRadius: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.vehicle.plate,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Driver: ${_assignedDriverName.isEmpty ? 'Unassigned' : _assignedDriverName}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFB7CFD1)
                                  : const Color(0xFF35545A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Seats: ${widget.vehicle.usedSeats}/${widget.vehicle.totalSeats} used',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFB7CFD1)
                                  : const Color(0xFF35545A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _GlassShell(
                      borderRadius: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Latest Trip',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          if (_isTripsLoading)
                            const Center(child: CircularProgressIndicator())
                          else if (_tripsLoadError != null)
                            Text(
                              'Failed to load current trip.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFFB7CFD1)
                                    : const Color(0xFF35545A),
                              ),
                            )
                          else if (latestTrip == null)
                            Text(
                              'No trip created yet.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFFB7CFD1)
                                    : const Color(0xFF35545A),
                              ),
                            )
                          else
                            _TripCard(
                              trip: latestTrip,
                              onAutoReturnChanged: _toggleLatestTripAutoReturn,
                              onDelete: (latestTrip.rawStatus == 'SCHEDULED' ||
                                      latestTrip.rawStatus == 'CANCELLED')
                                  ? () => _deleteTripById(
                                      tripId: latestTrip.id,
                                      rawStatus: latestTrip.rawStatus,
                                    )
                                  : null,
                              onCancel: latestTrip.rawStatus == 'IN_PROGRESS'
                                  ? () => _cancelTripById(
                                      tripId: latestTrip.id,
                                    )
                                  : null,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Column(
                        children: [
                          TabBar(
                            controller: _tripTabController,
                            tabs: const [
                              Tab(text: 'Upcoming Trips'),
                              Tab(text: 'Completed Trips'),
                            ],
                            labelColor: isDark
                                ? const Color(0xFFE2F0F1)
                                : const Color(0xFF143333),
                            unselectedLabelColor: isDark
                                ? const Color(0xFF8FA7AA)
                                : const Color(0xFF54666B),
                            indicatorColor: isDark
                                ? const Color(0xFF8ED0C6)
                                : const Color(0xFF0E5A57),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: TabBarView(
                              controller: _tripTabController,
                              children: [
                                _buildUpcomingTripsTab(context),
                                _buildCompletedTripsTab(context),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 18 + MediaQuery.paddingOf(context).bottom,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FloatingActionButton.small(
                  heroTag: 'driverFab',
                  onPressed:
                      (widget.vehicle.isOccupied && widget.vehicle.hasDriver)
                      ? null
                      : _openDriverProfileModal,
                  tooltip:
                      (widget.vehicle.isOccupied && widget.vehicle.hasDriver)
                      ? 'Cannot change driver for occupied vehicle'
                      : 'Manage driver assignment',
                  child: _assignedDriverName.isEmpty
                      ? const Icon(Icons.person_outline_rounded)
                      : Text(
                          _driverInitials(_assignedDriverName),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                if (_queuedTrips.isEmpty ||
                    (_queuedTrips.last.autoReturn == false &&
                        _queuedTrips.last.statusLabel != 'Auto-return'))
                  FloatingActionButton.small(
                    heroTag: 'scheduleTripFab',
                    onPressed: _openScheduleTripModal,
                    child: const Icon(Icons.add_rounded),
                  ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class PlannedTrip {
  const PlannedTrip({
    required this.id,
    required this.origin,
    required this.destination,
    required this.waypoints,
    required this.autoReturn,
    required this.rawStatus,
    required this.statusLabel,
    required this.departureTime,
  });

  final int id;
  final String origin;
  final String destination;
  final List<String> waypoints;
  final bool autoReturn;
  final String rawStatus;
  final String statusLabel;
  final String departureTime;
}

class RouteSuggestion {
  const RouteSuggestion({
    this.routeId,
    required this.origin,
    required this.destination,
    required this.departureTime,
    required this.baseFare,
    required this.waypoints,
    required this.waypointPrices,
    this.waypointIds = const {},
    this.cityRoute,
    this.isReversed = false,
  });

  final int? routeId;
  final String origin;
  final String destination;
  final String departureTime;
  final double baseFare;
  final List<String> waypoints;
  final Map<String, double> waypointPrices;
  final Map<String, int> waypointIds;
  final bool? cityRoute;
  final bool isReversed;
}

int? _asOptionalInt(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? double.tryParse(value)?.toInt();
  }
  return null;
}

double? _asOptionalDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

RouteSuggestion _routeSuggestionFromRouteWithLocations(RouteWithLocations r) {
  final waypointNames = <String>[];
  final waypointIds = <String, int>{};
  final waypointPrices = <String, double>{};

  for (final rawWaypoint in (r.route.waypoints ?? const <dynamic>[])) {
    if (rawWaypoint is! Map) {
      continue;
    }

    final waypoint = rawWaypoint.cast<String, dynamic>();
    final location = waypoint['location'] is Map
        ? (waypoint['location'] as Map).cast<String, dynamic>()
        : null;

    final locationId =
        _asOptionalInt(waypoint['location_id']) ?? _asOptionalInt(location?['id']);
    final name = (location?['custom_name']?.toString().trim().isNotEmpty == true)
        ? location!['custom_name'].toString().trim()
        : (location?['google_place_name']?.toString().trim().isNotEmpty == true)
            ? location!['google_place_name'].toString().trim()
            : (locationId != null ? 'Location #$locationId' : '?');

    waypointNames.add(name);
    if (locationId != null && locationId > 0) {
      waypointIds[name] = locationId;
    }

    final price = _asOptionalDouble(waypoint['price']);
    if (price != null) {
      waypointPrices[name] = price;
    }
  }

  return RouteSuggestion(
    routeId: r.route.id,
    origin: r.origin?.displayName ?? 'Loc #${r.route.originId}',
    destination: r.destination?.displayName ?? 'Loc #${r.route.destinationId}',
    departureTime: '',
    baseFare: r.route.routePrice ?? 0.0,
    waypoints: waypointNames,
    waypointPrices: waypointPrices,
    waypointIds: waypointIds,
    cityRoute: r.route.cityRoute,
  );
}

class TripTemplatesPage extends StatefulWidget {
  const TripTemplatesPage({super.key});

  @override
  State<TripTemplatesPage> createState() => _TripTemplatesPageState();
}

class _TripTemplatesPageState extends State<TripTemplatesPage> {
  List<RouteSuggestion> _cachedSearchedRoutes = [];
  final TextEditingController _routeSearchController = TextEditingController();
  RouteSuggestion? _selectedRoute;
  double _selectedRouteFare = 0;
  final List<String> _selectedWaypoints = [];
  final Map<String, double> _selectedWaypointPrices = {};

  List<RouteSuggestion> _mapSearchResultsToSuggestions(
    List<RouteWithLocations> results,
  ) {
    return results.map(_routeSuggestionFromRouteWithLocations).toList();
  }

  Future<void> _searchRoutesForTemplate(
    String query,
    void Function(void Function()) modalSetState,
  ) async {
    final normalizedQuery = query.trim();
    final sourceQuery = _routeSearchNeedsFullSource(normalizedQuery)
        ? ''
        : normalizedQuery;
    final results = await SyncRepository.instance.searchRoutes(
      sourceQuery,
      limit: 5000,
    );
    if (!mounted || _routeSearchController.text.trim() != normalizedQuery) {
      return;
    }
    setState(() {
      _cachedSearchedRoutes = _mapSearchResultsToSuggestions(results);
    });
    modalSetState(() {});
  }

  @override
  void dispose() {
    _routeSearchController.dispose();
    super.dispose();
  }

  void _selectRoute(RouteSuggestion route) {
    setState(() {
      _selectedRoute = route;
      _selectedRouteFare = route.baseFare;
      _selectedWaypoints
        ..clear()
        ..addAll(route.waypoints);
      _selectedWaypointPrices
        ..clear()
        ..addAll(route.waypointPrices);
    });
  }

  Future<double?> _openPriceEditorDialog({
    required String title,
    double? initialPrice,
  }) async {
    return showDialog<double>(
      context: context,
      builder: (_) =>
          _PriceEditorDialog(title: title, initialPrice: initialPrice),
    );
  }

  void _clearDraftRoute() {
    setState(() {
      _selectedRoute = null;
      _selectedRouteFare = 0;
      _selectedWaypoints.clear();
      _selectedWaypointPrices.clear();
      _routeSearchController.clear();
    });
  }

  Future<void> _saveAsTemplate() async {
    final route = _selectedRoute;
    if (route == null) {
      return;
    }

    final orderedWaypoints = List<String>.from(_selectedWaypoints);
    final prices = <String, double>{
      for (final waypoint in orderedWaypoints)
        waypoint: _selectedWaypointPrices[waypoint] ?? 0,
    };

    await TripTemplateStore.add(
      TripTemplate(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        origin: route.origin,
        destination: route.destination,
        baseFare: _selectedRouteFare,
        waypoints: orderedWaypoints,
        waypointPrices: prices,
        waypointIds: route.waypointIds,
        savedAt: DateTime.now(),
      ),
    );

    _clearDraftRoute();
    if (mounted) {
      _showTopToast(
        context,
        message: 'Template saved. You can reuse it while scheduling trips.',
      );
    }
  }

  void _openEditTemplateSheet(TripTemplate editing) {
    // Pre-fill the draft state with the template being edited
    _selectedRoute = editing.toRouteSuggestion();
    _selectedRouteFare = editing.baseFare;
    _selectedWaypoints
      ..clear()
      ..addAll(editing.waypoints);
    _selectedWaypointPrices
      ..clear()
      ..addAll(editing.waypointPrices);
    bool isReversed = editing.isReversed;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.fromLTRB(
                12,
                0,
                12,
                12 +
                    MediaQuery.paddingOf(context).bottom +
                    MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: _GlassShell(
                borderRadius: 20,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit Template',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _SelectedRouteCard(
                        route: _selectedRoute!,
                        routeFare: _selectedRouteFare,
                        waypoints: _selectedWaypoints,
                        waypointPrices: _selectedWaypointPrices,
                        onEditRouteFare: () async {
                          final price = await _openPriceEditorDialog(
                            title: 'Edit route fare',
                            initialPrice: _selectedRouteFare,
                          );
                          if (price != null) {
                            modalSetState(() => _selectedRouteFare = price);
                          }
                        },
                        onClear: () => modalSetState(() {
                          _selectedRoute = null;
                          _selectedWaypoints.clear();
                          _selectedWaypointPrices.clear();
                        }),
                        onMoveWaypoint: (from, to) => modalSetState(() {
                          final wp = _selectedWaypoints.removeAt(from);
                          _selectedWaypoints.insert(to, wp);
                        }),
                        onRemoveWaypoint: (wp) => modalSetState(() {
                          _selectedWaypoints.remove(wp);
                          _selectedWaypointPrices.remove(wp);
                        }),
                        onEditWaypointPrice: (wp) async {
                          final price = await _openPriceEditorDialog(
                            title: 'Edit price for $wp',
                            initialPrice: _selectedWaypointPrices[wp],
                          );
                          if (price != null) {
                            modalSetState(
                              () => _selectedWaypointPrices[wp] = price,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile.adaptive(
                        value: isReversed,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Reverse Route'),
                        subtitle: const Text(
                          'Save as a reversed trip template',
                        ),
                        onChanged: (value) =>
                            modalSetState(() => isReversed = value),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.save_outlined, size: 16),
                          label: const Text('Save Changes'),
                          onPressed: () async {
                            final updated = TripTemplate(
                              id: editing.id,
                              routeId: editing.routeId,
                              origin: editing.origin,
                              destination: editing.destination,
                              baseFare: _selectedRouteFare,
                              waypoints: List<String>.from(_selectedWaypoints),
                              waypointPrices: Map<String, double>.from(
                                _selectedWaypointPrices,
                              ),
                              waypointIds: editing.waypointIds,
                              savedAt: editing.savedAt,
                              isReversed: isReversed,
                            );
                            await TripTemplateStore.update(updated);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Template updated.'),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(_clearDraftRoute);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Templates')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF111A1D), Color(0xFF1A282C)]
                : const [Color(0xFFF2F8F7), Color(0xFFD9E8E8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: ValueListenableBuilder<List<TripTemplate>>(
              valueListenable: TripTemplateStore.templates,
              builder: (context, templates, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GlassShell(
                      borderRadius: 16,
                      child: Text(
                        templates.isEmpty
                            ? 'No templates yet. Use + to create your first reusable template.'
                            : 'Saved templates: ${templates.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFFBBD0D3)
                              : const Color(0xFF35545A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: templates.isEmpty
                          ? const Center(child: Text('No templates to display'))
                          : ListView.separated(
                              itemCount: templates.length,
                              separatorBuilder: (_, separatorIndex) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final template = templates[index];
                                return _TemplateCard(
                                  template: template,
                                  onDelete: () =>
                                      TripTemplateStore.delete(template.id),
                                  onEdit: () =>
                                      _openEditTemplateSheet(template),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          _routeSearchController.clear();
          _clearDraftRoute();

          final initialResults = await SyncRepository.instance.searchRoutes(
            '',
            limit: 5000,
          );
          if (mounted) {
            setState(() {
              _cachedSearchedRoutes =
                  _mapSearchResultsToSuggestions(initialResults);
            });
          }

          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) {
              return StatefulBuilder(
                builder: (context, modalSetState) {
                  final ranked = _rankRouteSuggestions(
                    _cachedSearchedRoutes,
                    _routeSearchController.text,
                  );
                  final modalSuggestions = _selectedRoute == null
                      ? ranked.map((e) => e.route).toList()
                      : const <RouteSuggestion>[];

                  return AnimatedPadding(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.fromLTRB(
                      12,
                      0,
                      12,
                      12 +
                          MediaQuery.paddingOf(context).bottom +
                          MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: _GlassShell(
                      borderRadius: 20,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Template',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 10),
                            if (_selectedRoute == null) ...[
                              _TripInputField(
                                controller: _routeSearchController,
                                label: 'Search route (supports ! , @c @p)',
                                hint: 'e.g. musanze, rubavu or !musanze or @c kigali',
                                onChanged: (value) async {
                                  await _searchRoutesForTemplate(
                                    value,
                                    modalSetState,
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 220,
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: modalSuggestions.length,
                                  itemBuilder: (context, index) {
                                    final route = modalSuggestions[index];
                                    return _RouteSuggestionTile(
                                      route: route,
                                      onTap: () {
                                        _selectRoute(route);
                                        modalSetState(() {});
                                      },
                                    );
                                  },
                                ),
                              ),
                            ] else ...[
                              _SelectedRouteCard(
                                route: _selectedRoute!,
                                routeFare: _selectedRouteFare,
                                waypoints: _selectedWaypoints,
                                waypointPrices: _selectedWaypointPrices,
                                onEditRouteFare: () async {
                                  final price = await _openPriceEditorDialog(
                                    title: 'Edit route fare',
                                    initialPrice: _selectedRouteFare,
                                  );
                                  if (price == null) {
                                    return;
                                  }
                                  setState(() => _selectedRouteFare = price);
                                  modalSetState(() {});
                                },
                                onEditWaypointPrice: (waypoint) async {
                                  final price = await _openPriceEditorDialog(
                                    title: 'Edit price for $waypoint',
                                    initialPrice:
                                        _selectedWaypointPrices[waypoint],
                                  );
                                  if (price == null) {
                                    return;
                                  }
                                  setState(
                                    () => _selectedWaypointPrices[waypoint] =
                                        price,
                                  );
                                  modalSetState(() {});
                                },
                                onMoveWaypoint: (fromIndex, toIndex) {
                                  if (fromIndex < 0 ||
                                      fromIndex >= _selectedWaypoints.length) {
                                    return;
                                  }
                                  if (toIndex < 0 ||
                                      toIndex >= _selectedWaypoints.length) {
                                    return;
                                  }
                                  setState(() {
                                    final waypoint = _selectedWaypoints
                                        .removeAt(fromIndex);
                                    _selectedWaypoints.insert(
                                      toIndex,
                                      waypoint,
                                    );
                                  });
                                  modalSetState(() {});
                                },
                                onRemoveWaypoint: (waypoint) {
                                  setState(() {
                                    _selectedWaypoints.remove(waypoint);
                                  });
                                  modalSetState(() {});
                                },
                                onClear: () {
                                  _clearDraftRoute();
                                  modalSetState(() {});
                                },
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () async {
                                    await _saveAsTemplate();
                                    if (!context.mounted) {
                                      return;
                                    }
                                    Navigator.of(context).pop();
                                  },
                                  icon: const Icon(Icons.save_outlined),
                                  label: const Text('Save Template'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Template'),
      ),
    );
  }
}

class TripConfirmationResult {
  const TripConfirmationResult({
    required this.departureDateTime,
    required this.autoReturn,
    this.isReversed = false,
  });

  final DateTime departureDateTime;
  final bool autoReturn;
  final bool isReversed;
}

class CompletedTrip {
  const CompletedTrip({
    required this.id,
    required this.origin,
    required this.destination,
    required this.rawStatus,
    required this.completedAt,
  });

  final int id;
  final String origin;
  final String destination;
  final String rawStatus;
  final String completedAt;
}

class DriverProfile {
  const DriverProfile({
    required this.name,
    required this.phone,
    required this.assignedVehicleId,
    required this.assignedVehiclePlate,
    required this.hasActiveTrips,
    this.id = -1,
    this.assignedVehicleStatus,
  });

  final int id;
  final String name;
  final String phone;
  final int? assignedVehicleId;
  final String? assignedVehiclePlate;
  final bool hasActiveTrips;
  final BackendVehicleStatus? assignedVehicleStatus;

  DriverProfile copyWith({
    int? id,
    String? name,
    String? phone,
    int? assignedVehicleId,
    String? assignedVehiclePlate,
    bool clearAssignedVehiclePlate = false,
    bool? hasActiveTrips,
    BackendVehicleStatus? assignedVehicleStatus,
  }) {
    return DriverProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
        assignedVehicleId: assignedVehicleId ?? this.assignedVehicleId,
      assignedVehiclePlate: clearAssignedVehiclePlate
          ? null
          : (assignedVehiclePlate ?? this.assignedVehiclePlate),
      hasActiveTrips: hasActiveTrips ?? this.hasActiveTrips,
      assignedVehicleStatus: assignedVehicleStatus ?? this.assignedVehicleStatus,
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.onDelete,
    required this.onEdit,
  });

  final TripTemplate template;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dismissible(
      key: ValueKey(template.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFB00020),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
      ),
      confirmDismiss: (_) async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete template?'),
            content: Text(
              'Remove "${template.origin} → ${template.destination}"? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Color(0xFFB00020)),
                ),
              ),
            ],
          ),
        );
        return confirm ?? false;
      },
      onDismissed: (_) => onDelete(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0x292A3F42) : const Color(0x66FFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF38555A) : const Color(0xFFC9DADA),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${template.origin} → ${template.destination}${template.isReversed ? " (Reversed)" : ""}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFFE2F0F1)
                          : const Color(0xFF143333),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fare: ${_formatMoney(template.baseFare)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFFBBD0D3)
                          : const Color(0xFF35545A),
                    ),
                  ),
                  if (template.waypoints.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Via: ${template.waypoints.join(' → ')}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFFBCD2D5)
                            : const Color(0xFF35545A),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit template',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.edit_outlined,
                size: 18,
                color: isDark
                    ? const Color(0xFF8ED0C6)
                    : const Color(0xFF0E5A57),
              ),
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverContactTile extends StatelessWidget {
  const _DriverContactTile({required this.driver});

  final DriverProfile driver;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x292A3F42) : const Color(0x66FFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF3A565B) : const Color(0xFFC7D8DA),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_in_talk_outlined, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${driver.name}  •  ${driver.phone}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? const Color(0xFFE2F0F1)
                    : const Color(0xFF143333),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverSuggestionTile extends StatelessWidget {
  const _DriverSuggestionTile({
    required this.driver,
    required this.currentVehiclePlate,
    required this.enabled,
    required this.onTap,
  });

  final DriverProfile driver;
  final String currentVehiclePlate;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOnCurrentVehicle =
        driver.assignedVehiclePlate == currentVehiclePlate;
    final assignedStatus = driver.assignedVehicleStatus;
    final isAssignedToAnotherVehicle =
      driver.assignedVehiclePlate != null && !isOnCurrentVehicle;
    final isAvailableForSwap =
      isAssignedToAnotherVehicle &&
      assignedStatus == BackendVehicleStatus.available;
    final isBusy =
      isAssignedToAnotherVehicle &&
      assignedStatus == BackendVehicleStatus.occupied;
    final isDisabled = !enabled;

    final icon = isBusy
      ? Icons.sync_problem_rounded
      : (isAvailableForSwap
          ? Icons.verified_rounded
          : Icons.person_outline_rounded);
    final color = isBusy
      ? const Color(0xFFE26D5A)
      : (isAvailableForSwap
          ? const Color(0xFF2E9F8D)
          : const Color(0xFF5D7178));
    final statusText = isOnCurrentVehicle
        ? 'Current vehicle'
        : (isBusy
          ? 'Busy on ${driver.assignedVehiclePlate}'
          : (isAvailableForSwap
            ? 'Available on ${driver.assignedVehiclePlate}'
            : (driver.assignedVehiclePlate != null
              ? 'Unavailable on ${driver.assignedVehiclePlate}'
              : 'Unassigned')));

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: isDisabled ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isDisabled ? color.withValues(alpha: 0.45) : color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    driver.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDisabled
                          ? (isDark
                                ? const Color(0xFF819395)
                                : const Color(0xFF8A9A9E))
                          : (isDark
                                ? const Color(0xFFE2F0F1)
                                : const Color(0xFF143333)),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$statusText  •  ${driver.phone}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDisabled
                          ? (isDark
                                ? const Color(0xFF718487)
                                : const Color(0xFF9AA7AA))
                          : (isDark
                                ? const Color(0xFFBBD0D3)
                                : const Color(0xFF35545A)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripInputField extends StatelessWidget {
  const _TripInputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      scrollPadding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + 72,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: isDark ? const Color(0xFF1F2F33) : const Color(0xF6FFFFFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF3B575C) : const Color(0xFFBFD0D5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF3B575C) : const Color(0xFFBFD0D5),
          ),
        ),
      ),
    );
  }
}

class _PriceEditorDialog extends StatefulWidget {
  const _PriceEditorDialog({required this.title, this.initialPrice});

  final String title;
  final double? initialPrice;

  @override
  State<_PriceEditorDialog> createState() => _PriceEditorDialogState();
}

class _PriceEditorDialogState extends State<_PriceEditorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialPrice == null
          ? ''
          : widget.initialPrice!.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final parsed = double.tryParse(_controller.text.trim());
    if (parsed == null) {
      return;
    }
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Price in RWF',
          prefixText: 'RWF ',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _RouteSuggestionTile extends StatelessWidget {
  const _RouteSuggestionTile({required this.route, required this.onTap});

  final RouteSuggestion route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0x292A3F42) : const Color(0x66FFFFFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF38555A) : const Color(0xFFC9DADA),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${route.origin} -> ${route.destination}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFFE2F0F1)
                            : const Color(0xFF143333),
                      ),
                    ),
                  ),
                  Text(
                    _formatMoney(route.baseFare),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? const Color(0xFF8ED0C6)
                          : const Color(0xFF0E5A57),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Route fare',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFF9AB5B9)
                      : const Color(0xFF54666B),
                ),
              ),
              if (route.waypoints.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Saved waypoints: ${route.waypoints.join(', ')}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFBCD2D5)
                        : const Color(0xFF35545A),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: route.waypoints.map((waypoint) {
                    final price = route.waypointPrices[waypoint] ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0x2A2CBDA8)
                            : const Color(0x332CBDA8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$waypoint ${_formatMoney(price)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFFBDE7DF)
                              : const Color(0xFF0E5A57),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    this.indexLabel,
    this.onAutoReturnChanged,
    this.onDelete,
    this.onCancel,
  });

  final PlannedTrip trip;
  final String? indexLabel;
  final ValueChanged<bool>? onAutoReturnChanged;
  final VoidCallback? onDelete;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x292A3F42) : const Color(0x66FFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF38555A) : const Color(0xFFC9DADA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (indexLabel != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    indexLabel!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? const Color(0xFF95CFC6)
                          : const Color(0xFF0E5A57),
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  '${trip.origin} -> ${trip.destination}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFFE2F0F1)
                        : const Color(0xFF143333),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x1F2CBDA8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  trip.statusLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF169E89),
                  ),
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Delete trip',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Color(0xFFE26D5A),
                  ),
                ),
              ],
              if (onCancel != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Cancel trip',
                  visualDensity: VisualDensity.compact,
                  onPressed: onCancel,
                  icon: const Icon(
                    Icons.cancel_outlined,
                    size: 18,
                    color: Color(0xFFE3A13B),
                  ),
                ),
              ],
            ],
          ),
          if (onAutoReturnChanged != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Auto-return',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFFBCD2D5)
                        : const Color(0xFF35545A),
                  ),
                ),
                const SizedBox(width: 8),
                Transform.scale(
                  scale: 0.82,
                  child: Switch.adaptive(
                    value: trip.autoReturn,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: onAutoReturnChanged,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Departure: ${trip.departureTime}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFBCD2D5) : const Color(0xFF35545A),
            ),
          ),
          if (trip.waypoints.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Waypoints: ${trip.waypoints.join(' -> ')}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFFBCD2D5)
                    : const Color(0xFF35545A),
              ),
            ),
          ],
          if (trip.autoReturn) ...[
            const SizedBox(height: 4),
            const Text(
              'Auto-return enabled',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2CBDA8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectedRouteCard extends StatelessWidget {
  const _SelectedRouteCard({
    required this.route,
    required this.routeFare,
    required this.waypoints,
    required this.waypointPrices,
    required this.onEditRouteFare,
    required this.onEditWaypointPrice,
    required this.onMoveWaypoint,
    required this.onRemoveWaypoint,
    required this.onClear,
  });

  final RouteSuggestion? route;
  final double routeFare;
  final List<String> waypoints;
  final Map<String, double> waypointPrices;
  final VoidCallback onEditRouteFare;
  final ValueChanged<String> onEditWaypointPrice;
  final void Function(int fromIndex, int toIndex) onMoveWaypoint;
  final ValueChanged<String> onRemoveWaypoint;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (route == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x292A3F42) : const Color(0x66FFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF38555A) : const Color(0xFFC9DADA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${route!.origin} -> ${route!.destination}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFFE2F0F1)
                        : const Color(0xFF143333),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text('Clear route'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Route fare: ${_formatMoney(routeFare)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFBCD2D5)
                        : const Color(0xFF35545A),
                  ),
                ),
              ),
              TextButton(onPressed: onEditRouteFare, child: const Text('Edit')),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Route plan',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFBCD2D5) : const Color(0xFF35545A),
            ),
          ),
          const SizedBox(height: 6),
          _RoutePlanStopRow(
            title: route!.origin,
            subtitle: 'Origin',
            isDark: isDark,
            canMoveUp: false,
            canMoveDown: false,
            onMoveUp: null,
            onMoveDown: null,
            onEditPrice: null,
            onRemove: null,
          ),
          if (waypoints.isNotEmpty)
            ...waypoints.asMap().entries.map((entry) {
              final index = entry.key;
              final waypoint = entry.value;
              final price = waypointPrices[waypoint] ?? 0;
              return _RoutePlanStopRow(
                title: waypoint,
                subtitle: 'Waypoint ${index + 1}',
                priceLabel: _formatMoney(price),
                isDark: isDark,
                canMoveUp: index > 0,
                canMoveDown: index < waypoints.length - 1,
                onMoveUp: index > 0
                    ? () => onMoveWaypoint(index, index - 1)
                    : null,
                onMoveDown: index < waypoints.length - 1
                    ? () => onMoveWaypoint(index, index + 1)
                    : null,
                onEditPrice: () => onEditWaypointPrice(waypoint),
                onRemove: () => onRemoveWaypoint(waypoint),
              );
            }),
          _RoutePlanStopRow(
            title: route!.destination,
            subtitle: 'Destination',
            isDark: isDark,
            canMoveUp: false,
            canMoveDown: false,
            onMoveUp: null,
            onMoveDown: null,
            onEditPrice: null,
            onRemove: null,
          ),
        ],
      ),
    );
  }
}

class _RoutePlanStopRow extends StatelessWidget {
  const _RoutePlanStopRow({
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onEditPrice,
    required this.onRemove,
    this.priceLabel,
  });

  final String title;
  final String subtitle;
  final bool isDark;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onEditPrice;
  final VoidCallback? onRemove;
  final String? priceLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x1F2A3F42) : const Color(0x55FFFFFF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFFE2F0F1)
                        : const Color(0xFF143333),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFBCD2D5)
                        : const Color(0xFF35545A),
                  ),
                ),
                if (priceLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    priceLabel!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFF8ED0C6)
                          : const Color(0xFF0E5A57),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onEditPrice != null)
            TextButton(onPressed: onEditPrice, child: const Text('Edit')),
          if (onRemove != null)
            IconButton(
              tooltip: 'Remove waypoint',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          if (canMoveUp || canMoveDown) ...[
            IconButton(
              tooltip: 'Move up',
              onPressed: canMoveUp ? onMoveUp : null,
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
            ),
            IconButton(
              tooltip: 'Move down',
              onPressed: canMoveDown ? onMoveDown : null,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

class _WaypointSuggestionTile extends StatelessWidget {
  const _WaypointSuggestionTile({required this.location, required this.onTap});

  final String location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0x292A3F42) : const Color(0x66FFFFFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF38555A) : const Color(0xFFC9DADA),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 16,
                color: Color(0xFF2E9F8D),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  location,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFFE2F0F1)
                        : const Color(0xFF143333),
                  ),
                ),
              ),
              const Icon(
                Icons.add_circle_outline_rounded,
                size: 16,
                color: Color(0xFF2E9F8D),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletedTripCard extends StatelessWidget {
  const _CompletedTripCard({required this.trip});

  final CompletedTrip trip;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x292A3F42) : const Color(0x66FFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF38555A) : const Color(0xFFC9DADA),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF2E9F8D),
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${trip.origin} -> ${trip.destination}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? const Color(0xFFE2F0F1)
                    : const Color(0xFF143333),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            trip.completedAt,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFBCD2D5) : const Color(0xFF35545A),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? const Color(0xFF9FBABD)
                    : const Color(0xFF35545A),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFFE3F1F2)
                    : const Color(0xFF143333),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassShell extends StatelessWidget {
  const _GlassShell({
    required this.child,
    required this.borderRadius,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x44000000) : const Color(0x24084D4B),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xCC1A2A2E) : const Color(0xAAFFFFFF),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: isDark
                    ? const Color(0x66719399)
                    : const Color(0x66FFFFFF),
                width: 1.2,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _DockShell extends StatelessWidget {
  const _DockShell({
    required this.child,
    required this.borderRadius,
    this.padding = const EdgeInsets.all(10),
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2A2D) : const Color(0xFFF6FBFA),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark ? const Color(0xFF405C61) : const Color(0xFFD2E1E0),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x5A000000) : const Color(0x2B0C3F3D),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class Vehicle {
  const Vehicle({
    required this.backendId,
    required this.name,
    required this.backendStatus,
    required this.plate,
    required this.driverName,
    required this.type,
    required this.routeName,
    required this.origin,
    required this.destination,
    required this.departureTime,
    required this.totalSeats,
    required this.usedSeats,
    required this.isOccupied,
    required this.hasDeparted,
    this.remainingDistanceKm,
  });

  factory Vehicle.fromSummary(VehicleSummaryDto dto) {
    final displayName = '${dto.make} ${dto.model}'.trim();
    final capacity = dto.capacity < 0 ? 0 : dto.capacity;
    final usedSeats = dto.status == BackendVehicleStatus.occupied
        ? capacity
        : 0;

    return Vehicle(
      backendId: dto.id,
      name: displayName.isEmpty ? dto.licensePlate : displayName,
      backendStatus: dto.status,
      plate: dto.licensePlate,
      driverName: dto.driver?.fullName ?? '',
      type: dto.vehicleType,
      routeName: '',
      origin: '',
      destination: '',
      departureTime: '',
      totalSeats: capacity,
      usedSeats: usedSeats,
      isOccupied: dto.status == BackendVehicleStatus.occupied,
      hasDeparted: false,
      remainingDistanceKm: null,
    );
  }

  final int backendId;
  final String name;
  final BackendVehicleStatus backendStatus;
  final String plate;
  final String driverName;
  final String type;
  final String routeName;
  final String origin;
  final String destination;
  final String departureTime;
  final int totalSeats;
  final int usedSeats;
  final bool isOccupied;
  final bool hasDeparted;
  final double? remainingDistanceKm;

  Vehicle copyWith({
    int? backendId,
    String? name,
    BackendVehicleStatus? backendStatus,
    String? plate,
    String? driverName,
    String? type,
    String? routeName,
    String? origin,
    String? destination,
    String? departureTime,
    int? totalSeats,
    int? usedSeats,
    bool? isOccupied,
    bool? hasDeparted,
    double? remainingDistanceKm,
  }) {
    return Vehicle(
      backendId: backendId ?? this.backendId,
      name: name ?? this.name,
      backendStatus: backendStatus ?? this.backendStatus,
      plate: plate ?? this.plate,
      driverName: driverName ?? this.driverName,
      type: type ?? this.type,
      routeName: routeName ?? this.routeName,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      departureTime: departureTime ?? this.departureTime,
      totalSeats: totalSeats ?? this.totalSeats,
      usedSeats: usedSeats ?? this.usedSeats,
      isOccupied: isOccupied ?? this.isOccupied,
      hasDeparted: hasDeparted ?? this.hasDeparted,
      remainingDistanceKm: remainingDistanceKm ?? this.remainingDistanceKm,
    );
  }

  int get remainingSeats => totalSeats - usedSeats;

  bool get hasDriver => driverName.trim().isNotEmpty;

  String get driverDisplayName => hasDriver ? driverName : 'Unassigned';
}
