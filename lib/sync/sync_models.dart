import 'dart:convert';

int _intValue(dynamic value, {int fallback = 0}) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double? _doubleValue(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}

bool? _boolValue(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value.toInt() == 1;
  }
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  if (normalized == 'true' || normalized == '1') {
    return true;
  }
  if (normalized == 'false' || normalized == '0') {
    return false;
  }
  return null;
}

enum SyncOperation { created, updated, deleted }

SyncOperation parseSyncOperation(String value) {
  switch (value.toLowerCase()) {
    case 'created':
      return SyncOperation.created;
    case 'updated':
      return SyncOperation.updated;
    case 'deleted':
      return SyncOperation.deleted;
    default:
      return SyncOperation.updated;
  }
}

class LocationEntity {
  const LocationEntity({
    required this.id,
    this.latitude,
    this.longitude,
    this.code,
    this.googlePlaceName,
    this.customName,
    this.province,
    this.district,
    this.placeId,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final double? latitude;
  final double? longitude;
  final String? code;
  final String? googlePlaceName;
  final String? customName;
  final String? province;
  final String? district;
  final String? placeId;
  final String? createdAt;
  final String? updatedAt;

  String get displayName {
    final custom = customName?.trim() ?? '';
    final google = googlePlaceName?.trim() ?? '';
    if (custom.isNotEmpty) {
      return custom;
    }
    if (google.isNotEmpty) {
      return google;
    }
    return 'Location #$id';
  }

  factory LocationEntity.fromJson(Map<String, dynamic> json) {
    return LocationEntity(
      id: _intValue(json['id']),
      latitude: _doubleValue(json['latitude']),
      longitude: _doubleValue(json['longitude']),
      code: json['code']?.toString(),
      googlePlaceName: json['google_place_name']?.toString(),
      customName: json['custom_name']?.toString(),
      province: json['province']?.toString(),
      district: json['district']?.toString(),
      placeId: json['place_id']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, Object?> toDbMap() {
    return <String, Object?>{
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'code': code,
      'google_place_name': googlePlaceName,
      'custom_name': customName,
      'province': province,
      'district': district,
      'place_id': placeId,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory LocationEntity.fromDb(Map<String, Object?> row) {
    return LocationEntity(
      id: row['id'] as int,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      code: row['code'] as String?,
      googlePlaceName: row['google_place_name'] as String?,
      customName: row['custom_name'] as String?,
      province: row['province'] as String?,
      district: row['district'] as String?,
      placeId: row['place_id'] as String?,
      createdAt: row['created_at'] as String?,
      updatedAt: row['updated_at'] as String?,
    );
  }
}

class RouteEntity {
  const RouteEntity({
    required this.id,
    this.name,
    this.distanceMeters,
    this.estimatedDurationSeconds,
    this.googleRouteId,
    required this.originId,
    required this.destinationId,
    this.routePrice,
    this.cityRoute,
    this.waypoints,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String? name;
  final int? distanceMeters;
  final int? estimatedDurationSeconds;
  final String? googleRouteId;
  final int originId;
  final int destinationId;
  final double? routePrice;
  final bool? cityRoute;
  final List<dynamic>? waypoints;
  final String? createdAt;
  final String? updatedAt;

  factory RouteEntity.fromJson(Map<String, dynamic> json) {
    final originMap = json['origin'] as Map<String, dynamic>?;
    final destinationMap = json['destination'] as Map<String, dynamic>?;
    return RouteEntity(
      id: _intValue(json['id']),
      name: json['name']?.toString(),
      distanceMeters: _intValue(json['distance_meters'], fallback: 0),
      estimatedDurationSeconds: _intValue(
      json['estimated_duration_seconds'],
      fallback: 0,
      ),
      googleRouteId: json['google_route_id']?.toString(),
      originId: _intValue(json['origin_id'], fallback: _intValue(originMap?['id'])),
      destinationId: _intValue(
      json['destination_id'],
      fallback: _intValue(destinationMap?['id']),
      ),
      routePrice: _doubleValue(json['route_price']),
      cityRoute: _boolValue(json['city_route']),
      waypoints: json['waypoints'] as List<dynamic>?,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, Object?> toDbMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'distance_meters': distanceMeters,
      'estimated_duration_seconds': estimatedDurationSeconds,
      'google_route_id': googleRouteId,
      'origin_id': originId,
      'destination_id': destinationId,
      'route_price': routePrice,
      'city_route': cityRoute == null ? null : (cityRoute! ? 1 : 0),
      'waypoints': waypoints != null ? jsonEncode(waypoints) : null,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory RouteEntity.fromDb(Map<String, Object?> row) {
    return RouteEntity(
      id: row['id'] as int,
      name: row['name'] as String?,
      distanceMeters: row['distance_meters'] as int?,
      estimatedDurationSeconds: row['estimated_duration_seconds'] as int?,
      googleRouteId: row['google_route_id'] as String?,
      originId: row['origin_id'] as int,
      destinationId: row['destination_id'] as int,
      routePrice: (row['route_price'] as num?)?.toDouble(),
      cityRoute: (row['city_route'] as num?) == null
          ? null
          : (row['city_route'] as num).toInt() == 1,
      waypoints: row['waypoints'] == null
          ? null
          : jsonDecode(row['waypoints'] as String) as List<dynamic>,
      createdAt: row['created_at'] as String?,
      updatedAt: row['updated_at'] as String?,
    );
  }
}

class RouteWithLocations {
  const RouteWithLocations({
    required this.route,
    required this.origin,
    required this.destination,
  });

  final RouteEntity route;
  final LocationEntity? origin;
  final LocationEntity? destination;
}

class SyncChange<T> {
  const SyncChange({
    required this.id,
    required this.operation,
    required this.entity,
    this.changedAt,
  });

  final int id;
  final SyncOperation operation;
  final T? entity;
  final String? changedAt;
}

class SyncPage<T> {
  const SyncPage({
    required this.hash,
    required this.changed,
    required this.items,
    required this.changes,
    required this.deletedIds,
    required this.page,
    required this.limit,
    required this.total,
    required this.message,
  });

  final String hash;
  final bool changed;
  final List<T> items;
  final List<SyncChange<T>> changes;
  final List<int> deletedIds;
  final int page;
  final int limit;
  final int total;
  final String message;

  bool get indicatesInvalidHash {
    final normalized = message.toLowerCase();
    return normalized.contains('invalid hash') ||
        normalized.contains('resync') ||
        normalized.contains('without hash');
  }
}
