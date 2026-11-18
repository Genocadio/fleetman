import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fleetman/auth/access_api_client.dart';

http.Response _json(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'Content-Type': 'application/json'},
  );
}

void main() {
  group('AccessApiClient', () {
    test('sync posts to the canonical gateway with a Bearer token', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return _json({
          'user': {'id': 5, 'role': 'FLEET_MANAGER'},
          'company': {'companyId': 9, 'companyName': 'Acme'},
          'accessRequest': null,
        });
      });

      final profile = await AccessApiClient(httpClient: client)
          .fetchSyncProfile('token-123');

      expect(captured!.method, 'POST');
      expect(captured!.url.toString(),
          'https://api.gocavgo.com/main/users/sync');
      expect(captured!.headers['Authorization'], 'Bearer token-123');
      expect(profile.company?.companyId, 9);
      expect(profile.user.role, 'FLEET_MANAGER');
      expect(profile.accessRequest, isNull);
    });

    test('my-status 204 means no request', () async {
      final client = MockClient(
        (_) async => http.Response('', 204),
      );

      final result = await AccessApiClient(httpClient: client)
          .fetchMyAccessRequest('token-123');

      expect(result.found, isFalse);
      expect(result.error, isNull);
      expect(result.request, isNull);
    });

    test('my-status 200 returns the latest request', () async {
      final client = MockClient((_) async {
        return _json({
          'id': 12,
          'status': 'PENDING',
          'companyCode': 'ACME',
          'companyName': 'Acme',
        });
      });

      final result = await AccessApiClient(httpClient: client)
          .fetchMyAccessRequest('token-123');

      expect(result.found, isTrue);
      expect(result.request?.status, 'PENDING');
      expect(result.request?.companyCode, 'ACME');
    });

    test('my-status auth failure is an error, never "no request"', () async {
      final client = MockClient(
        (_) async => _json({'message': 'expired'}, statusCode: 401),
      );

      final result = await AccessApiClient(httpClient: client)
          .fetchMyAccessRequest('token-123');

      expect(result.found, isFalse);
      expect(result.request, isNull);
      expect(result.error, isNotNull);
      expect(result.error, contains('expired'));
    });

    test('access request posts the company code with a Bearer token', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return _json({
          'id': 1,
          'status': 'PENDING',
          'companyCode': 'ACME',
        });
      });

      final result = await AccessApiClient(httpClient: client)
          .requestFleetManagerAccess('token-123', ' ACME ');

      expect(captured!.method, 'POST');
      expect(captured!.url.toString(),
          'https://api.gocavgo.com/main/company-access-requests');
      expect(captured!.headers['Authorization'], 'Bearer token-123');
      expect(jsonDecode(captured!.body), {'companyCode': 'ACME'});
      expect(result.status, 'PENDING');
    });

    test('duplicate-request message from the backend is surfaced', () async {
      final client = MockClient((_) async {
        return _json({
          'message':
              'You already have a pending company access request. Please wait.',
        }, statusCode: 400);
      });

      expect(
        () => AccessApiClient(httpClient: client)
            .requestFleetManagerAccess('token-123', 'ACME'),
        throwsA(
          isA<AccessApiException>().having(
            (e) => e.message,
            'message',
            contains('already have a pending company access request'),
          ),
        ),
      );
    });
  });
}
