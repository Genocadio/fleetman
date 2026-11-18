import sys
import re

def main():
    with open('lib/main.dart', 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Replacements for State array initialization
    content = content.replace(
        '  late final List<RouteSuggestion> _savedRoutes;\n  late final List<String> _locationDirectory;\n',
        '  List<RouteSuggestion> _cachedSearchedRoutes = [];\n  List<String> _cachedLocations = [];\n'
    )
    content = content.replace(
        '    _savedRoutes = _buildSavedRoutes();\n    _locationDirectory = _buildLocationDirectory();\n',
        ''
    )

    # 2. Strip dummy builders
    content = re.sub(r'  List<RouteSuggestion> _buildSavedRoutes\(\) \{.*?\n  \}\n\n', '', content, flags=re.DOTALL)
    content = re.sub(r'  List<String> _buildLocationDirectory\(\) \{.*?\n  \}\n\n', '', content, flags=re.DOTALL)

    # 3. Update query logic inside _openScheduleTripModal
    old_query = """            final sourceRoutes = _searchTemplatesInScheduler
                ? TripTemplateStore.templates.value
                      .map((template) => template.toRouteSuggestion())
                      .toList()
                : _savedRoutes;
            final routeSuggestions = _selectedRoute == null
                ? sourceRoutes.where((route) {
                    return route.origin.toLowerCase().contains(routeQuery) ||
                        route.destination.toLowerCase().contains(routeQuery);
                  }).toList()
                : const <RouteSuggestion>[];"""
    
    new_query = """            final routeSuggestions = _selectedRoute == null
                ? (_searchTemplatesInScheduler
                    ? TripTemplateStore.templates.value
                        .map((template) => template.toRouteSuggestion())
                        .where((route) =>
                            route.origin.toLowerCase().contains(routeQuery) ||
                            route.destination.toLowerCase().contains(routeQuery))
                        .toList()
                    : _cachedSearchedRoutes)
                : const <RouteSuggestion>[];"""
    content = content.replace(old_query, new_query)

    # 4. Hook autocomplete to async search in Modal input field
    old_route_onchanged = """                          onChanged: (_) => modalSetState(() {}),"""
    
    new_route_onchanged_modal = """                          onChanged: (text) async {
                            final query = text.trim();
                            if (!_searchTemplatesInScheduler) {
                               final results = await SyncRepository.instance.searchRoutes(query);
                               if (mounted && _routeSearchController.text.trim() == query) {
                                  _cachedSearchedRoutes = results.map((r) => RouteSuggestion(
                                      routeId: r.route.id,
                                      origin: r.origin?.displayName ?? 'Loc #${r.route.originId}',
                                      destination: r.destination?.displayName ?? 'Loc #${r.route.destinationId}',
                                      departureTime: '',
                                      baseFare: r.route.routePrice ?? 0.0,
                                      waypoints: r.route.waypoints?.map((w) {
                                        if (w is Map<String, dynamic>) {
                                          final loc = w['location'] as Map<String, dynamic>?;
                                          return loc?['custom_name'] ?? loc?['google_place_name'] ?? loc?['id']?.toString() ?? '?';
                                        }
                                        return '?';
                                      }).toList() ?? [],
                                      waypointPrices: {},
                                      waypointIds: {},
                                  )).toList();
                                  modalSetState(() {});
                               }
                            } else {
                               modalSetState(() {});
                            }
                          },"""
    # Note: we need to replace only the first occurrence in the specific modal
    content = content.replace(old_route_onchanged, new_route_onchanged_modal, 1)

    # 5. Hook up Waypoint Search
    old_waypoint_query = """            final query = _waypointSearchController.text.trim().toLowerCase();
            final suggestions = _locationDirectory.where((location) {
              final matches =
                  query.isEmpty || location.toLowerCase().contains(query);
              final alreadySelected = _selectedWaypoints.contains(location);
              return matches && !alreadySelected;
            }).toList();"""
    new_waypoint_query = """            final query = _waypointSearchController.text.trim().toLowerCase();
            final suggestions = _cachedLocations.where((location) {
              final matches = query.isEmpty || location.toLowerCase().contains(query);
              final alreadySelected = _selectedWaypoints.contains(location);
              return matches && !alreadySelected;
            }).toList();"""
    content = content.replace(old_waypoint_query, new_waypoint_query)
    
    old_waypoint_onchanged = """                      onChanged: (_) => modalSetState(() {}),"""
    new_waypoint_onchanged = """                      onChanged: (text) async {
                        final query = text.trim().toLowerCase();
                        final locs = await SyncRepository.instance.searchLocations(query);
                        if (mounted && _waypointSearchController.text.trim().toLowerCase() == query) {
                          _cachedLocations = locs.map((e) => e.displayName).toList();
                          modalSetState(() {});
                        }
                      },"""
    # Replace the exact occurrence of waypoint search onChanged
    content = content.replace(old_waypoint_onchanged, new_waypoint_onchanged, 1)

    with open('lib/main.dart', 'w', encoding='utf-8') as f:
        f.write(content)
        
if __name__ == '__main__':
    main()
