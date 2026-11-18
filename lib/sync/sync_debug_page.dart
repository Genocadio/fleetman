import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'sync_coordinator.dart';
import 'sync_models.dart';
import 'sync_repository.dart';

class SyncDebugPage extends StatefulWidget {
  const SyncDebugPage({super.key});

  @override
  State<SyncDebugPage> createState() => _SyncDebugPageState();
}

class _SyncDebugPageState extends State<SyncDebugPage> {
  static const int _tablePageSize = 50;

  SyncSnapshot? _snapshot;
  bool _loading = true;
  bool _syncing = false;
  bool _showSyncDetails = false;
  final List<LocationEntity> _locations = <LocationEntity>[];
  final List<RouteWithLocations> _routes = <RouteWithLocations>[];
  int _locationOffset = 0;
  int _routeOffset = 0;
  bool _loadingMoreLocations = false;
  bool _loadingMoreRoutes = false;
  bool _hasMoreLocations = true;
  bool _hasMoreRoutes = true;
  final ScrollController _locationsScrollController = ScrollController();
  final ScrollController _routesScrollController = ScrollController();
  final TextEditingController _locationSearchController =
      TextEditingController();
  final TextEditingController _routeSearchController = TextEditingController();
  final List<LocationEntity> _searchedLocations = <LocationEntity>[];
  final List<RouteWithLocations> _searchedRoutes = <RouteWithLocations>[];
  bool _searchingLocations = false;
  bool _searchingRoutes = false;
  int _searchRequestToken = 0;

  @override
  void initState() {
    super.initState();
    _locationSearchController.addListener(_onSearchChanged);
    _routeSearchController.addListener(_onSearchChanged);
    _locationsScrollController.addListener(_onLocationsTableScroll);
    _routesScrollController.addListener(_onRoutesTableScroll);
    _refreshLocalSnapshot();
  }

  @override
  void dispose() {
    _locationSearchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _routeSearchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _locationsScrollController
      ..removeListener(_onLocationsTableScroll)
      ..dispose();
    _routesScrollController
      ..removeListener(_onRoutesTableScroll)
      ..dispose();
    super.dispose();
  }

  void _onLocationsTableScroll() {
    if (_locationSearchController.text.trim().isNotEmpty) {
      return;
    }
    if (!_locationsScrollController.hasClients) {
      return;
    }
    if (_locationsScrollController.position.pixels >=
        _locationsScrollController.position.maxScrollExtent - 120) {
      _loadMoreLocations();
    }
  }

  void _onRoutesTableScroll() {
    if (_routeSearchController.text.trim().isNotEmpty) {
      return;
    }
    if (!_routesScrollController.hasClients) {
      return;
    }
    if (_routesScrollController.position.pixels >=
        _routesScrollController.position.maxScrollExtent - 120) {
      _loadMoreRoutes();
    }
  }

  void _onSearchChanged() {
    unawaited(_refreshSearchResults());
  }

  Future<void> _refreshSearchResults() async {
    final locationQuery = _locationSearchController.text.trim();
    final routeQuery = _routeSearchController.text.trim();

    final token = ++_searchRequestToken;

    if (mounted) {
      setState(() {
        _searchingLocations = locationQuery.isNotEmpty;
        _searchingRoutes = routeQuery.isNotEmpty;
      });
    }

    final locationResults = locationQuery.isEmpty
        ? const <LocationEntity>[]
        : await SyncRepository.instance.searchLocations(locationQuery, limit: 500);
    final routeResults = routeQuery.isEmpty
        ? const <RouteWithLocations>[]
        : await SyncRepository.instance.searchRoutes(routeQuery, limit: 500);

    if (!mounted || token != _searchRequestToken) {
      return;
    }

    setState(() {
      _searchedLocations
        ..clear()
        ..addAll(locationResults);
      _searchedRoutes
        ..clear()
        ..addAll(routeResults);
      _searchingLocations = false;
      _searchingRoutes = false;
    });
  }

