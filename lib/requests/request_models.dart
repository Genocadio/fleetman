/// The two request families a Fleet Manager can act on for their company.
/// Both are exposed by cavgomain with the same list/approve/reject contract.
enum CompanyRequestKind { companyAccess, driver }

extension CompanyRequestKindLabel on CompanyRequestKind {
  String get label => switch (this) {
    CompanyRequestKind.companyAccess => 'Role access',
    CompanyRequestKind.driver => 'Driver',
  };

  String get pluralLabel => switch (this) {
    CompanyRequestKind.companyAccess => 'Role access requests',
    CompanyRequestKind.driver => 'Driver requests',
  };
}

/// A request submitted by a user who wants to join the Fleet Manager's company.
///
/// The backend returns slightly different DTOs for company-access and driver
/// requests; this normalises them so one approval UI can handle both.
class CompanyRequestItem {
  const CompanyRequestItem({
    required this.id,
    required this.kind,
    required this.status,
    this.nexxauthUserId,
    this.firstName = '',
    this.lastName = '',
    this.email,
    this.phone,
    this.role,
    this.companyCode,
    this.companyId,
    this.companyName,
    this.rejectionReason,
    this.approvedBy,
    this.rejectedBy,
    this.createdAt,
  });

  final int id;
  final CompanyRequestKind kind;
  final String status;
  final int? nexxauthUserId;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;

  /// Requested role — only present on company-access requests.
  final String? role;

  final String? companyCode;
  final int? companyId;
  final String? companyName;
  final String? rejectionReason;
  final int? approvedBy;
  final int? rejectedBy;
  final String? createdAt;

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isApproved => status.toUpperCase() == 'APPROVED';
  bool get isRejected => status.toUpperCase() == 'REJECTED';

  String get fullName {
    final name = [firstName, lastName]
        .where((part) => part.trim().isNotEmpty)
        .join(' ')
        .trim();
    if (name.isNotEmpty) return name;
    if (email != null && email!.isNotEmpty) return email!;
    if (phone != null && phone!.isNotEmpty) return phone!;
    return 'User ${nexxauthUserId ?? id}';
  }

  String get contact {
    final value = email ?? phone;
    return (value == null || value.isEmpty) ? 'No contact details' : value;
  }

  String get statusLabel => switch (status.toUpperCase()) {
    'PENDING' => 'Pending',
    'APPROVED' => 'Approved',
    'REJECTED' => 'Rejected',
    _ => status,
  };

  factory CompanyRequestItem.fromAccessJson(Map<String, dynamic> json) {
    return CompanyRequestItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      kind: CompanyRequestKind.companyAccess,
      nexxauthUserId: (json['nexxauthUserId'] as num?)?.toInt(),
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String?,
      companyCode: json['companyCode'] as String?,
      companyId: (json['companyId'] as num?)?.toInt(),
      companyName: json['companyName'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      rejectionReason: json['rejectionReason'] as String?,
      approvedBy: (json['approvedBy'] as num?)?.toInt(),
      rejectedBy: (json['rejectedBy'] as num?)?.toInt(),
      createdAt: json['createdAt'] as String?,
    );
  }

  factory CompanyRequestItem.fromDriverJson(Map<String, dynamic> json) {
    return CompanyRequestItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      kind: CompanyRequestKind.driver,
      nexxauthUserId: (json['nexxauthUserId'] as num?)?.toInt(),
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      role: 'DRIVER',
      companyCode: json['companyCode'] as String?,
      companyId: (json['companyId'] as num?)?.toInt(),
      companyName: json['companyName'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      rejectionReason: json['rejectionReason'] as String?,
      approvedBy: (json['approvedBy'] as num?)?.toInt(),
      rejectedBy: (json['rejectedBy'] as num?)?.toInt(),
      createdAt: json['createdAt'] as String?,
    );
  }
}
