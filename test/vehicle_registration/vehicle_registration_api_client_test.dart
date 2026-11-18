import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fleetman/auth/access_api_client.dart';
import 'package:fleetman/vehicle_registration/vehicle_registration_api_client.dart';
import 'package:fleetman/vehicle_registration/vehicle_registration_models.dart';

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'Content-Type': 'application/json'},
  );
}

Map<String, dynamic> _responseJson() => <String, dynamic>{
  'id': 11,
  'companyId': 3,
  'companyName': 'Acme Logistics',
  'make': 'Toyota',
  'model': 'Hiace',
  'licensePlate': 'RAB123X',
  'capacity': 14,
  'vehicleType': 'VAN',
  'status': 'AVAILABLE',
  'initialPassword': '482913',
};

VehicleRegistrationDraft _draft() {
  return const VehicleRegistrationDraft(
    make: '  Toyota  ',
    model: ' Hiace ',
    licensePlate: ' rab123x ',
    capacity: 14,
    vehicleType: VehicleRegistrationType.van,
    pubKey: ' key1 ',
  );
}

void main() {
  group('VehicleRegistrationApiClient', () {
    test('posts exact field names with no company field', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return _json(_responseJson());
      });

      final result = await VehicleRegistrationApiClient(
        httpClient: client,
      ).register('tok', draft: _draft());

      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/main/vehicles');
      expect(captured!.headers['Accept'], 'application/json');
      expect(captured!.headers['Content-Type'], 'application/json');
      expect(captured!.headers['Authorization'], 'Bearer tok');

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body, {
        'make': 'Toyota',
        'model': 'Hiace',
        'pubKey': 'key1',
        'capacity': 14,
        'licensePlate': 'rab123x',
        'vehicleType': 'VAN',
        'status': 'AVAILABLE',
      });
      expect(body.containsKey('companyCode'), isFalse);
      expect(body.containsKey('companyId'), isFalse);

      expect(result.id, 11);
      expect(result.companyId, 3);
      expect(result.initialPassword, '482913');
    });

    test('sends a non-default status when selected', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return _json(_responseJson()..['status'] = 'MAINTENANCE');
      });

      await VehicleRegistrationApiClient(httpClient: client).register(
        'tok',
        draft: VehicleRegistrationDraft(
          make: 'Toyota',
          model: 'Hiace',
          licensePlate: 'RAB123X',
          capacity: 14,
          vehicleType: VehicleRegistrationType.van,
          pubKey: 'key1',
          status: VehicleRegistrationStatus.maintenance,
        ),
      );

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['status'], 'MAINTENANCE');
    });

    test('validation field errors replace the generic message', () async {
      final client = MockClient(
        (_) async => _json({
          'status': 400,
          'message': 'Validation error',
          'errors': [
            {
              'field': 'capacity',
              'defaultMessage': 'Capacity must be at least 1',
            },
          ],
        }, statusCode: 400),
      );

      await expectLater(
        VehicleRegistrationApiClient(
          httpClient: client,
        ).register('tok', draft: _draft()),
        throwsA(
          isA<AccessApiException>()
              .having(
                (e) => e.message,
                'message',
                'Capacity must be at least 1',
              )
              .having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });

    test('duplicate plate messages are surfaced verbatim', () async {
      const message =
          "A vehicle with license plate 'RAB123X' already exists. Please use a different license plate.";
      final client = MockClient(
        (_) async => _json({'message': message}, statusCode: 400),
      );

      await expectLater(
        VehicleRegistrationApiClient(
          httpClient: client,
        ).register('tok', draft: _draft()),
        throwsA(
          isA<AccessApiException>().having(
            (e) => e.message,
            'message',
            message,
          ),
        ),
      );
    });

    test('401 is surfaced as an expired session', () async {
      final client = MockClient(
        (_) async => _json({'message': 'expired'}, statusCode: 401),
      );

      await expectLater(
        VehicleRegistrationApiClient(
          httpClient: client,
        ).register('tok', draft: _draft()),
        throwsA(isA<AccessApiUnauthorizedException>()),
      );
    });

    test('403 is a permission error, not an expired session', () async {
      final client = MockClient(
        (_) async =>
            _json({'message': 'Company access denied'}, statusCode: 403),
      );

      try {
        await VehicleRegistrationApiClient(
          httpClient: client,
        ).register('tok', draft: _draft());
        fail('Expected a permission error');
      } on AccessApiException catch (e) {
        expect(e, isNot(isA<AccessApiUnauthorizedException>()));
        expect(e.message, 'Company access denied');
        expect(e.statusCode, 403);
      }
    });

    test('network failures are normalised and never retried', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        throw const SocketException('Failed host lookup');
      });

      await expectLater(
        VehicleRegistrationApiClient(
          httpClient: client,
        ).register('tok', draft: _draft()),
        throwsA(
          isA<AccessApiException>().having(
            (e) => e.message,
            'message',
            contains('No internet connection'),
          ),
        ),
      );
      expect(calls, 1);
    });

    test('a bare 5xx gets a usable fallback message', () async {
      final client = MockClient((_) async => http.Response('', 503));

      await expectLater(
        VehicleRegistrationApiClient(
          httpClient: client,
        ).register('tok', draft: _draft()),
        throwsA(
          isA<AccessApiException>().having(
            (e) => e.message,
            'message',
            contains('temporarily unavailable'),
          ),
        ),
      );
    });

    test(
      'a 2xx with an empty body still succeeds without a password',
      () async {
        final client = MockClient((_) async => http.Response('', 200));

        final result = await VehicleRegistrationApiClient(
          httpClient: client,
        ).register('tok', draft: _draft());

        expect(result.licensePlate, 'rab123x');
        expect(result.initialPassword, isNull);
      },
    );
  });
}