  Future<void> _refreshLocalSnapshot() async {
    setState(() => _loading = true);
    final snapshot = await SyncRepository.instance.readSnapshot(
      locationLimit: 1,
      routeLimit: 1,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _snapshot = snapshot;
      _loading = false;
    });
    await _resetLocalPaging();
  }

  Future<void> _resetLocalPaging() async {
    setState(() {
      _locations.clear();
      _routes.clear();
      _locationOffset = 0;
      _routeOffset = 0;
      _hasMoreLocations = true;
      _hasMoreRoutes = true;
      _loadingMoreLocations = false;
      _loadingMoreRoutes = false;
      _searchedLocations.clear();
      _searchedRoutes.clear();
      _searchingLocations = false;
      _searchingRoutes = false;
    });

    await _loadMoreLocations();
    await _loadMoreRoutes();
  }

  Future<void> _loadMoreLocations() async {
    if (_loadingMoreLocations || !_hasMoreLocations) {
      return;
    }

    setState(() => _loadingMoreLocations = true);
    final page = await SyncRepository.instance.readLocationsPage(
      limit: _tablePageSize,
      offset: _locationOffset,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _locations.addAll(page);
      _locationOffset += page.length;
      _hasMoreLocations = page.length == _tablePageSize;
      _loadingMoreLocations = false;
    });
  }

  Future<void> _loadMoreRoutes() async {
    if (_loadingMoreRoutes || !_hasMoreRoutes) {
      return;
    }

    setState(() => _loadingMoreRoutes = true);
    final page = await SyncRepository.instance.readRoutesPage(
      limit: _tablePageSize,
      offset: _routeOffset,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _routes.addAll(page);
      _routeOffset += page.length;
      _hasMoreRoutes = page.length == _tablePageSize;
      _loadingMoreRoutes = false;
    });
  }

  Future<void> _runSyncNow() async {
    if (_syncing) {
      return;
    }

    setState(() => _syncing = true);
    try {
      await SyncCoordinator.instance.syncNow();
      await _refreshLocalSnapshot();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sync completed.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sync failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  Future<void> _runClearAndSync() async {
    if (_syncing) {
      return;
    }

    print('[SyncDebugPage] Clear & Sync pressed');
    setState(() => _syncing = true);
    try {
      await SyncCoordinator.instance.forceFullResync();
      await _refreshLocalSnapshot();
      if (!mounted) {
        return;
      }
      print('[SyncDebugPage] Clear & Sync completed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cleared and resynced successfully.')),
      );
    } catch (error) {
      print('[SyncDebugPage] Clear & Sync failed: $error');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Clear & Sync failed: $error')),
      );
    } finally {
      setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncProgress = SyncCoordinator.instance.progress;
    final lastSyncAt = _snapshot?.state[SyncCoordinator.lastSuccessSyncAtKey];
    final locationQuery = _locationSearchController.text.trim();
    final routeQuery = _routeSearchController.text.trim();
    final visibleLocations = locationQuery.isEmpty ? _locations : _searchedLocations;
    final visibleRoutes = routeQuery.isEmpty ? _routes : _searchedRoutes;

    return Scaffold(
      appBar: AppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _snapshot == null
          ? const Center(child: Text('No local data available'))
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: _SyncHeaderPanel(
                      expanded: _showSyncDetails,
                      lastSyncAt: lastSyncAt,
                      snapshot: _snapshot!,
                      progress: syncProgress,
                      syncing: _syncing,
                      onToggleExpanded: () {
                        setState(() {
                          _showSyncDetails = !_showSyncDetails;
                        });
                      },
                      onSyncNow: _runSyncNow,
                      onClearAndSync: _runClearAndSync,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: TabBar(
                      tabs: [
                        Tab(text: 'Locations'),
                        Tab(text: 'Routes'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TabBarView(
                        children: [
                          _LocationsTableSection(
                            locations: visibleLocations,
                            verticalController: _locationsScrollController,
                            loadingMore: locationQuery.isEmpty
                                ? _loadingMoreLocations
                                : _searchingLocations,
                            searchController: _locationSearchController,
                          ),
                          _RoutesTableSection(
                            routes: visibleRoutes,
                            verticalController: _routesScrollController,
                            loadingMore: routeQuery.isEmpty
                                ? _loadingMoreRoutes
                                : _searchingRoutes,
                            searchController: _routeSearchController,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SyncHeaderPanel extends StatelessWidget {
  const _SyncHeaderPanel({
    required this.expanded,
    required this.lastSyncAt,
    required this.snapshot,
    required this.progress,
    required this.syncing,
    required this.onToggleExpanded,
    required this.onSyncNow,
    required this.onClearAndSync,
  });

  final bool expanded;
  final String? lastSyncAt;
  final SyncSnapshot snapshot;
  final ValueListenable<SyncProgress> progress;
  final bool syncing;
  final VoidCallback onToggleExpanded;
  final VoidCallback onSyncNow;
  final VoidCallback onClearAndSync;

  String _formatLastSync(String? rawValue) {
    final parsed = DateTime.tryParse(rawValue ?? '');
    if (parsed == null) {
      return 'Last sync: never';
    }

    final local = parsed.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final meridiem = local.hour < 12 ? 'AM' : 'PM';
    return 'Last sync: ${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hour:$minute $meridiem';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 1,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onToggleExpanded,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatLastSync(lastSyncAt),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 12),
                _SyncInfoCard(snapshot: snapshot),
                const SizedBox(height: 12),
                ValueListenableBuilder<SyncProgress>(
                  valueListenable: progress,
                  builder: (context, value, _) {
                    return _SyncProgressCard(progress: value);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: syncing ? null : onClearAndSync,
                        icon: const Icon(Icons.cleaning_services_outlined),
                        label: const Text('Clear & Sync'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: syncing ? null : onSyncNow,
                        icon: syncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync_rounded),
                        label: Text(syncing ? 'Syncing...' : 'Sync now'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncProgressCard extends StatelessWidget {
  const _SyncProgressCard({required this.progress});

  final SyncProgress progress;

  String _stageLabel() {
    switch (progress.stage) {
      case SyncStage.idle:
        return 'Idle';
      case SyncStage.checkingInternet:
        return 'Checking internet';
      case SyncStage.syncingLocations:
        return 'Syncing locations';
      case SyncStage.syncingRoutes:
        return 'Syncing routes';
      case SyncStage.done:
        return 'Done';
      case SyncStage.failed:
        return 'Failed';
    }
  }

  @override
  Widget build(BuildContext context) {
    final percentageLabel = '${progress.percentage.toStringAsFixed(1)}%';
    final progressValue = (progress.percentage / 100).clamp(0.0, 1.0);

    return _ThinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _stageLabel(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(percentageLabel),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progressValue),
          const SizedBox(height: 8),
          Text(progress.message),
          if (progress.currentPage != null && progress.totalPages != null)
            Text('Page ${progress.currentPage}/${progress.totalPages}'),
          if (progress.itemsInCurrentPage != null)
            Text('Items in current page: ${progress.itemsInCurrentPage}'),
        ],
      ),
    );
  }
}

class _SyncInfoCard extends StatelessWidget {
  const _SyncInfoCard({required this.snapshot});

  final SyncSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _ThinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trips API base URL: ${snapshot.baseUrl}'),
          const SizedBox(height: 6),
          Text('Active hash: ${snapshot.activeHash ?? '(none yet)'}'),
          const SizedBox(height: 10),
          const Text(
            'Sync state values',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (snapshot.state.isEmpty) const Text('No sync state stored yet.'),
          for (final entry in snapshot.state.entries)
            Text('${entry.key}: ${entry.value}'),
        ],
      ),
    );
  }
}

class _LocationsTableSection extends StatelessWidget {
  const _LocationsTableSection({
    required this.locations,
    required this.verticalController,
    required this.loadingMore,
    required this.searchController,
  });

  final List<LocationEntity> locations;
  final ScrollController verticalController;
  final bool loadingMore;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              labelText: 'Search locations',
              hintText: 'By name, code, province, district',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Tap a row to view full location data',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: locations.isEmpty
                ? Center(
                    child: Text(
                      query.isEmpty
                          ? 'No locations loaded yet.'
                          : 'No locations match this search.',
                    ),
                  )
                : _DataGridShell(
                    verticalController: verticalController,
                    child: DataTable(
                      showCheckboxColumn: false,
                      columns: const [
                        DataColumn(label: Text('Custom Name')),
                        DataColumn(label: Text('District')),
                      ],
                      rows: locations
                          .map(
                            (location) => DataRow(
                              onSelectChanged: (_) =>
                                  _showLocationDetailsDialog(context, location),
                              cells: [
                                DataCell(Text(location.customName ?? '-')),
                                DataCell(Text(location.district ?? '-')),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
          ),
          if (loadingMore)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoutesTableSection extends StatelessWidget {
  const _RoutesTableSection({
    required this.routes,
    required this.verticalController,
    required this.loadingMore,
    required this.searchController,
  });

  final List<RouteWithLocations> routes;
  final ScrollController verticalController;
  final bool loadingMore;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              labelText: 'Search routes',
              hintText: 'By route id, name, origin, destination',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Tap a row to view full route data',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: routes.isEmpty
                ? Center(
                    child: Text(
                      query.isEmpty
                          ? 'No routes loaded yet.'
                          : 'No routes match this search.',
                    ),
                  )
                : _DataGridShell(
                    verticalController: verticalController,
                    child: DataTable(
                      showCheckboxColumn: false,
                      columns: const [
                        DataColumn(label: Text('Origin')),
                        DataColumn(label: Text('Destination')),
                      ],
                      rows: routes
                          .map(
                            (entry) => DataRow(
                              onSelectChanged: (_) =>
                                  _showRouteDetailsDialog(context, entry),
                              cells: [
                                DataCell(
                                  Text(
                                    entry.origin?.displayName ??
                                        'Location #${entry.route.originId}',
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    entry.destination?.displayName ??
                                        'Location #${entry.route.destinationId}',
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
          ),
          if (loadingMore)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}

class _DataGridShell extends StatelessWidget {
  const _DataGridShell({required this.child, required this.verticalController});

  final Widget child;
  final ScrollController verticalController;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Card(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: SingleChildScrollView(
                controller: verticalController,
                scrollDirection: Axis.vertical,
                child: Padding(padding: const EdgeInsets.all(8), child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThinCard extends StatelessWidget {
  const _ThinCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

Future<void> _showLocationDetailsDialog(
  BuildContext context,
  LocationEntity location,
) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Location Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailLine(label: 'Name', value: location.displayName),
              _DetailLine(label: 'Province', value: location.province),
              _DetailLine(label: 'District', value: location.district),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

Future<void> _showRouteDetailsDialog(
  BuildContext context,
  RouteWithLocations entry,
) {
  final route = entry.route;
  final widgets = <Widget>[];

  widgets.add(
    _DetailLine(
      label: 'Origin',
      value: entry.origin?.displayName ?? 'Location #${route.originId}',
    ),
  );

  if (route.waypoints != null && route.waypoints!.isNotEmpty) {
    for (final w in route.waypoints!) {
      if (w is Map<String, dynamic>) {
        final loc = w['location'] as Map<String, dynamic>?;
        final name = loc != null ? (loc['custom_name'] ?? loc['google_place_name'] ?? loc['id']?.toString() ?? '?') : '?';
        final price = w['price']?.toString() ?? '-';
        widgets.add(
          _DetailLine(
            label: 'Waypoint',
            value: '$name - $price',
          ),
        );
      }
    }
  }

  final routePrice = route.routePrice?.toStringAsFixed(2) ?? '-';
  widgets.add(
    _DetailLine(
      label: 'Destination',
      value: '${entry.destination?.displayName ?? 'Location #${route.destinationId}'} - $routePrice',
    ),
  );

  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Route Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: widgets,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('$label: ${value == null || value!.isEmpty ? '-' : value}'),
    );
  }
}
