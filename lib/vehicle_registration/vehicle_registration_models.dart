/// Form and response models for `POST /main/vehicles`.
///
/// The request deliberately has no company field: the gateway resolves the
/// company from the authenticated Fleet Manager's approved membership.
enum VehicleRegistrationType {
  sedan,
  suv,
  truck,
  van,
  motorcycle,
  bus,
  minibus,
}

extension VehicleRegistrationTypeX on VehicleRegistrationType {
  String get apiValue => switch (this) {
    VehicleRegistrationType.sedan => 'SEDAN',
    VehicleRegistrationType.suv => 'SUV',
    VehicleRegistrationType.truck => 'TRUCK',
    VehicleRegistrationType.van => 'VAN',
    VehicleRegistrationType.motorcycle => 'MOTORCYCLE',
    VehicleRegistrationType.bus => 'BUS',
    VehicleRegistrationType.minibus => 'MINIBUS',
  };

  String get label => switch (this) {
    VehicleRegistrationType.sedan => 'Sedan',
    VehicleRegistrationType.suv => 'SUV',
    VehicleRegistrationType.truck => 'Truck',
    VehicleRegistrationType.van => 'Van',
    VehicleRegistrationType.motorcycle => 'Motorcycle',
    VehicleRegistrationType.bus => 'Bus',
    VehicleRegistrationType.minibus => 'Minibus',
  };
}

enum VehicleRegistrationStatus {
  available,
  maintenance,
  outOfService,
  occupied,
}

extension VehicleRegistrationStatusX on VehicleRegistrationStatus {
  String get apiValue => switch (this) {
    VehicleRegistrationStatus.available => 'AVAILABLE',
    VehicleRegistrationStatus.maintenance => 'MAINTENANCE',
    VehicleRegistrationStatus.outOfService => 'OUT_OF_SERVICE',
    VehicleRegistrationStatus.occupied => 'OCCUPIED',
  };

  String get label => switch (this) {
    VehicleRegistrationStatus.available => 'Available',
    VehicleRegistrationStatus.maintenance => 'Maintenance',
    VehicleRegistrationStatus.outOfService => 'Out of service',
    VehicleRegistrationStatus.occupied => 'Occupied',
  };
}

/// Values collected by the native registration form.
class VehicleRegistrationDraft {
  const VehicleRegistrationDraft({
    required this.make,
    required this.model,
    required this.licensePlate,
    required this.capacity,
    required this.vehicleType,
    required this.pubKey,
    this.status = VehicleRegistrationStatus.available,
  });

  final String make;
  final String model;
  final String licensePlate;
  final int capacity;
  final VehicleRegistrationType vehicleType;
  final String pubKey;
  final VehicleRegistrationStatus status;

  /// Mirrors the backend's bean validation so obvious mistakes never cause a
  /// network call. Server-only checks (duplicate plate, company scope) are
  /// still surfaced as form errors.
  String? validate() {
    if (make.trim().isEmpty) return 'Enter the vehicle make.';
    if (model.trim().isEmpty) return 'Enter the vehicle model.';
    if (licensePlate.trim().isEmpty) return 'Enter the license plate.';
    if (capacity < 1) return 'Capacity must be at least 1.';
    if (pubKey.trim().isEmpty) return 'Enter the device public key.';
    return null;
  }

  /// Exact wire body for `POST /main/vehicles`. `companyCode` must never be
  /// included; the backend infers the signed-in manager's company.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'make': make.trim(),
    'model': model.trim(),
    'pubKey': pubKey.trim(),
    'capacity': capacity,
    'licensePlate': licensePlate.trim(),
    'vehicleType': vehicleType.apiValue,
    'status': status.apiValue,
  };
}

/// The vehicle returned by a successful registration.
class RegisteredVehicle {
  const RegisteredVehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.licensePlate,
    required this.capacity,
    required this.vehicleType,
    required this.status,
    this.companyId,
    this.companyName,
    this.initialPassword,
  });

  final int id;
  final String make;
  final String model;
  final String licensePlate;
  final int capacity;
  final String vehicleType;
  final String status;
  final int? companyId;
  final String? companyName;

  /// Returned only on creation. The UI shows it once and then drops it.
  final String? initialPassword;

  factory RegisteredVehicle.fromJson(Map<String, dynamic> json) {
    return RegisteredVehicle(
      id: _int(json['id']) ?? 0,
      make: _text(json['make']) ?? '',
      model: _text(json['model']) ?? '',
      licensePlate: _text(json['licensePlate']) ?? '',
      capacity: _int(json['capacity']) ?? 0,
      vehicleType: _text(json['vehicleType']) ?? '',
      status:
          _text(json['status']) ?? VehicleRegistrationStatus.available.apiValue,
      companyId: _int(json['companyId']),
      companyName: _text(json['companyName']),
      initialPassword: _text(json['initialPassword']),
    );
  }

  factory RegisteredVehicle.fromDraft(
    VehicleRegistrationDraft draft, {
    int? companyId,
    String? companyName,
  }) {
    return RegisteredVehicle(
      id: 0,
      make: draft.make.trim(),
      model: draft.model.trim(),
      licensePlate: draft.licensePlate.trim(),
      capacity: draft.capacity,
      vehicleType: draft.vehicleType.apiValue,
      status: draft.status.apiValue,
      companyId: companyId,
      companyName: companyName,
    );
  }

  String get displayName => '$make $model'.trim();
}

int? _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}

String? _text(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
