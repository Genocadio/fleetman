// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_sync_database.dart';

// ignore_for_file: type=lint
class $LocationsTable extends Locations
    with TableInfo<$LocationsTable, DriftLocation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _googlePlaceNameMeta = const VerificationMeta(
    'googlePlaceName',
  );
  @override
  late final GeneratedColumn<String> googlePlaceName = GeneratedColumn<String>(
    'google_place_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customNameMeta = const VerificationMeta(
    'customName',
  );
  @override
  late final GeneratedColumn<String> customName = GeneratedColumn<String>(
    'custom_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _provinceMeta = const VerificationMeta(
    'province',
  );
  @override
  late final GeneratedColumn<String> province = GeneratedColumn<String>(
    'province',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _districtMeta = const VerificationMeta(
    'district',
  );
  @override
  late final GeneratedColumn<String> district = GeneratedColumn<String>(
    'district',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _placeIdMeta = const VerificationMeta(
    'placeId',
  );
  @override
  late final GeneratedColumn<String> placeId = GeneratedColumn<String>(
    'place_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    latitude,
    longitude,
    code,
    googlePlaceName,
    customName,
    province,
    district,
    placeId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'locations';
  @override
  VerificationContext validateIntegrity(
    Insertable<DriftLocation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    }
    if (data.containsKey('google_place_name')) {
      context.handle(
        _googlePlaceNameMeta,
        googlePlaceName.isAcceptableOrUnknown(
          data['google_place_name']!,
          _googlePlaceNameMeta,
        ),
      );
    }
    if (data.containsKey('custom_name')) {
      context.handle(
        _customNameMeta,
        customName.isAcceptableOrUnknown(data['custom_name']!, _customNameMeta),
      );
    }
    if (data.containsKey('province')) {
      context.handle(
        _provinceMeta,
        province.isAcceptableOrUnknown(data['province']!, _provinceMeta),
      );
    }
    if (data.containsKey('district')) {
      context.handle(
        _districtMeta,
        district.isAcceptableOrUnknown(data['district']!, _districtMeta),
      );
    }
    if (data.containsKey('place_id')) {
      context.handle(
        _placeIdMeta,
        placeId.isAcceptableOrUnknown(data['place_id']!, _placeIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DriftLocation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriftLocation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      ),
      googlePlaceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}google_place_name'],
      ),
      customName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_name'],
      ),
      province: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}province'],
      ),
      district: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}district'],
      ),
      placeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}place_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $LocationsTable createAlias(String alias) {
    return $LocationsTable(attachedDatabase, alias);
  }
}

