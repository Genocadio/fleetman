import '../sync/sync_models.dart';

/// An office returned by `GET /main/offices?companyId=...`.
///
/// The backend models an office as a `Company` subclass: [companyName] is the
/// parent company, while [name] is the office's own name and [companyCode] is
/// the generated office code.
class OfficeItem {
  const OfficeItem({
    required this.id,
    this.companyId,
    this.companyName,
    this.name = '',
    this.email,
    this.phone,
    this.address,
    this.city,
    this.companyCode,
    this.officeLocationId,
    this.locationId,
    this.latitude,
    this.longitude,
    this.googlePlaceName,
    this.customName,
    this.placeId,
    this.contactEmails = const <String>[],
    this.contactPhones = const <String>[],
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int? companyId;
  final String? companyName;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String? city;

  /// Generated office code (not the parent company's code).
  final String? companyCode;
  final String? officeLocationId;
  final int? locationId;
  final double? latitude;
  final double? longitude;
  final String? googlePlaceName;
  final String? customName;
  final String? placeId;
  final List<String> contactEmails;
  final List<String> contactPhones;
  final String? createdAt;
  final String? updatedAt;

  String get locationLabel {
    final custom = customName?.trim() ?? '';
    if (custom.isNotEmpty) return custom;
    final google = googlePlaceName?.trim() ?? '';
    if (google.isNotEmpty) return google;
    if (locationId != null) return 'Location #$locationId';
    return 'No location';
  }

  String get contactLabel {
    final values = <String>[
      if (email != null && email!.trim().isNotEmpty) email!.trim(),
      if (phone != null && phone!.trim().isNotEmpty) phone!.trim(),
      if (address != null && address!.trim().isNotEmpty) address!.trim(),
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
    ];
    return values.join(' · ');
  }

  factory OfficeItem.fromJson(Map<String, dynamic> json) {
    return OfficeItem(
      id: _int(json['id']) ?? 0,
      companyId: _int(json['companyId']),
      companyName: _text(json['companyName']),
      name: _text(json['name']) ?? '',
      email: _text(json['email']),
      phone: _text(json['phone']),
      address: _text(json['address']),
      city: _text(json['city']),
      companyCode: _text(json['companyCode']),
      officeLocationId: _text(json['officeLocationId']),
      locationId: _int(json['locationId']),
      latitude: _double(json['latitude']),
      longitude: _double(json['longitude']),
      googlePlaceName: _text(json['googlePlaceName']),
      customName: _text(json['customName']),
      placeId: _text(json['placeId']),
      contactEmails: _stringList(json['contactEmails']),
      contactPhones: _stringList(json['contactPhones']),
      createdAt: _text(json['createdAt']),
      updatedAt: _text(json['updatedAt']),
    );
  }
}

/// Form values for a new office. No company is selected here on purpose: the
/// controller always injects the signed-in manager's company id from the
/// session before calling the backend.
class OfficeDraft {
  const OfficeDraft({
    required this.name,
    required this.location,
    this.email,
    this.phone,
    this.address,
    this.city,
    this.contactEmails = const <String>[],
    this.contactPhones = const <String>[],
  });

  final String name;
  final LocationEntity location;
  final String? email;
  final String? phone;
  final String? address;
  final String? city;
  final List<String> contactEmails;
  final List<String> contactPhones;

  Map<String, dynamic> toJson({required int companyId}) {
    return <String, dynamic>{
      'companyId': companyId,
      'name': name.trim(),
      'locationId': location.id,
      if (location.latitude != null) 'latitude': location.latitude,
      if (location.longitude != null) 'longitude': location.longitude,
      if (location.googlePlaceName != null)
        'googlePlaceName': location.googlePlaceName,
      if (location.customName != null) 'customName': location.customName,
      if (location.placeId != null) 'placeId': location.placeId,
      if (email != null && email!.trim().isNotEmpty) 'email': email!.trim(),
      if (phone != null && phone!.trim().isNotEmpty) 'phone': phone!.trim(),
      if (address != null && address!.trim().isNotEmpty)
        'address': address!.trim(),
      if (city != null && city!.trim().isNotEmpty) 'city': city!.trim(),
      'contactEmails': contactEmails,
      'contactPhones': contactPhones,
    };
  }
}

int? _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '');
}

double? _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().trim() ?? '');
}

String? _text(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const <String>[];
  return value
      .map((e) => e?.toString().trim() ?? '')
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
}
