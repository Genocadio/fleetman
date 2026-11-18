enum BackendVehicleStatus {
  available,
  maintenance,
  outOfService,
  occupied,
}

BackendVehicleStatus parseBackendVehicleStatus(String raw) {
  switch (raw.toUpperCase()) {
    case 'AVAILABLE':
      return BackendVehicleStatus.available;
    case 'MAINTENANCE':
      return BackendVehicleStatus.maintenance;
    case 'OUT_OF_SERVICE':
      return BackendVehicleStatus.outOfService;
    case 'OCCUPIED':
      return BackendVehicleStatus.occupied;
    default:
      return BackendVehicleStatus.available;
  }
}

String backendVehicleStatusToApiValue(BackendVehicleStatus status) {
  switch (status) {
    case BackendVehicleStatus.available:
      return 'AVAILABLE';
    case BackendVehicleStatus.maintenance:
      return 'MAINTENANCE';
    case BackendVehicleStatus.outOfService:
      return 'OUT_OF_SERVICE';
    case BackendVehicleStatus.occupied:
      return 'OCCUPIED';
  }
}

class DriverSummaryDto {
  const DriverSummaryDto({
    required this.id,
    required this.firstName,
    required this.lastName,
  });

  final int id;
  final String firstName;
  final String lastName;

  String get fullName {
    final combined = '$firstName $lastName'.trim();
    return combined;
  }

  factory DriverSummaryDto.fromJson(Map<String, dynamic> json) {
    return DriverSummaryDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
    );
  }
}

class VehicleSummaryDto {
  const VehicleSummaryDto({
    required this.id,
    required this.licensePlate,
    required this.make,
    required this.model,
    required this.vehicleType,
    required this.capacity,
    required this.status,
    required this.driver,
  });

  final int id;
  final String licensePlate;
  final String make;
  final String model;
  final String vehicleType;
  final int capacity;
  final BackendVehicleStatus status;
  final DriverSummaryDto? driver;

  factory VehicleSummaryDto.fromJson(Map<String, dynamic> json) {
    final driverRaw = json['driver'];
    return VehicleSummaryDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      licensePlate: json['licensePlate']?.toString() ?? '',
      make: json['make']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      vehicleType: json['vehicleType']?.toString() ?? '',
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      status: parseBackendVehicleStatus(json['status']?.toString() ?? ''),
      driver: driverRaw is Map<String, dynamic>
          ? DriverSummaryDto.fromJson(driverRaw)
          : (driverRaw is Map ? DriverSummaryDto.fromJson(driverRaw.cast<String, dynamic>()) : null),
    );
  }
}

class VehiclePageDto {
  const VehiclePageDto({
    required this.content,
    required this.number,
    required this.size,
    required this.totalPages,
    required this.totalElements,
    required this.last,
    required this.first,
  });

  final List<VehicleSummaryDto> content;
  final int number;
  final int size;
  final int totalPages;
  final int totalElements;
  final bool last;
  final bool first;

  factory VehiclePageDto.fromJson(Map<String, dynamic> json) {
    final contentRaw = (json['content'] as List<dynamic>? ?? const <dynamic>[])
        .map(
          (item) => VehicleSummaryDto.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
        )
        .toList();

    return VehiclePageDto(
      content: contentRaw,
      number: (json['number'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? contentRaw.length,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? contentRaw.length,
      last: json['last'] == true,
      first: json['first'] == true,
    );
  }
}

class CompanyDriverDto {
  const CompanyDriverDto({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.status,
    required this.vehicle,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String phone;
  final String status;
  final VehicleSummaryDto? vehicle;

  String get fullName {
    final combined = '$firstName $lastName'.trim();
    return combined;
  }

  factory CompanyDriverDto.fromJson(Map<String, dynamic> json) {
    final vehicleRaw = json['vehicle'];
    return CompanyDriverDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ACTIVE',
      vehicle: vehicleRaw is Map<String, dynamic>
          ? VehicleSummaryDto.fromJson(vehicleRaw)
          : (vehicleRaw is Map ? VehicleSummaryDto.fromJson(vehicleRaw.cast<String, dynamic>()) : null),
    );
  }
}

class DriverPageDto {
  const DriverPageDto({
    required this.content,
    required this.number,
    required this.size,
    required this.totalPages,
    required this.totalElements,
    required this.last,
    required this.first,
  });

  final List<CompanyDriverDto> content;
  final int number;
  final int size;
  final int totalPages;
  final int totalElements;
  final bool last;
  final bool first;

  factory DriverPageDto.fromJson(Map<String, dynamic> json) {
    final contentRaw = (json['content'] as List<dynamic>? ?? const <dynamic>[])
        .map(
          (item) => CompanyDriverDto.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
        )
        .toList();

    return DriverPageDto(
      content: contentRaw,
      number: (json['number'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? contentRaw.length,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? contentRaw.length,
      last: json['last'] == true,
      first: json['first'] == true,
    );
  }
}
