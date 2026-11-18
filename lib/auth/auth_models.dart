/// Nexxauth role names, matched case-insensitively by the backend
/// (see cavgomain NexxauthRoles).
const String kFleetManagerRole = 'fleet_manager';
const String kSupervisorRole = 'supervisor';
const String kAdminRole = 'admin';
const String kDriverRole = 'driver';
const String kWorkerRole = 'worker';

const Set<String> kStaffRoles = {
  kFleetManagerRole,
  kSupervisorRole,
  kAdminRole,
};

String? detectIdentifierType(String identifier) {
  final value = identifier.trim();
  if (value.contains('@')) return 'EMAIL';
  final normalized = value
      .replaceAll(RegExp(r'[\s()\-]'), '')
      .replaceFirst(RegExp(r'^\+'), '');
  if (normalized.isNotEmpty && RegExp(r'^\d+$').hasMatch(normalized)) {
    return 'PHONE';
  }
  // Let Nexxauth try username -> email -> phone when it cannot be determined.
  return null;
}

class LoginRequestDto {
  const LoginRequestDto({
    required this.identifier,
    required this.password,
    this.identifierType,
    this.authType = 'PASSWORD',
  });

  final String identifier;
  final String password;
  final String? identifierType;
  final String authType;

  factory LoginRequestDto.fromInput(String identifier, String password) {
    return LoginRequestDto(
      identifier: identifier.trim(),
      password: password,
      identifierType: detectIdentifierType(identifier),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'identifier': identifier,
      if (identifierType != null) 'identifierType': identifierType,
      'authType': authType,
      'password': password,
    };
  }
}

class NexxAuthUser {
  const NexxAuthUser({
    required this.id,
    required this.firstName,
    this.lastName,
    this.username,
    this.email,
    this.phone,
    required this.enabled,
    required this.roles,
    required this.authTypes,
    this.createdAt,
  });

  final int id;
  final String firstName;
  final String? lastName;
  final String? username;
  final String? email;
  final String? phone;
  final bool enabled;
  final List<String> roles;
  final List<String> authTypes;
  final String? createdAt;

  String get displayName {
    final full = [firstName, lastName].where((p) => p != null && p.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;
    if (username != null && username!.isNotEmpty) return username!;
    return email ?? phone ?? 'User $id';
  }

  bool hasRole(String role) =>
      roles.any((r) => r.toLowerCase() == role.toLowerCase());

  factory NexxAuthUser.fromJson(Map<String, dynamic> json) {
    return NexxAuthUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String?,
      username: json['username'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      enabled: json['enabled'] as bool? ?? false,
      roles: (json['roles'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      authTypes: (json['authTypes'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      createdAt: json['createdAt'] as String?,
    );
  }
}

class NexxAuthResponse {
  const NexxAuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresInSeconds,
    required this.user,
    required this.actions,
  });

  final String accessToken;
  final String? refreshToken;
  final String tokenType;
  final int expiresInSeconds;
  final NexxAuthUser user;
  final List<String> actions;

  /// Unix seconds at which the access token expires.
  int get expiresAt =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 + expiresInSeconds;

  factory NexxAuthResponse.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    if (userJson is! Map<String, dynamic>) {
      throw const FormatException('Nexxauth response has no user object');
    }
    return NexxAuthResponse(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String?,
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      expiresInSeconds: (json['expiresInSeconds'] as num?)?.toInt() ?? 0,
      user: NexxAuthUser.fromJson(userJson),
      actions: (json['actions'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class NexxAuthRefreshResponse {
  const NexxAuthRefreshResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresInSeconds,
    this.user,
  });

  final String accessToken;
  final String? refreshToken;
  final int expiresInSeconds;

  /// Present on some Nexxauth refresh responses; used to refresh cached roles.
  final NexxAuthUser? user;

  factory NexxAuthRefreshResponse.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    return NexxAuthRefreshResponse(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String?,
      expiresInSeconds: (json['expiresInSeconds'] as num?)?.toInt() ?? 0,
      user: userJson is Map<String, dynamic>
          ? NexxAuthUser.fromJson(userJson)
          : null,
    );
  }
}

/// Profile/company/access-request context returned by POST /main/users/sync.
class SyncProfileDto {
  const SyncProfileDto({
    required this.user,
    this.company,
    this.accessRequest,
  });

  final SyncUserDto user;
  final CompanyContextDto? company;
  final AccessRequestDto? accessRequest;

  factory SyncProfileDto.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    final companyJson = json['company'];
    final requestJson = json['accessRequest'];
    return SyncProfileDto(
      user: userJson is Map<String, dynamic>
          ? SyncUserDto.fromJson(userJson)
          : const SyncUserDto(),
      company: companyJson is Map<String, dynamic>
          ? CompanyContextDto.fromJson(companyJson)
          : null,
      accessRequest: requestJson is Map<String, dynamic>
          ? AccessRequestDto.fromJson(requestJson)
          : null,
    );
  }
}

class SyncUserDto {
  const SyncUserDto({
    this.id,
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.status,
    this.role,
  });

  final int? id;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? status;
  final String? role;

  bool get isFleetManager =>
      role != null && role!.toUpperCase() == 'FLEET_MANAGER';

  factory SyncUserDto.fromJson(Map<String, dynamic> json) {
    return SyncUserDto(
      id: (json['id'] as num?)?.toInt(),
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      status: json['status'] as String?,
      role: json['role'] as String?,
    );
  }
}

class CompanyContextDto {
  const CompanyContextDto({
    required this.companyId,
    this.companyName,
    this.companyCode,
  });

  final int companyId;
  final String? companyName;
  final String? companyCode;

  factory CompanyContextDto.fromJson(Map<String, dynamic> json) {
    return CompanyContextDto(
      companyId: (json['companyId'] as num?)?.toInt() ?? 0,
      companyName: json['companyName'] as String?,
      companyCode: json['companyCode'] as String?,
    );
  }
}

class AccessRequestDto {
  const AccessRequestDto({
    required this.id,
    required this.status,
    this.companyCode,
    this.companyId,
    this.companyName,
    this.rejectionReason,
  });

  final int id;
  final String status;
  final String? companyCode;
  final int? companyId;
  final String? companyName;
  final String? rejectionReason;

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isApproved => status.toUpperCase() == 'APPROVED';
  bool get isRejected => status.toUpperCase() == 'REJECTED';

  factory AccessRequestDto.fromJson(Map<String, dynamic> json) {
    return AccessRequestDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'PENDING',
      companyCode: json['companyCode'] as String?,
      companyId: (json['companyId'] as num?)?.toInt(),
      companyName: json['companyName'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
    );
  }
}