class DriftLocation extends DataClass implements Insertable<DriftLocation> {
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
  const DriftLocation({
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
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    if (!nullToAbsent || code != null) {
      map['code'] = Variable<String>(code);
    }
    if (!nullToAbsent || googlePlaceName != null) {
      map['google_place_name'] = Variable<String>(googlePlaceName);
    }
    if (!nullToAbsent || customName != null) {
      map['custom_name'] = Variable<String>(customName);
    }
    if (!nullToAbsent || province != null) {
      map['province'] = Variable<String>(province);
    }
    if (!nullToAbsent || district != null) {
      map['district'] = Variable<String>(district);
    }
    if (!nullToAbsent || placeId != null) {
      map['place_id'] = Variable<String>(placeId);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    return map;
  }

  LocationsCompanion toCompanion(bool nullToAbsent) {
    return LocationsCompanion(
      id: Value(id),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      code: code == null && nullToAbsent ? const Value.absent() : Value(code),
      googlePlaceName: googlePlaceName == null && nullToAbsent
          ? const Value.absent()
          : Value(googlePlaceName),
      customName: customName == null && nullToAbsent
          ? const Value.absent()
          : Value(customName),
      province: province == null && nullToAbsent
          ? const Value.absent()
          : Value(province),
      district: district == null && nullToAbsent
          ? const Value.absent()
          : Value(district),
      placeId: placeId == null && nullToAbsent
          ? const Value.absent()
          : Value(placeId),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory DriftLocation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriftLocation(
      id: serializer.fromJson<int>(json['id']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      code: serializer.fromJson<String?>(json['code']),
      googlePlaceName: serializer.fromJson<String?>(json['googlePlaceName']),
      customName: serializer.fromJson<String?>(json['customName']),
      province: serializer.fromJson<String?>(json['province']),
      district: serializer.fromJson<String?>(json['district']),
      placeId: serializer.fromJson<String?>(json['placeId']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'code': serializer.toJson<String?>(code),
      'googlePlaceName': serializer.toJson<String?>(googlePlaceName),
      'customName': serializer.toJson<String?>(customName),
      'province': serializer.toJson<String?>(province),
      'district': serializer.toJson<String?>(district),
      'placeId': serializer.toJson<String?>(placeId),
      'createdAt': serializer.toJson<String?>(createdAt),
      'updatedAt': serializer.toJson<String?>(updatedAt),
    };
  }

  DriftLocation copyWith({
    int? id,
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    Value<String?> code = const Value.absent(),
    Value<String?> googlePlaceName = const Value.absent(),
    Value<String?> customName = const Value.absent(),
    Value<String?> province = const Value.absent(),
    Value<String?> district = const Value.absent(),
    Value<String?> placeId = const Value.absent(),
    Value<String?> createdAt = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
  }) => DriftLocation(
    id: id ?? this.id,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
    code: code.present ? code.value : this.code,
    googlePlaceName: googlePlaceName.present
        ? googlePlaceName.value
        : this.googlePlaceName,
    customName: customName.present ? customName.value : this.customName,
    province: province.present ? province.value : this.province,
    district: district.present ? district.value : this.district,
    placeId: placeId.present ? placeId.value : this.placeId,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  DriftLocation copyWithCompanion(LocationsCompanion data) {
    return DriftLocation(
      id: data.id.present ? data.id.value : this.id,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      code: data.code.present ? data.code.value : this.code,
      googlePlaceName: data.googlePlaceName.present
          ? data.googlePlaceName.value
          : this.googlePlaceName,
      customName: data.customName.present
          ? data.customName.value
          : this.customName,
      province: data.province.present ? data.province.value : this.province,
      district: data.district.present ? data.district.value : this.district,
      placeId: data.placeId.present ? data.placeId.value : this.placeId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DriftLocation(')
          ..write('id: $id, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('code: $code, ')
          ..write('googlePlaceName: $googlePlaceName, ')
          ..write('customName: $customName, ')
          ..write('province: $province, ')
          ..write('district: $district, ')
          ..write('placeId: $placeId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    latitude,
    longitude,
    code,
    googlePlaceName,
    customName,
    province,
    district,
    placeId,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriftLocation &&
          other.id == this.id &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.code == this.code &&
          other.googlePlaceName == this.googlePlaceName &&
          other.customName == this.customName &&
          other.province == this.province &&
          other.district == this.district &&
          other.placeId == this.placeId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocationsCompanion extends UpdateCompanion<DriftLocation> {
  final Value<int> id;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<String?> code;
  final Value<String?> googlePlaceName;
  final Value<String?> customName;
  final Value<String?> province;
  final Value<String?> district;
  final Value<String?> placeId;
  final Value<String?> createdAt;
  final Value<String?> updatedAt;
  const LocationsCompanion({
    this.id = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.code = const Value.absent(),
    this.googlePlaceName = const Value.absent(),
    this.customName = const Value.absent(),
    this.province = const Value.absent(),
    this.district = const Value.absent(),
    this.placeId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  LocationsCompanion.insert({
    this.id = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.code = const Value.absent(),
    this.googlePlaceName = const Value.absent(),
    this.customName = const Value.absent(),
    this.province = const Value.absent(),
    this.district = const Value.absent(),
    this.placeId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<DriftLocation> custom({
    Expression<int>? id,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? code,
    Expression<String>? googlePlaceName,
    Expression<String>? customName,
    Expression<String>? province,
    Expression<String>? district,
    Expression<String>? placeId,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (code != null) 'code': code,
      if (googlePlaceName != null) 'google_place_name': googlePlaceName,
      if (customName != null) 'custom_name': customName,
      if (province != null) 'province': province,
      if (district != null) 'district': district,
      if (placeId != null) 'place_id': placeId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  LocationsCompanion copyWith({
    Value<int>? id,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<String?>? code,
    Value<String?>? googlePlaceName,
    Value<String?>? customName,
    Value<String?>? province,
    Value<String?>? district,
    Value<String?>? placeId,
    Value<String?>? createdAt,
    Value<String?>? updatedAt,
  }) {
    return LocationsCompanion(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      code: code ?? this.code,
      googlePlaceName: googlePlaceName ?? this.googlePlaceName,
      customName: customName ?? this.customName,
      province: province ?? this.province,
      district: district ?? this.district,
      placeId: placeId ?? this.placeId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (googlePlaceName.present) {
      map['google_place_name'] = Variable<String>(googlePlaceName.value);
    }
    if (customName.present) {
      map['custom_name'] = Variable<String>(customName.value);
    }
    if (province.present) {
      map['province'] = Variable<String>(province.value);
    }
    if (district.present) {
      map['district'] = Variable<String>(district.value);
    }
    if (placeId.present) {
      map['place_id'] = Variable<String>(placeId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocationsCompanion(')
          ..write('id: $id, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('code: $code, ')
          ..write('googlePlaceName: $googlePlaceName, ')
          ..write('customName: $customName, ')
          ..write('province: $province, ')
          ..write('district: $district, ')
          ..write('placeId: $placeId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $RoutesTable extends Routes with TableInfo<$RoutesTable, DriftRoute> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _distanceMetersMeta = const VerificationMeta(
    'distanceMeters',
  );
  @override
  late final GeneratedColumn<int> distanceMeters = GeneratedColumn<int>(
    'distance_meters',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _estimatedDurationSecondsMeta =
      const VerificationMeta('estimatedDurationSeconds');
  @override
  late final GeneratedColumn<int> estimatedDurationSeconds =
      GeneratedColumn<int>(
        'estimated_duration_seconds',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _googleRouteIdMeta = const VerificationMeta(
    'googleRouteId',
  );
  @override
  late final GeneratedColumn<String> googleRouteId = GeneratedColumn<String>(
    'google_route_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originIdMeta = const VerificationMeta(
    'originId',
  );
  @override
  late final GeneratedColumn<int> originId = GeneratedColumn<int>(
    'origin_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES locations (id)',
    ),
  );
  static const VerificationMeta _destinationIdMeta = const VerificationMeta(
    'destinationId',
  );
  @override
  late final GeneratedColumn<int> destinationId = GeneratedColumn<int>(
    'destination_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES locations (id)',
    ),
  );
  static const VerificationMeta _routePriceMeta = const VerificationMeta(
    'routePrice',
  );
  @override
  late final GeneratedColumn<double> routePrice = GeneratedColumn<double>(
    'route_price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cityRouteMeta = const VerificationMeta(
    'cityRoute',
  );
  @override
  late final GeneratedColumn<bool> cityRoute = GeneratedColumn<bool>(
    'city_route',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("city_route" IN (0, 1))',
    ),
  );
  static const VerificationMeta _waypointsMeta = const VerificationMeta(
    'waypoints',
  );
  @override
  late final GeneratedColumn<String> waypoints = GeneratedColumn<String>(
    'waypoints',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    distanceMeters,
    estimatedDurationSeconds,
    googleRouteId,
    originId,
    destinationId,
    routePrice,
    cityRoute,
    waypoints,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routes';
  @override
  VerificationContext validateIntegrity(
    Insertable<DriftRoute> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('distance_meters')) {
      context.handle(
        _distanceMetersMeta,
        distanceMeters.isAcceptableOrUnknown(
          data['distance_meters']!,
          _distanceMetersMeta,
        ),
      );
    }
    if (data.containsKey('estimated_duration_seconds')) {
      context.handle(
        _estimatedDurationSecondsMeta,
        estimatedDurationSeconds.isAcceptableOrUnknown(
          data['estimated_duration_seconds']!,
          _estimatedDurationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('google_route_id')) {
      context.handle(
        _googleRouteIdMeta,
        googleRouteId.isAcceptableOrUnknown(
          data['google_route_id']!,
          _googleRouteIdMeta,
        ),
      );
    }
    if (data.containsKey('origin_id')) {
      context.handle(
        _originIdMeta,
        originId.isAcceptableOrUnknown(data['origin_id']!, _originIdMeta),
      );
    } else if (isInserting) {
      context.missing(_originIdMeta);
    }
    if (data.containsKey('destination_id')) {
      context.handle(
        _destinationIdMeta,
        destinationId.isAcceptableOrUnknown(
          data['destination_id']!,
          _destinationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_destinationIdMeta);
    }
    if (data.containsKey('route_price')) {
      context.handle(
        _routePriceMeta,
        routePrice.isAcceptableOrUnknown(data['route_price']!, _routePriceMeta),
      );
    }
    if (data.containsKey('city_route')) {
      context.handle(
        _cityRouteMeta,
        cityRoute.isAcceptableOrUnknown(data['city_route']!, _cityRouteMeta),
      );
    }
    if (data.containsKey('waypoints')) {
      context.handle(
        _waypointsMeta,
        waypoints.isAcceptableOrUnknown(data['waypoints']!, _waypointsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DriftRoute map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriftRoute(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      distanceMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}distance_meters'],
      ),
      estimatedDurationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}estimated_duration_seconds'],
      ),
      googleRouteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}google_route_id'],
      ),
      originId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}origin_id'],
      )!,
      destinationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}destination_id'],
      )!,
      routePrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}route_price'],
      ),
      cityRoute: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}city_route'],
      ),
      waypoints: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}waypoints'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $RoutesTable createAlias(String alias) {
    return $RoutesTable(attachedDatabase, alias);
  }
}

class DriftRoute extends DataClass implements Insertable<DriftRoute> {
  final int id;
  final String? name;
  final int? distanceMeters;
  final int? estimatedDurationSeconds;
  final String? googleRouteId;
  final int originId;
  final int destinationId;
  final double? routePrice;
  final bool? cityRoute;
  final String? waypoints;
  final String? createdAt;
  final String? updatedAt;
  const DriftRoute({
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
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || distanceMeters != null) {
      map['distance_meters'] = Variable<int>(distanceMeters);
    }
    if (!nullToAbsent || estimatedDurationSeconds != null) {
      map['estimated_duration_seconds'] = Variable<int>(
        estimatedDurationSeconds,
      );
    }
    if (!nullToAbsent || googleRouteId != null) {
      map['google_route_id'] = Variable<String>(googleRouteId);
    }
    map['origin_id'] = Variable<int>(originId);
    map['destination_id'] = Variable<int>(destinationId);
    if (!nullToAbsent || routePrice != null) {
      map['route_price'] = Variable<double>(routePrice);
    }
    if (!nullToAbsent || cityRoute != null) {
      map['city_route'] = Variable<bool>(cityRoute);
    }
    if (!nullToAbsent || waypoints != null) {
      map['waypoints'] = Variable<String>(waypoints);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    return map;
  }

  RoutesCompanion toCompanion(bool nullToAbsent) {
    return RoutesCompanion(
      id: Value(id),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      distanceMeters: distanceMeters == null && nullToAbsent
          ? const Value.absent()
          : Value(distanceMeters),
      estimatedDurationSeconds: estimatedDurationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(estimatedDurationSeconds),
      googleRouteId: googleRouteId == null && nullToAbsent
          ? const Value.absent()
          : Value(googleRouteId),
      originId: Value(originId),
      destinationId: Value(destinationId),
      routePrice: routePrice == null && nullToAbsent
          ? const Value.absent()
          : Value(routePrice),
      cityRoute: cityRoute == null && nullToAbsent
          ? const Value.absent()
          : Value(cityRoute),
      waypoints: waypoints == null && nullToAbsent
          ? const Value.absent()
          : Value(waypoints),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory DriftRoute.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriftRoute(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String?>(json['name']),
      distanceMeters: serializer.fromJson<int?>(json['distanceMeters']),
      estimatedDurationSeconds: serializer.fromJson<int?>(
        json['estimatedDurationSeconds'],
      ),
      googleRouteId: serializer.fromJson<String?>(json['googleRouteId']),
      originId: serializer.fromJson<int>(json['originId']),
      destinationId: serializer.fromJson<int>(json['destinationId']),
      routePrice: serializer.fromJson<double?>(json['routePrice']),
      cityRoute: serializer.fromJson<bool?>(json['cityRoute']),
      waypoints: serializer.fromJson<String?>(json['waypoints']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String?>(name),
      'distanceMeters': serializer.toJson<int?>(distanceMeters),
      'estimatedDurationSeconds': serializer.toJson<int?>(
        estimatedDurationSeconds,
      ),
      'googleRouteId': serializer.toJson<String?>(googleRouteId),
      'originId': serializer.toJson<int>(originId),
      'destinationId': serializer.toJson<int>(destinationId),
      'routePrice': serializer.toJson<double?>(routePrice),
      'cityRoute': serializer.toJson<bool?>(cityRoute),
      'waypoints': serializer.toJson<String?>(waypoints),
      'createdAt': serializer.toJson<String?>(createdAt),
      'updatedAt': serializer.toJson<String?>(updatedAt),
    };
  }

  DriftRoute copyWith({
    int? id,
    Value<String?> name = const Value.absent(),
    Value<int?> distanceMeters = const Value.absent(),
    Value<int?> estimatedDurationSeconds = const Value.absent(),
    Value<String?> googleRouteId = const Value.absent(),
    int? originId,
    int? destinationId,
    Value<double?> routePrice = const Value.absent(),
    Value<bool?> cityRoute = const Value.absent(),
    Value<String?> waypoints = const Value.absent(),
    Value<String?> createdAt = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
  }) => DriftRoute(
    id: id ?? this.id,
    name: name.present ? name.value : this.name,
    distanceMeters: distanceMeters.present
        ? distanceMeters.value
        : this.distanceMeters,
    estimatedDurationSeconds: estimatedDurationSeconds.present
        ? estimatedDurationSeconds.value
        : this.estimatedDurationSeconds,
    googleRouteId: googleRouteId.present
        ? googleRouteId.value
        : this.googleRouteId,
    originId: originId ?? this.originId,
    destinationId: destinationId ?? this.destinationId,
    routePrice: routePrice.present ? routePrice.value : this.routePrice,
    cityRoute: cityRoute.present ? cityRoute.value : this.cityRoute,
    waypoints: waypoints.present ? waypoints.value : this.waypoints,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  DriftRoute copyWithCompanion(RoutesCompanion data) {
    return DriftRoute(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      distanceMeters: data.distanceMeters.present
          ? data.distanceMeters.value
          : this.distanceMeters,
      estimatedDurationSeconds: data.estimatedDurationSeconds.present
          ? data.estimatedDurationSeconds.value
          : this.estimatedDurationSeconds,
      googleRouteId: data.googleRouteId.present
          ? data.googleRouteId.value
          : this.googleRouteId,
      originId: data.originId.present ? data.originId.value : this.originId,
      destinationId: data.destinationId.present
          ? data.destinationId.value
          : this.destinationId,
      routePrice: data.routePrice.present
          ? data.routePrice.value
          : this.routePrice,
      cityRoute: data.cityRoute.present ? data.cityRoute.value : this.cityRoute,
      waypoints: data.waypoints.present ? data.waypoints.value : this.waypoints,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DriftRoute(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('distanceMeters: $distanceMeters, ')
          ..write('estimatedDurationSeconds: $estimatedDurationSeconds, ')
          ..write('googleRouteId: $googleRouteId, ')
          ..write('originId: $originId, ')
          ..write('destinationId: $destinationId, ')
          ..write('routePrice: $routePrice, ')
          ..write('cityRoute: $cityRoute, ')
          ..write('waypoints: $waypoints, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    distanceMeters,
    estimatedDurationSeconds,
    googleRouteId,
    originId,
    destinationId,
    routePrice,
    cityRoute,
    waypoints,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriftRoute &&
          other.id == this.id &&
          other.name == this.name &&
          other.distanceMeters == this.distanceMeters &&
          other.estimatedDurationSeconds == this.estimatedDurationSeconds &&
          other.googleRouteId == this.googleRouteId &&
          other.originId == this.originId &&
          other.destinationId == this.destinationId &&
          other.routePrice == this.routePrice &&
          other.cityRoute == this.cityRoute &&
          other.waypoints == this.waypoints &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RoutesCompanion extends UpdateCompanion<DriftRoute> {
  final Value<int> id;
  final Value<String?> name;
  final Value<int?> distanceMeters;
  final Value<int?> estimatedDurationSeconds;
  final Value<String?> googleRouteId;
  final Value<int> originId;
  final Value<int> destinationId;
  final Value<double?> routePrice;
  final Value<bool?> cityRoute;
  final Value<String?> waypoints;
  final Value<String?> createdAt;
  final Value<String?> updatedAt;
  const RoutesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.distanceMeters = const Value.absent(),
    this.estimatedDurationSeconds = const Value.absent(),
    this.googleRouteId = const Value.absent(),
    this.originId = const Value.absent(),
    this.destinationId = const Value.absent(),
    this.routePrice = const Value.absent(),
    this.cityRoute = const Value.absent(),
    this.waypoints = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  RoutesCompanion.insert({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.distanceMeters = const Value.absent(),
    this.estimatedDurationSeconds = const Value.absent(),
    this.googleRouteId = const Value.absent(),
    required int originId,
    required int destinationId,
    this.routePrice = const Value.absent(),
    this.cityRoute = const Value.absent(),
    this.waypoints = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : originId = Value(originId),
       destinationId = Value(destinationId);
  static Insertable<DriftRoute> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? distanceMeters,
    Expression<int>? estimatedDurationSeconds,
    Expression<String>? googleRouteId,
    Expression<int>? originId,
    Expression<int>? destinationId,
    Expression<double>? routePrice,
    Expression<bool>? cityRoute,
    Expression<String>? waypoints,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (distanceMeters != null) 'distance_meters': distanceMeters,
      if (estimatedDurationSeconds != null)
        'estimated_duration_seconds': estimatedDurationSeconds,
      if (googleRouteId != null) 'google_route_id': googleRouteId,
      if (originId != null) 'origin_id': originId,
      if (destinationId != null) 'destination_id': destinationId,
      if (routePrice != null) 'route_price': routePrice,
      if (cityRoute != null) 'city_route': cityRoute,
      if (waypoints != null) 'waypoints': waypoints,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  RoutesCompanion copyWith({
    Value<int>? id,
    Value<String?>? name,
    Value<int?>? distanceMeters,
    Value<int?>? estimatedDurationSeconds,
    Value<String?>? googleRouteId,
    Value<int>? originId,
    Value<int>? destinationId,
    Value<double?>? routePrice,
    Value<bool?>? cityRoute,
    Value<String?>? waypoints,
    Value<String?>? createdAt,
    Value<String?>? updatedAt,
  }) {
    return RoutesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      estimatedDurationSeconds:
          estimatedDurationSeconds ?? this.estimatedDurationSeconds,
      googleRouteId: googleRouteId ?? this.googleRouteId,
      originId: originId ?? this.originId,
      destinationId: destinationId ?? this.destinationId,
      routePrice: routePrice ?? this.routePrice,
      cityRoute: cityRoute ?? this.cityRoute,
      waypoints: waypoints ?? this.waypoints,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (distanceMeters.present) {
      map['distance_meters'] = Variable<int>(distanceMeters.value);
    }
    if (estimatedDurationSeconds.present) {
      map['estimated_duration_seconds'] = Variable<int>(
        estimatedDurationSeconds.value,
      );
    }
    if (googleRouteId.present) {
      map['google_route_id'] = Variable<String>(googleRouteId.value);
    }
    if (originId.present) {
      map['origin_id'] = Variable<int>(originId.value);
    }
    if (destinationId.present) {
      map['destination_id'] = Variable<int>(destinationId.value);
    }
    if (routePrice.present) {
      map['route_price'] = Variable<double>(routePrice.value);
    }
    if (cityRoute.present) {
      map['city_route'] = Variable<bool>(cityRoute.value);
    }
    if (waypoints.present) {
      map['waypoints'] = Variable<String>(waypoints.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('distanceMeters: $distanceMeters, ')
          ..write('estimatedDurationSeconds: $estimatedDurationSeconds, ')
          ..write('googleRouteId: $googleRouteId, ')
          ..write('originId: $originId, ')
          ..write('destinationId: $destinationId, ')
          ..write('routePrice: $routePrice, ')
          ..write('cityRoute: $cityRoute, ')
          ..write('waypoints: $waypoints, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $SyncStatesTable extends SyncStates
    with TableInfo<$SyncStatesTable, DriftSyncState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<DriftSyncState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  DriftSyncState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriftSyncState(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SyncStatesTable createAlias(String alias) {
    return $SyncStatesTable(attachedDatabase, alias);
  }
}

class DriftSyncState extends DataClass implements Insertable<DriftSyncState> {
  final String key;
  final String value;
  const DriftSyncState({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncStatesCompanion toCompanion(bool nullToAbsent) {
    return SyncStatesCompanion(key: Value(key), value: Value(value));
  }

  factory DriftSyncState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriftSyncState(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  DriftSyncState copyWith({String? key, String? value}) =>
      DriftSyncState(key: key ?? this.key, value: value ?? this.value);
  DriftSyncState copyWithCompanion(SyncStatesCompanion data) {
    return DriftSyncState(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DriftSyncState(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriftSyncState &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncStatesCompanion extends UpdateCompanion<DriftSyncState> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncStatesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStatesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<DriftSyncState> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStatesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncStatesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStatesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TripTemplatesTable extends TripTemplates
    with TableInfo<$TripTemplatesTable, DriftTripTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _routeIdMeta = const VerificationMeta(
    'routeId',
  );
  @override
  late final GeneratedColumn<int> routeId = GeneratedColumn<int>(
    'route_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _destinationMeta = const VerificationMeta(
    'destination',
  );
  @override
  late final GeneratedColumn<String> destination = GeneratedColumn<String>(
    'destination',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseFareMeta = const VerificationMeta(
    'baseFare',
  );
  @override
  late final GeneratedColumn<double> baseFare = GeneratedColumn<double>(
    'base_fare',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _waypointsMeta = const VerificationMeta(
    'waypoints',
  );
  @override
  late final GeneratedColumn<String> waypoints = GeneratedColumn<String>(
    'waypoints',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _waypointPricesMeta = const VerificationMeta(
    'waypointPrices',
  );
  @override
  late final GeneratedColumn<String> waypointPrices = GeneratedColumn<String>(
    'waypoint_prices',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _waypointIdsMeta = const VerificationMeta(
    'waypointIds',
  );
  @override
  late final GeneratedColumn<String> waypointIds = GeneratedColumn<String>(
    'waypoint_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _savedAtMeta = const VerificationMeta(
    'savedAt',
  );
  @override
  late final GeneratedColumn<int> savedAt = GeneratedColumn<int>(
    'saved_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isReversedMeta = const VerificationMeta(
    'isReversed',
  );
  @override
  late final GeneratedColumn<bool> isReversed = GeneratedColumn<bool>(
    'is_reversed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_reversed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    routeId,
    origin,
    destination,
    baseFare,
    waypoints,
    waypointPrices,
    waypointIds,
    savedAt,
    isReversed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trip_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<DriftTripTemplate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('route_id')) {
      context.handle(
        _routeIdMeta,
        routeId.isAcceptableOrUnknown(data['route_id']!, _routeIdMeta),
      );
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    } else if (isInserting) {
      context.missing(_originMeta);
    }
    if (data.containsKey('destination')) {
      context.handle(
        _destinationMeta,
        destination.isAcceptableOrUnknown(
          data['destination']!,
          _destinationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_destinationMeta);
    }
    if (data.containsKey('base_fare')) {
      context.handle(
        _baseFareMeta,
        baseFare.isAcceptableOrUnknown(data['base_fare']!, _baseFareMeta),
      );
    } else if (isInserting) {
      context.missing(_baseFareMeta);
    }
    if (data.containsKey('waypoints')) {
      context.handle(
        _waypointsMeta,
        waypoints.isAcceptableOrUnknown(data['waypoints']!, _waypointsMeta),
      );
    } else if (isInserting) {
      context.missing(_waypointsMeta);
    }
    if (data.containsKey('waypoint_prices')) {
      context.handle(
        _waypointPricesMeta,
        waypointPrices.isAcceptableOrUnknown(
          data['waypoint_prices']!,
          _waypointPricesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_waypointPricesMeta);
    }
    if (data.containsKey('waypoint_ids')) {
      context.handle(
        _waypointIdsMeta,
        waypointIds.isAcceptableOrUnknown(
          data['waypoint_ids']!,
          _waypointIdsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_waypointIdsMeta);
    }
    if (data.containsKey('saved_at')) {
      context.handle(
        _savedAtMeta,
        savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_savedAtMeta);
    }
    if (data.containsKey('is_reversed')) {
      context.handle(
        _isReversedMeta,
        isReversed.isAcceptableOrUnknown(data['is_reversed']!, _isReversedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DriftTripTemplate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriftTripTemplate(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      routeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}route_id'],
      ),
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      )!,
      destination: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destination'],
      )!,
      baseFare: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}base_fare'],
      )!,
      waypoints: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}waypoints'],
      )!,
      waypointPrices: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}waypoint_prices'],
      )!,
      waypointIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}waypoint_ids'],
      )!,
      savedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}saved_at'],
      )!,
      isReversed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_reversed'],
      )!,
    );
  }

  @override
  $TripTemplatesTable createAlias(String alias) {
    return $TripTemplatesTable(attachedDatabase, alias);
  }
}

class DriftTripTemplate extends DataClass
    implements Insertable<DriftTripTemplate> {
  final String id;
  final int? routeId;
  final String origin;
  final String destination;
  final double baseFare;
  final String waypoints;
  final String waypointPrices;
  final String waypointIds;
  final int savedAt;
  final bool isReversed;
  const DriftTripTemplate({
    required this.id,
    this.routeId,
    required this.origin,
    required this.destination,
    required this.baseFare,
    required this.waypoints,
    required this.waypointPrices,
    required this.waypointIds,
    required this.savedAt,
    required this.isReversed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || routeId != null) {
      map['route_id'] = Variable<int>(routeId);
    }
    map['origin'] = Variable<String>(origin);
    map['destination'] = Variable<String>(destination);
    map['base_fare'] = Variable<double>(baseFare);
    map['waypoints'] = Variable<String>(waypoints);
    map['waypoint_prices'] = Variable<String>(waypointPrices);
    map['waypoint_ids'] = Variable<String>(waypointIds);
    map['saved_at'] = Variable<int>(savedAt);
    map['is_reversed'] = Variable<bool>(isReversed);
    return map;
  }

  TripTemplatesCompanion toCompanion(bool nullToAbsent) {
    return TripTemplatesCompanion(
      id: Value(id),
      routeId: routeId == null && nullToAbsent
          ? const Value.absent()
          : Value(routeId),
      origin: Value(origin),
      destination: Value(destination),
      baseFare: Value(baseFare),
      waypoints: Value(waypoints),
      waypointPrices: Value(waypointPrices),
      waypointIds: Value(waypointIds),
      savedAt: Value(savedAt),
      isReversed: Value(isReversed),
    );
  }

  factory DriftTripTemplate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriftTripTemplate(
      id: serializer.fromJson<String>(json['id']),
      routeId: serializer.fromJson<int?>(json['routeId']),
      origin: serializer.fromJson<String>(json['origin']),
      destination: serializer.fromJson<String>(json['destination']),
      baseFare: serializer.fromJson<double>(json['baseFare']),
      waypoints: serializer.fromJson<String>(json['waypoints']),
      waypointPrices: serializer.fromJson<String>(json['waypointPrices']),
      waypointIds: serializer.fromJson<String>(json['waypointIds']),
      savedAt: serializer.fromJson<int>(json['savedAt']),
      isReversed: serializer.fromJson<bool>(json['isReversed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'routeId': serializer.toJson<int?>(routeId),
      'origin': serializer.toJson<String>(origin),
      'destination': serializer.toJson<String>(destination),
      'baseFare': serializer.toJson<double>(baseFare),
      'waypoints': serializer.toJson<String>(waypoints),
      'waypointPrices': serializer.toJson<String>(waypointPrices),
      'waypointIds': serializer.toJson<String>(waypointIds),
      'savedAt': serializer.toJson<int>(savedAt),
      'isReversed': serializer.toJson<bool>(isReversed),
    };
  }

  DriftTripTemplate copyWith({
    String? id,
    Value<int?> routeId = const Value.absent(),
    String? origin,
    String? destination,
    double? baseFare,
    String? waypoints,
    String? waypointPrices,
    String? waypointIds,
    int? savedAt,
    bool? isReversed,
  }) => DriftTripTemplate(
    id: id ?? this.id,
    routeId: routeId.present ? routeId.value : this.routeId,
    origin: origin ?? this.origin,
    destination: destination ?? this.destination,
    baseFare: baseFare ?? this.baseFare,
    waypoints: waypoints ?? this.waypoints,
    waypointPrices: waypointPrices ?? this.waypointPrices,
    waypointIds: waypointIds ?? this.waypointIds,
    savedAt: savedAt ?? this.savedAt,
    isReversed: isReversed ?? this.isReversed,
  );
  DriftTripTemplate copyWithCompanion(TripTemplatesCompanion data) {
    return DriftTripTemplate(
      id: data.id.present ? data.id.value : this.id,
      routeId: data.routeId.present ? data.routeId.value : this.routeId,
      origin: data.origin.present ? data.origin.value : this.origin,
      destination: data.destination.present
          ? data.destination.value
          : this.destination,
      baseFare: data.baseFare.present ? data.baseFare.value : this.baseFare,
      waypoints: data.waypoints.present ? data.waypoints.value : this.waypoints,
      waypointPrices: data.waypointPrices.present
          ? data.waypointPrices.value
          : this.waypointPrices,
      waypointIds: data.waypointIds.present
          ? data.waypointIds.value
          : this.waypointIds,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
      isReversed: data.isReversed.present
          ? data.isReversed.value
          : this.isReversed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DriftTripTemplate(')
          ..write('id: $id, ')
          ..write('routeId: $routeId, ')
          ..write('origin: $origin, ')
          ..write('destination: $destination, ')
          ..write('baseFare: $baseFare, ')
          ..write('waypoints: $waypoints, ')
          ..write('waypointPrices: $waypointPrices, ')
          ..write('waypointIds: $waypointIds, ')
          ..write('savedAt: $savedAt, ')
          ..write('isReversed: $isReversed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    routeId,
    origin,
    destination,
    baseFare,
    waypoints,
    waypointPrices,
    waypointIds,
    savedAt,
    isReversed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriftTripTemplate &&
          other.id == this.id &&
          other.routeId == this.routeId &&
          other.origin == this.origin &&
          other.destination == this.destination &&
          other.baseFare == this.baseFare &&
          other.waypoints == this.waypoints &&
          other.waypointPrices == this.waypointPrices &&
          other.waypointIds == this.waypointIds &&
          other.savedAt == this.savedAt &&
          other.isReversed == this.isReversed);
}

class TripTemplatesCompanion extends UpdateCompanion<DriftTripTemplate> {
  final Value<String> id;
  final Value<int?> routeId;
  final Value<String> origin;
  final Value<String> destination;
  final Value<double> baseFare;
  final Value<String> waypoints;
  final Value<String> waypointPrices;
  final Value<String> waypointIds;
  final Value<int> savedAt;
  final Value<bool> isReversed;
  final Value<int> rowid;
  const TripTemplatesCompanion({
    this.id = const Value.absent(),
    this.routeId = const Value.absent(),
    this.origin = const Value.absent(),
    this.destination = const Value.absent(),
    this.baseFare = const Value.absent(),
    this.waypoints = const Value.absent(),
    this.waypointPrices = const Value.absent(),
    this.waypointIds = const Value.absent(),
    this.savedAt = const Value.absent(),
    this.isReversed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TripTemplatesCompanion.insert({
    required String id,
    this.routeId = const Value.absent(),
    required String origin,
    required String destination,
    required double baseFare,
    required String waypoints,
    required String waypointPrices,
    required String waypointIds,
    required int savedAt,
    this.isReversed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       origin = Value(origin),
       destination = Value(destination),
       baseFare = Value(baseFare),
       waypoints = Value(waypoints),
       waypointPrices = Value(waypointPrices),
       waypointIds = Value(waypointIds),
       savedAt = Value(savedAt);
  static Insertable<DriftTripTemplate> custom({
    Expression<String>? id,
    Expression<int>? routeId,
    Expression<String>? origin,
    Expression<String>? destination,
    Expression<double>? baseFare,
    Expression<String>? waypoints,
    Expression<String>? waypointPrices,
    Expression<String>? waypointIds,
    Expression<int>? savedAt,
    Expression<bool>? isReversed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (routeId != null) 'route_id': routeId,
      if (origin != null) 'origin': origin,
      if (destination != null) 'destination': destination,
      if (baseFare != null) 'base_fare': baseFare,
      if (waypoints != null) 'waypoints': waypoints,
      if (waypointPrices != null) 'waypoint_prices': waypointPrices,
      if (waypointIds != null) 'waypoint_ids': waypointIds,
      if (savedAt != null) 'saved_at': savedAt,
      if (isReversed != null) 'is_reversed': isReversed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TripTemplatesCompanion copyWith({
    Value<String>? id,
    Value<int?>? routeId,
    Value<String>? origin,
    Value<String>? destination,
    Value<double>? baseFare,
    Value<String>? waypoints,
    Value<String>? waypointPrices,
    Value<String>? waypointIds,
    Value<int>? savedAt,
    Value<bool>? isReversed,
    Value<int>? rowid,
  }) {
    return TripTemplatesCompanion(
      id: id ?? this.id,
      routeId: routeId ?? this.routeId,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      baseFare: baseFare ?? this.baseFare,
      waypoints: waypoints ?? this.waypoints,
      waypointPrices: waypointPrices ?? this.waypointPrices,
      waypointIds: waypointIds ?? this.waypointIds,
      savedAt: savedAt ?? this.savedAt,
      isReversed: isReversed ?? this.isReversed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (routeId.present) {
      map['route_id'] = Variable<int>(routeId.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (destination.present) {
      map['destination'] = Variable<String>(destination.value);
    }
    if (baseFare.present) {
      map['base_fare'] = Variable<double>(baseFare.value);
    }
    if (waypoints.present) {
      map['waypoints'] = Variable<String>(waypoints.value);
    }
    if (waypointPrices.present) {
      map['waypoint_prices'] = Variable<String>(waypointPrices.value);
    }
    if (waypointIds.present) {
      map['waypoint_ids'] = Variable<String>(waypointIds.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<int>(savedAt.value);
    }
    if (isReversed.present) {
      map['is_reversed'] = Variable<bool>(isReversed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('routeId: $routeId, ')
          ..write('origin: $origin, ')
          ..write('destination: $destination, ')
          ..write('baseFare: $baseFare, ')
          ..write('waypoints: $waypoints, ')
          ..write('waypointPrices: $waypointPrices, ')
          ..write('waypointIds: $waypointIds, ')
          ..write('savedAt: $savedAt, ')
          ..write('isReversed: $isReversed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalSyncDatabase extends GeneratedDatabase {
  _$LocalSyncDatabase(QueryExecutor e) : super(e);
  $LocalSyncDatabaseManager get managers => $LocalSyncDatabaseManager(this);
  late final $LocationsTable locations = $LocationsTable(this);
  late final $RoutesTable routes = $RoutesTable(this);
  late final $SyncStatesTable syncStates = $SyncStatesTable(this);
  late final $TripTemplatesTable tripTemplates = $TripTemplatesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    locations,
    routes,
    syncStates,
    tripTemplates,
  ];
}

typedef $$LocationsTableCreateCompanionBuilder =
    LocationsCompanion Function({
      Value<int> id,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<String?> code,
      Value<String?> googlePlaceName,
      Value<String?> customName,
      Value<String?> province,
      Value<String?> district,
      Value<String?> placeId,
      Value<String?> createdAt,
      Value<String?> updatedAt,
    });
typedef $$LocationsTableUpdateCompanionBuilder =
    LocationsCompanion Function({
      Value<int> id,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<String?> code,
      Value<String?> googlePlaceName,
      Value<String?> customName,
      Value<String?> province,
      Value<String?> district,
      Value<String?> placeId,
      Value<String?> createdAt,
      Value<String?> updatedAt,
    });

class $$LocationsTableFilterComposer
    extends Composer<_$LocalSyncDatabase, $LocationsTable> {
  $$LocationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get googlePlaceName => $composableBuilder(
    column: $table.googlePlaceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customName => $composableBuilder(
    column: $table.customName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get province => $composableBuilder(
    column: $table.province,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get district => $composableBuilder(
    column: $table.district,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get placeId => $composableBuilder(
    column: $table.placeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocationsTableOrderingComposer
    extends Composer<_$LocalSyncDatabase, $LocationsTable> {
  $$LocationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get googlePlaceName => $composableBuilder(
    column: $table.googlePlaceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customName => $composableBuilder(
    column: $table.customName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get province => $composableBuilder(
    column: $table.province,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get district => $composableBuilder(
    column: $table.district,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get placeId => $composableBuilder(
    column: $table.placeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocationsTableAnnotationComposer
    extends Composer<_$LocalSyncDatabase, $LocationsTable> {
  $$LocationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get googlePlaceName => $composableBuilder(
    column: $table.googlePlaceName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customName => $composableBuilder(
    column: $table.customName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get province =>
      $composableBuilder(column: $table.province, builder: (column) => column);

  GeneratedColumn<String> get district =>
      $composableBuilder(column: $table.district, builder: (column) => column);

  GeneratedColumn<String> get placeId =>
      $composableBuilder(column: $table.placeId, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocationsTableTableManager
    extends
        RootTableManager<
          _$LocalSyncDatabase,
          $LocationsTable,
          DriftLocation,
          $$LocationsTableFilterComposer,
          $$LocationsTableOrderingComposer,
          $$LocationsTableAnnotationComposer,
          $$LocationsTableCreateCompanionBuilder,
          $$LocationsTableUpdateCompanionBuilder,
          (
            DriftLocation,
            BaseReferences<_$LocalSyncDatabase, $LocationsTable, DriftLocation>,
          ),
          DriftLocation,
          PrefetchHooks Function()
        > {
  $$LocationsTableTableManager(_$LocalSyncDatabase db, $LocationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<String?> code = const Value.absent(),
                Value<String?> googlePlaceName = const Value.absent(),
                Value<String?> customName = const Value.absent(),
                Value<String?> province = const Value.absent(),
                Value<String?> district = const Value.absent(),
                Value<String?> placeId = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
              }) => LocationsCompanion(
                id: id,
                latitude: latitude,
                longitude: longitude,
                code: code,
                googlePlaceName: googlePlaceName,
                customName: customName,
                province: province,
                district: district,
                placeId: placeId,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<String?> code = const Value.absent(),
                Value<String?> googlePlaceName = const Value.absent(),
                Value<String?> customName = const Value.absent(),
                Value<String?> province = const Value.absent(),
                Value<String?> district = const Value.absent(),
                Value<String?> placeId = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
              }) => LocationsCompanion.insert(
                id: id,
                latitude: latitude,
                longitude: longitude,
                code: code,
                googlePlaceName: googlePlaceName,
                customName: customName,
                province: province,
                district: district,
                placeId: placeId,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocationsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalSyncDatabase,
      $LocationsTable,
      DriftLocation,
      $$LocationsTableFilterComposer,
      $$LocationsTableOrderingComposer,
      $$LocationsTableAnnotationComposer,
      $$LocationsTableCreateCompanionBuilder,
      $$LocationsTableUpdateCompanionBuilder,
      (
        DriftLocation,
        BaseReferences<_$LocalSyncDatabase, $LocationsTable, DriftLocation>,
      ),
      DriftLocation,
      PrefetchHooks Function()
    >;
typedef $$RoutesTableCreateCompanionBuilder =
    RoutesCompanion Function({
      Value<int> id,
      Value<String?> name,
      Value<int?> distanceMeters,
      Value<int?> estimatedDurationSeconds,
      Value<String?> googleRouteId,
      required int originId,
      required int destinationId,
      Value<double?> routePrice,
      Value<bool?> cityRoute,
      Value<String?> waypoints,
      Value<String?> createdAt,
      Value<String?> updatedAt,
    });
typedef $$RoutesTableUpdateCompanionBuilder =
    RoutesCompanion Function({
      Value<int> id,
      Value<String?> name,
      Value<int?> distanceMeters,
      Value<int?> estimatedDurationSeconds,
      Value<String?> googleRouteId,
      Value<int> originId,
      Value<int> destinationId,
      Value<double?> routePrice,
      Value<bool?> cityRoute,
      Value<String?> waypoints,
      Value<String?> createdAt,
      Value<String?> updatedAt,
    });

final class $$RoutesTableReferences
    extends BaseReferences<_$LocalSyncDatabase, $RoutesTable, DriftRoute> {
  $$RoutesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LocationsTable _originIdTable(_$LocalSyncDatabase db) => db.locations
      .createAlias($_aliasNameGenerator(db.routes.originId, db.locations.id));

  $$LocationsTableProcessedTableManager get originId {
    final $_column = $_itemColumn<int>('origin_id')!;

    final manager = $$LocationsTableTableManager(
      $_db,
      $_db.locations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_originIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LocationsTable _destinationIdTable(_$LocalSyncDatabase db) =>
      db.locations.createAlias(
        $_aliasNameGenerator(db.routes.destinationId, db.locations.id),
      );

  $$LocationsTableProcessedTableManager get destinationId {
    final $_column = $_itemColumn<int>('destination_id')!;

    final manager = $$LocationsTableTableManager(
      $_db,
      $_db.locations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_destinationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RoutesTableFilterComposer
    extends Composer<_$LocalSyncDatabase, $RoutesTable> {
  $$RoutesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estimatedDurationSeconds => $composableBuilder(
    column: $table.estimatedDurationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get googleRouteId => $composableBuilder(
    column: $table.googleRouteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get routePrice => $composableBuilder(
    column: $table.routePrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get cityRoute => $composableBuilder(
    column: $table.cityRoute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get waypoints => $composableBuilder(
    column: $table.waypoints,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LocationsTableFilterComposer get originId {
    final $$LocationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.originId,
      referencedTable: $db.locations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationsTableFilterComposer(
            $db: $db,
            $table: $db.locations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LocationsTableFilterComposer get destinationId {
    final $$LocationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.destinationId,
      referencedTable: $db.locations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationsTableFilterComposer(
            $db: $db,
            $table: $db.locations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RoutesTableOrderingComposer
    extends Composer<_$LocalSyncDatabase, $RoutesTable> {
  $$RoutesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estimatedDurationSeconds => $composableBuilder(
    column: $table.estimatedDurationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get googleRouteId => $composableBuilder(
    column: $table.googleRouteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get routePrice => $composableBuilder(
    column: $table.routePrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get cityRoute => $composableBuilder(
    column: $table.cityRoute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get waypoints => $composableBuilder(
    column: $table.waypoints,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocationsTableOrderingComposer get originId {
    final $$LocationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.originId,
      referencedTable: $db.locations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationsTableOrderingComposer(
            $db: $db,
            $table: $db.locations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LocationsTableOrderingComposer get destinationId {
    final $$LocationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.destinationId,
      referencedTable: $db.locations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationsTableOrderingComposer(
            $db: $db,
            $table: $db.locations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RoutesTableAnnotationComposer
    extends Composer<_$LocalSyncDatabase, $RoutesTable> {
  $$RoutesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => column,
  );

  GeneratedColumn<int> get estimatedDurationSeconds => $composableBuilder(
    column: $table.estimatedDurationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get googleRouteId => $composableBuilder(
    column: $table.googleRouteId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get routePrice => $composableBuilder(
    column: $table.routePrice,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get cityRoute =>
      $composableBuilder(column: $table.cityRoute, builder: (column) => column);

  GeneratedColumn<String> get waypoints =>
      $composableBuilder(column: $table.waypoints, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$LocationsTableAnnotationComposer get originId {
    final $$LocationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.originId,
      referencedTable: $db.locations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationsTableAnnotationComposer(
            $db: $db,
            $table: $db.locations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LocationsTableAnnotationComposer get destinationId {
    final $$LocationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.destinationId,
      referencedTable: $db.locations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocationsTableAnnotationComposer(
            $db: $db,
            $table: $db.locations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RoutesTableTableManager
    extends
        RootTableManager<
          _$LocalSyncDatabase,
          $RoutesTable,
          DriftRoute,
          $$RoutesTableFilterComposer,
          $$RoutesTableOrderingComposer,
          $$RoutesTableAnnotationComposer,
          $$RoutesTableCreateCompanionBuilder,
          $$RoutesTableUpdateCompanionBuilder,
          (DriftRoute, $$RoutesTableReferences),
          DriftRoute,
          PrefetchHooks Function({bool originId, bool destinationId})
        > {
  $$RoutesTableTableManager(_$LocalSyncDatabase db, $RoutesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoutesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoutesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoutesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<int?> distanceMeters = const Value.absent(),
                Value<int?> estimatedDurationSeconds = const Value.absent(),
                Value<String?> googleRouteId = const Value.absent(),
                Value<int> originId = const Value.absent(),
                Value<int> destinationId = const Value.absent(),
                Value<double?> routePrice = const Value.absent(),
                Value<bool?> cityRoute = const Value.absent(),
                Value<String?> waypoints = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
              }) => RoutesCompanion(
                id: id,
                name: name,
                distanceMeters: distanceMeters,
                estimatedDurationSeconds: estimatedDurationSeconds,
                googleRouteId: googleRouteId,
                originId: originId,
                destinationId: destinationId,
                routePrice: routePrice,
                cityRoute: cityRoute,
                waypoints: waypoints,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<int?> distanceMeters = const Value.absent(),
                Value<int?> estimatedDurationSeconds = const Value.absent(),
                Value<String?> googleRouteId = const Value.absent(),
                required int originId,
                required int destinationId,
                Value<double?> routePrice = const Value.absent(),
                Value<bool?> cityRoute = const Value.absent(),
                Value<String?> waypoints = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
              }) => RoutesCompanion.insert(
                id: id,
                name: name,
                distanceMeters: distanceMeters,
                estimatedDurationSeconds: estimatedDurationSeconds,
                googleRouteId: googleRouteId,
                originId: originId,
                destinationId: destinationId,
                routePrice: routePrice,
                cityRoute: cityRoute,
                waypoints: waypoints,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$RoutesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({originId = false, destinationId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (originId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.originId,
                                referencedTable: $$RoutesTableReferences
                                    ._originIdTable(db),
                                referencedColumn: $$RoutesTableReferences
                                    ._originIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (destinationId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.destinationId,
                                referencedTable: $$RoutesTableReferences
                                    ._destinationIdTable(db),
                                referencedColumn: $$RoutesTableReferences
                                    ._destinationIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RoutesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalSyncDatabase,
      $RoutesTable,
      DriftRoute,
      $$RoutesTableFilterComposer,
      $$RoutesTableOrderingComposer,
      $$RoutesTableAnnotationComposer,
      $$RoutesTableCreateCompanionBuilder,
      $$RoutesTableUpdateCompanionBuilder,
      (DriftRoute, $$RoutesTableReferences),
      DriftRoute,
      PrefetchHooks Function({bool originId, bool destinationId})
    >;
typedef $$SyncStatesTableCreateCompanionBuilder =
    SyncStatesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SyncStatesTableUpdateCompanionBuilder =
    SyncStatesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SyncStatesTableFilterComposer
    extends Composer<_$LocalSyncDatabase, $SyncStatesTable> {
  $$SyncStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStatesTableOrderingComposer
    extends Composer<_$LocalSyncDatabase, $SyncStatesTable> {
  $$SyncStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStatesTableAnnotationComposer
    extends Composer<_$LocalSyncDatabase, $SyncStatesTable> {
  $$SyncStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncStatesTableTableManager
    extends
        RootTableManager<
          _$LocalSyncDatabase,
          $SyncStatesTable,
          DriftSyncState,
          $$SyncStatesTableFilterComposer,
          $$SyncStatesTableOrderingComposer,
          $$SyncStatesTableAnnotationComposer,
          $$SyncStatesTableCreateCompanionBuilder,
          $$SyncStatesTableUpdateCompanionBuilder,
          (
            DriftSyncState,
            BaseReferences<
              _$LocalSyncDatabase,
              $SyncStatesTable,
              DriftSyncState
            >,
          ),
          DriftSyncState,
          PrefetchHooks Function()
        > {
  $$SyncStatesTableTableManager(_$LocalSyncDatabase db, $SyncStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalSyncDatabase,
      $SyncStatesTable,
      DriftSyncState,
      $$SyncStatesTableFilterComposer,
      $$SyncStatesTableOrderingComposer,
      $$SyncStatesTableAnnotationComposer,
      $$SyncStatesTableCreateCompanionBuilder,
      $$SyncStatesTableUpdateCompanionBuilder,
      (
        DriftSyncState,
        BaseReferences<_$LocalSyncDatabase, $SyncStatesTable, DriftSyncState>,
      ),
      DriftSyncState,
      PrefetchHooks Function()
    >;
typedef $$TripTemplatesTableCreateCompanionBuilder =
    TripTemplatesCompanion Function({
      required String id,
      Value<int?> routeId,
      required String origin,
      required String destination,
      required double baseFare,
      required String waypoints,
      required String waypointPrices,
      required String waypointIds,
      required int savedAt,
      Value<bool> isReversed,
      Value<int> rowid,
    });
typedef $$TripTemplatesTableUpdateCompanionBuilder =
    TripTemplatesCompanion Function({
      Value<String> id,
      Value<int?> routeId,
      Value<String> origin,
      Value<String> destination,
      Value<double> baseFare,
      Value<String> waypoints,
      Value<String> waypointPrices,
      Value<String> waypointIds,
      Value<int> savedAt,
      Value<bool> isReversed,
      Value<int> rowid,
    });

class $$TripTemplatesTableFilterComposer
    extends Composer<_$LocalSyncDatabase, $TripTemplatesTable> {
  $$TripTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get routeId => $composableBuilder(
    column: $table.routeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get destination => $composableBuilder(
    column: $table.destination,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get baseFare => $composableBuilder(
    column: $table.baseFare,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get waypoints => $composableBuilder(
    column: $table.waypoints,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get waypointPrices => $composableBuilder(
    column: $table.waypointPrices,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get waypointIds => $composableBuilder(
    column: $table.waypointIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isReversed => $composableBuilder(
    column: $table.isReversed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TripTemplatesTableOrderingComposer
    extends Composer<_$LocalSyncDatabase, $TripTemplatesTable> {
  $$TripTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get routeId => $composableBuilder(
    column: $table.routeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get destination => $composableBuilder(
    column: $table.destination,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get baseFare => $composableBuilder(
    column: $table.baseFare,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get waypoints => $composableBuilder(
    column: $table.waypoints,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get waypointPrices => $composableBuilder(
    column: $table.waypointPrices,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get waypointIds => $composableBuilder(
    column: $table.waypointIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isReversed => $composableBuilder(
    column: $table.isReversed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TripTemplatesTableAnnotationComposer
    extends Composer<_$LocalSyncDatabase, $TripTemplatesTable> {
  $$TripTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get routeId =>
      $composableBuilder(column: $table.routeId, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get destination => $composableBuilder(
    column: $table.destination,
    builder: (column) => column,
  );

  GeneratedColumn<double> get baseFare =>
      $composableBuilder(column: $table.baseFare, builder: (column) => column);

  GeneratedColumn<String> get waypoints =>
      $composableBuilder(column: $table.waypoints, builder: (column) => column);

  GeneratedColumn<String> get waypointPrices => $composableBuilder(
    column: $table.waypointPrices,
    builder: (column) => column,
  );

  GeneratedColumn<String> get waypointIds => $composableBuilder(
    column: $table.waypointIds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);

  GeneratedColumn<bool> get isReversed => $composableBuilder(
    column: $table.isReversed,
    builder: (column) => column,
  );
}

class $$TripTemplatesTableTableManager
    extends
        RootTableManager<
          _$LocalSyncDatabase,
          $TripTemplatesTable,
          DriftTripTemplate,
          $$TripTemplatesTableFilterComposer,
          $$TripTemplatesTableOrderingComposer,
          $$TripTemplatesTableAnnotationComposer,
          $$TripTemplatesTableCreateCompanionBuilder,
          $$TripTemplatesTableUpdateCompanionBuilder,
          (
            DriftTripTemplate,
            BaseReferences<
              _$LocalSyncDatabase,
              $TripTemplatesTable,
              DriftTripTemplate
            >,
          ),
          DriftTripTemplate,
          PrefetchHooks Function()
        > {
  $$TripTemplatesTableTableManager(
    _$LocalSyncDatabase db,
    $TripTemplatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripTemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripTemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> routeId = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<String> destination = const Value.absent(),
                Value<double> baseFare = const Value.absent(),
                Value<String> waypoints = const Value.absent(),
                Value<String> waypointPrices = const Value.absent(),
                Value<String> waypointIds = const Value.absent(),
                Value<int> savedAt = const Value.absent(),
                Value<bool> isReversed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripTemplatesCompanion(
                id: id,
                routeId: routeId,
                origin: origin,
                destination: destination,
                baseFare: baseFare,
                waypoints: waypoints,
                waypointPrices: waypointPrices,
                waypointIds: waypointIds,
                savedAt: savedAt,
                isReversed: isReversed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> routeId = const Value.absent(),
                required String origin,
                required String destination,
                required double baseFare,
                required String waypoints,
                required String waypointPrices,
                required String waypointIds,
                required int savedAt,
                Value<bool> isReversed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripTemplatesCompanion.insert(
                id: id,
                routeId: routeId,
                origin: origin,
                destination: destination,
                baseFare: baseFare,
                waypoints: waypoints,
                waypointPrices: waypointPrices,
                waypointIds: waypointIds,
                savedAt: savedAt,
                isReversed: isReversed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TripTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalSyncDatabase,
      $TripTemplatesTable,
      DriftTripTemplate,
      $$TripTemplatesTableFilterComposer,
      $$TripTemplatesTableOrderingComposer,
      $$TripTemplatesTableAnnotationComposer,
      $$TripTemplatesTableCreateCompanionBuilder,
      $$TripTemplatesTableUpdateCompanionBuilder,
      (
        DriftTripTemplate,
        BaseReferences<
          _$LocalSyncDatabase,
          $TripTemplatesTable,
          DriftTripTemplate
        >,
      ),
      DriftTripTemplate,
      PrefetchHooks Function()
    >;

class $LocalSyncDatabaseManager {
  final _$LocalSyncDatabase _db;
  $LocalSyncDatabaseManager(this._db);
  $$LocationsTableTableManager get locations =>
      $$LocationsTableTableManager(_db, _db.locations);
  $$RoutesTableTableManager get routes =>
      $$RoutesTableTableManager(_db, _db.routes);
  $$SyncStatesTableTableManager get syncStates =>
      $$SyncStatesTableTableManager(_db, _db.syncStates);
  $$TripTemplatesTableTableManager get tripTemplates =>
      $$TripTemplatesTableTableManager(_db, _db.tripTemplates);
}
