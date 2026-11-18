import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fleetman/auth/access_api_client.dart';
import 'package:fleetman/offices/office_models.dart';
import 'package:fleetman/offices/offices_api_client.dart';
import 'package:fleetman/sync/sync_models.dart';

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'Content-Type': 'application/json'},
  );
}

Map<String, dynamic> _officeJson() => <String, dynamic>{
  'id': 9,
  'companyId': 3,
  'companyName': 'Acme Logistics',
  'name': 'Kigali Main Office',
  'email': 'kigali@example.com',
  'companyCode': 'ACME-KIG-4F2A',
  'officeLocationId': '8c3f4b90-0b4d-4b6f-9f1e-1c0f8f2f0d41',
  'locationId': 45,
  'latitude': -1.9441,
  'longitude': 30.0444,
  'googlePlaceName': 'Kigali Downtown',
  'customName': 'Main Hub',
  'placeId': 'loc-45',
  'contactEmails': ['ops@example.com'],
  'contactPhones': ['+250700000001'],
  'createdAt': '2026-11-18T10:00:00',
};

OfficeDraft _draft() => OfficeDraft(
  name: '  Kigali Main Office  ',
  location: const LocationEntity(
    id: 45,
    latitude: -1.9441,
    longitude: 30.0444,
    googlePlaceName: 'Kigali Downtown',
    customName: 'Main Hub',
    placeId: 'loc-45',
  ),
  email: ' kigali@example.com ',
  contactEmails: const ['ops@example.com'],
  contactPhones: const ['+250700000001'],
);

void main() {
  group('OfficesApiClient', () {
    test('fetchOffices sends companyId and parses the office list', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return _json([_officeJson()]);
      });

      final items = await OfficesApiClient(httpClient: client)
          .fetchOffices('tok', companyId: 3);

      expect(captured!.method, 'GET');
      expect(captured!.url.path, '/main/offices');
      expect(captured!.url.queryParameters['companyId'], '3');
      expect(captured!.headers['Authorization'], 'Bearer tok');
      expect(items, hasLength(1));
      expect(items.single.id, 9);
      expect(items.single.name, 'Kigali Main Office');
      expect(items.single.companyName, 'Acme Logistics');
      expect(items.single.companyCode, 'ACME-KIG-4F2A');
      expect(items.single.locationLabel, 'Main Hub');
      expect(items.single.contactEmails, ['ops@example.com']);
    });

    test('createOffice posts the exact backend field names', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return _json(_officeJson());
      });

      final created = await OfficesApiClient(httpClient: client).createOffice(
        'tok',
        companyId: 3,
        draft: _draft(),
      );

      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/main/offices');
      expect(captured!.headers['Authorization'], 'Bearer tok');
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['companyId'], 3);
      expect(body['name'], 'Kigali Main Office');
      expect(body['locationId'], 45);
      expect(body['latitude'], -1.9441);
      expect(body['longitude'], 30.0444);
      expect(body['googlePlaceName'], 'Kigali Downtown');
      expect(body['customName'], 'Main Hub');
      expect(body['placeId'], 'loc-45');
      expect(body['email'], 'kigali@example.com');
      expect(body['contactEmails'], ['ops@example.com']);
      expect(body['contactPhones'], ['+250700000001']);
      // The company is never read from the draft.
      expect(body.containsKey('companyCode'), isFalse);
      expect(created.id, 9);
    });

    test('backend validation message is surfaced verbatim', () async {
      final client = MockClient((_) async => _json(
        {
          'status': 400,
          'message':
              'locationId is required when creating an office (must be selected from cavgotrips locations)',
        },
        statusCode: 400,
      ));

      await expectLater(
        OfficesApiClient(httpClient: client).createOffice(
          'tok',
          companyId: 3,
          draft: _draft(),
        ),
        throwsA(
          isA<AccessApiException>().having(
            (e) => e.message,
            'message',
            contains('locationId is required'),
          ),
        ),
      );
    });

    test('401 is surfaced as an expired session', () async {
      final client = MockClient(
        (_) async => _json({'message': 'expired'}, statusCode: 401),
      );

      await expectLater(
        OfficesApiClient(httpClient: client).fetchOffices('tok', companyId: 3),
        throwsA(isA<AccessApiUnauthorizedException>()),
      );
    });
  });
}
