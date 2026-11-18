class CreateTripRequest {
  const CreateTripRequest({
    required this.routeId,
    required this.vehicleId,
    this.price,
    required this.departureTime,
    required this.connectionMode,
    this.notes,
    this.isReversed = false,
    this.customWaypoints = const [],
    this.noWaypoints = false,
    this.autoReturn = false,
  });

  final int routeId;
  final int vehicleId;
  final double? price;
  final int departureTime;
  final String connectionMode;
  final String? notes;
  final bool isReversed;
  final List<CreateCustomWaypoint> customWaypoints;
  final bool noWaypoints;
  final bool autoReturn;

  Map<String, dynamic> toJson() {
    return {
      'route_id': routeId,
      'vehicle_id': vehicleId,
      if (price != null) 'price': price,
      'departure_time': departureTime,
      'connection_mode': connectionMode,
      if (notes != null) 'notes': notes,
      'is_reversed': isReversed,
      'custom_waypoints': customWaypoints.map((e) => e.toJson()).toList(),
      'no_waypoints': noWaypoints,
      'auto_return': autoReturn,
    };
  }
}

int? _asInt(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? double.tryParse(value)?.toInt();
  }
  return null;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
  }
  return fallback;
}

class CreateCustomWaypoint {
  const CreateCustomWaypoint({
    required this.locationId,
    required this.order,
    this.price,
  });

  final int locationId;
  final int order;
  final double? price;

  Map<String, dynamic> toJson() {
    return {
      'location_id': locationId,
      'order': order,
      if (price != null) 'price': price,
    };
  }
}

class TripResponse {
  const TripResponse({
    required this.id,
    required this.routeId,
    required this.vehicleId,
    required this.status,
  });

  final int id;
  final int routeId;
  final int vehicleId;
  final String status;

  factory TripResponse.fromJson(Map<String, dynamic> json) {
    return TripResponse(
      id: _asInt(json['id']) ?? 0,
      routeId: _asInt(json['route_id']) ?? 0,
      vehicleId: _asInt(json['vehicle_id']) ?? 0,
      status: json['status'] as String,
    );
  }
}

class VehicleTripsResponse {
  const VehicleTripsResponse({
    required this.trips,
    required this.total,
    required this.limit,
    required this.offset,
    required this.page,
    required this.totalPages,
    this.sseUuid,
  });

  final List<VehicleTrip> trips;
  final int total;
  final int limit;
  final int offset;
  final int page;
  final int totalPages;
  final String? sseUuid;

  factory VehicleTripsResponse.fromJson(Map<String, dynamic> json) {
    final tripsRaw = (json['trips'] as List<dynamic>? ?? const <dynamic>[])
        .map(
          (item) => VehicleTrip.fromJson((item as Map).cast<String, dynamic>()),
        )
        .toList();

    return VehicleTripsResponse(
      trips: tripsRaw,
      total: _asInt(json['total']) ?? tripsRaw.length,
      limit: _asInt(json['limit']) ?? tripsRaw.length,
      offset: _asInt(json['offset']) ?? 0,
      page: _asInt(json['page']) ?? 1,
      totalPages: _asInt(json['total_pages']) ?? 1,
      sseUuid: json['sse_uuid']?.toString(),
    );
  }
}

class VehicleTrip {
  const VehicleTrip({
    required this.id,
    required this.vehicleId,
    required this.status,
    required this.autoReturn,
    required this.route,
    required this.waypoints,
    this.departureTime,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int vehicleId;
  final String status;
  final bool autoReturn;
  final VehicleTripRoute? route;
  final List<VehicleTripWaypoint> waypoints;
  final int? departureTime;
  final int? createdAt;
  final int? updatedAt;

  factory VehicleTrip.fromJson(Map<String, dynamic> json) {
    final rawRoute = json['route'];

    return VehicleTrip(
      id: _asInt(json['id']) ?? 0,
      vehicleId: _asInt(json['vehicle_id']) ?? 0,
      status: json['status']?.toString() ?? '',
      autoReturn: _asBool(json['auto_return']),
      route: rawRoute is Map<String, dynamic>
          ? VehicleTripRoute.fromJson(rawRoute)
          : (rawRoute is Map
                ? VehicleTripRoute.fromJson(rawRoute.cast<String, dynamic>())
                : null),
      waypoints: (json['waypoints'] as List<dynamic>? ?? const <dynamic>[]).map(
        (item) {
          if (item is Map<String, dynamic>) {
            return VehicleTripWaypoint.fromJson(item);
          }
          if (item is Map) {
            return VehicleTripWaypoint.fromJson(item.cast<String, dynamic>());
          }
          return const VehicleTripWaypoint(locationName: '', order: null);
        },
      ).toList(),
      departureTime: _asInt(json['departure_time']),
      createdAt: _asInt(json['created_at']),
      updatedAt: _asInt(json['updated_at']),
    );
  }
}

class VehicleTripRoute {
  const VehicleTripRoute({
    required this.id,
    required this.origin,
    required this.destination,
  });

  final int id;
  final VehicleTripLocation? origin;
  final VehicleTripLocation? destination;

  factory VehicleTripRoute.fromJson(Map<String, dynamic> json) {
    final rawOrigin = json['origin'];
    final rawDestination = json['destination'];

    return VehicleTripRoute(
      id: _asInt(json['id']) ?? 0,
      origin: rawOrigin is Map<String, dynamic>
          ? VehicleTripLocation.fromJson(rawOrigin)
          : (rawOrigin is Map
                ? VehicleTripLocation.fromJson(
                    rawOrigin.cast<String, dynamic>(),
                  )
                : null),
      destination: rawDestination is Map<String, dynamic>
          ? VehicleTripLocation.fromJson(rawDestination)
          : (rawDestination is Map
                ? VehicleTripLocation.fromJson(
                    rawDestination.cast<String, dynamic>(),
                  )
                : null),
    );
  }
}

class VehicleTripLocation {
  const VehicleTripLocation({
    required this.id,
    this.customName,
    this.googlePlaceName,
  });

  final int id;
  final String? customName;
  final String? googlePlaceName;

  String get displayName {
    final custom = customName?.trim() ?? '';
    if (custom.isNotEmpty) {
      return custom;
    }

    final google = googlePlaceName?.trim() ?? '';
    if (google.isNotEmpty) {
      return google;
    }

    return 'Location #$id';
  }

  factory VehicleTripLocation.fromJson(Map<String, dynamic> json) {
    return VehicleTripLocation(
      id: _asInt(json['id']) ?? 0,
      customName: json['custom_name']?.toString(),
      googlePlaceName: json['google_place_name']?.toString(),
    );
  }
}

class VehicleTripWaypoint {
  const VehicleTripWaypoint({required this.locationName, required this.order});

  final String locationName;
  final int? order;

  factory VehicleTripWaypoint.fromJson(Map<String, dynamic> json) {
    final rawLocation = json['location'];
    String locationName = '';

    if (rawLocation is Map<String, dynamic>) {
      locationName = VehicleTripLocation.fromJson(rawLocation).displayName;
    } else if (rawLocation is Map) {
      locationName = VehicleTripLocation.fromJson(
        rawLocation.cast<String, dynamic>(),
      ).displayName;
    }

    return VehicleTripWaypoint(
      locationName: locationName,
      order: _asInt(json['order']),
    );
  }
}
