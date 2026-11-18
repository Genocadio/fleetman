import sys
import re

def main():
    with open('lib/main.dart', 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Fix List<dynamic> assignment error at line 1808 (waypoints parsing)
    old_waypoints = "waypoints: r.route.waypoints?.map((w) {"
    new_waypoints = "waypoints: r.route.waypoints?.map<String>((w) {"
    content = content.replace(old_waypoints, new_waypoints)
    
    old_tolist = "}).toList() ?? [],"
    new_tolist = "}).toList() ?? <String>[],"
    content = content.replace(old_tolist, new_tolist)
    
    # 2. Fix waypointIds in TripTemplate( ... )
    # At 1987 context inside _saveCurrentSelectionAsTemplate
    old_trip_template_1 = """        waypoints: orderedWaypoints,
        waypointPrices: prices,
        savedAt: DateTime.now(),"""
    new_trip_template_1 = """        waypoints: orderedWaypoints,
        waypointPrices: prices,
        waypointIds: route.waypointIds,
        savedAt: DateTime.now(),"""
    content = content.replace(old_trip_template_1, new_trip_template_1)

    # At 2795 context inside _TripTemplatesPageState._saveAsTemplate
    old_trip_template_2 = """        waypoints: orderedWaypoints,
        waypointPrices: prices,
        savedAt: DateTime.now(),"""
    new_trip_template_2 = """        waypoints: orderedWaypoints,
        waypointPrices: prices,
        waypointIds: route.waypointIds,
        savedAt: DateTime.now(),"""
    content = content.replace(old_trip_template_2, new_trip_template_2)
    
    # 3. Add cached search states to _TripTemplatesPageState
    # Let's find _TripTemplatesPageState state variables and inject cached lists
    old_state = """class _TripTemplatesPageState extends State<TripTemplatesPage> {
  final TextEditingController _routeSearchController = TextEditingController();"""
    new_state = """class _TripTemplatesPageState extends State<TripTemplatesPage> {
  List<RouteSuggestion> _cachedSearchedRoutes = [];
  final TextEditingController _routeSearchController = TextEditingController();"""
    content = content.replace(old_state, new_state)
    
    # 4. _seedRouteSuggestions usage in _TripTemplatesPageState
    old_modal_query = """                  final modalSuggestions = _selectedRoute == null
                      ? _seedRouteSuggestions.where((route) {
                          return route.origin.toLowerCase().contains(
                                modalQuery,
                              ) ||
                              route.destination.toLowerCase().contains(
                                modalQuery,
                              );
                        }).toList()
                      : const <RouteSuggestion>[];"""
    
    new_modal_query = """                  final modalSuggestions = _selectedRoute == null
                      ? _cachedSearchedRoutes
                      : const <RouteSuggestion>[];"""
    content = content.replace(old_modal_query, new_modal_query)

    # 5. Connect _TripTemplatesPageState _routeSearchController onChanged to async fetch
    old_modal_on_changed = """                                  onChanged: (_) => modalSetState(() {}),"""
    # Wait, we need to locate the one belonging to Create Template Modal.
    new_modal_on_changed = """                                  onChanged: (text) async {
                                    final query = text.trim();
                                    final results = await SyncRepository.instance.searchRoutes(query);
                                    if (mounted && _routeSearchController.text.trim() == query) {
                                      _cachedSearchedRoutes = results.map((r) => RouteSuggestion(
                                          routeId: r.route.id,
                                          origin: r.origin?.displayName ?? 'Loc #${r.route.originId}',
                                          destination: r.destination?.displayName ?? 'Loc #${r.route.destinationId}',
                                          departureTime: '',
                                          baseFare: r.route.routePrice ?? 0.0,
                                          waypoints: r.route.waypoints?.map<String>((w) {
                                            if (w is Map<String, dynamic>) {
                                              final loc = w['location'] as Map<String, dynamic>?;
                                              return loc?['custom_name'] ?? loc?['google_place_name'] ?? loc?['id']?.toString() ?? '?';
                                            }
                                            return '?';
                                          }).toList() ?? <String>[],
                                          waypointPrices: {},
                                          waypointIds: {},
                                      )).toList();
                                      modalSetState(() {});
                                    }
                                  },"""
    # Since earlier I replaced the Schedule New Trip one, the remaining one will be inside Create Template Modal. 
    # I'll let regex substitute the first occurrence or just replace them locally.
    content = content.replace(old_modal_on_changed, new_modal_on_changed, 1)

    with open('lib/main.dart', 'w', encoding='utf-8') as f:
        f.write(content)
        
if __name__ == '__main__':
    main()
