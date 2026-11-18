import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fleetman/auth/access_api_client.dart';
import 'package:fleetman/requests/company_requests_api_client.dart';
import 'package:fleetman/requests/request_models.dart';

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'Content-Type': 'application/json'},
  );
}

Map<String, dynamic> _access({
  required int id,
  required String status,
  String createdAt = '2026-01-01T10:00:00',
}) =>
    {
      'id': id,
      'nexxauthUserId': 100 + id,
      'firstName': 'Ada',
      'lastName': 'Nexx',
      'email': 'ada$id@example.com',
      'role': 'FLEET_MANAGER',
      'companyId': 3,
      'companyCode': 'ACME',
      'companyName': 'Acme',
      'status': status,
      'createdAt': createdAt,
    };

Map<String, dynamic> _driver({
  required int id,
  required String status,
  String createdAt = '2026-01-02T10:00:00',
}) =>
    {
      'id': id,
      'nexxauthUserId': 200 + id,
      'firstName': 'Kevin',
      'lastName': 'Driver',
      'phone': '+25078800000$id',
      'companyId': 3,
      'companyCode': 'ACME',
      'status': status,
      'createdAt': createdAt,
    };

void main() {
  group('CompanyRequestsApiClient', () {
    test('combines both queues, newest first', () async {
      final paths = <String>[];
      final client = MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path.contains('company-access-requests')) {
          return _json([_access(id: 1, status: 'PENDING')]);
        }
        return _json([_driver(id: 2, status: 'PENDING')]);
      });

      final items = await CompanyRequestsApiClient(httpClient: client)
          .fetchRequests('tok', companyId: 3);

      expect(paths, [
        '/main/company-access-requests/company/3',
        '/main/driver-requests/company/3',
      ]);
      expect(items.map((e) => e.kind), [
        CompanyRequestKind.driver,
        CompanyRequestKind.companyAccess,
      ]);
      expect(items.first.kind.label, 'Driver');
      expect(items.last.fullName, 'Ada Nexx');
    });

    test('pendingOnly calls the pending endpoints', () async {
      final paths = <String>[];
      final client = MockClient((request) async {
        paths.add(request.url.path);
        return _json(<dynamic>[]);
      });

      await CompanyRequestsApiClient(httpClient: client)
          .fetchRequests('tok', companyId: 7, pendingOnly: true);

      expect(paths, [
        '/main/company-access-requests/company/7/pending',
        '/main/driver-requests/company/7/pending',
      ]);
    });

    test('driver queue failure does not hide role access requests', () async {
      final client = MockClient((request) async {
        if (request.url.path.contains('company-access-requests')) {
          return _json([_access(id: 4, status: 'PENDING')]);
        }
        return _json({'message': 'driver queue unavailable'}, statusCode: 500);
      });

      final items = await CompanyRequestsApiClient(httpClient: client)
          .fetchRequests('tok', companyId: 3);

      expect(items.length, 1);
      expect(items.single.kind, CompanyRequestKind.companyAccess);
    });

    test('approve posts to the right endpoint for each request kind', () async {
      final paths = <String>[];
      final client = MockClient((request) async {
        paths.add(request.url.path);
        return _json(_access(id: 1, status: 'APPROVED'));
      });
      final api = CompanyRequestsApiClient(httpClient: client);

      await api.approve('tok', CompanyRequestItem.fromAccessJson(
        _access(id: 1, status: 'PENDING'),
      ));
      await api.approve('tok', CompanyRequestItem.fromDriverJson(
        _driver(id: 2, status: 'PENDING'),
      ));

      expect(paths, [
        '/main/company-access-requests/1/approve',
        '/main/driver-requests/2/approve',
      ]);
    });

    test('reject sends the reason in the body', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return _json(_access(id: 1, status: 'REJECTED'));
      });
      final item = CompanyRequestItem.fromAccessJson(
        _access(id: 1, status: 'PENDING'),
      );

      await CompanyRequestsApiClient(httpClient: client)
          .reject('tok', item, reason: ' Not in our company ');

      expect(captured!.url.path, '/main/company-access-requests/1/reject');
      expect(jsonDecode(captured!.body), {'reason': 'Not in our company'});
    });

    test('401 is surfaced as an expired session', () async {
      final client = MockClient(
        (_) async => _json({'message': 'expired'}, statusCode: 401),
      );

      await expectLater(
        CompanyRequestsApiClient(httpClient: client)
            .fetchRequests('tok', companyId: 3),
        throwsA(isA<AccessApiUnauthorizedException>()),
      );
    });
  });
}
