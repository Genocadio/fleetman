import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fleetman/trips/trip_api_client.dart';
import 'package:fleetman/vehicles/vehicle_api_client.dart';

void main() {
  group('401 recovery', () {
    test('vehicle client refreshes once and retries with the new token',
        () async {
      final authHeaders = <String?>[];
      var calls = 0;
      final client = MockClient((request) async {
        authHeaders.add(request.headers['Authorization']);
        calls++;
        if (calls == 1) return http.Response('unauthorized', 401);
        return http.Response('', 200);
      });

      final api = VehicleApiClient(
        httpClient: client,
        onUnauthorized: () async => 'fresh-token',
      );
      await api.assignDriverToVehicle(
        vehicleId: 1,
        driverId: 2,
        accessToken: 'stale-token',
      );

      expect(calls, 2);
      expect(authHeaders, [
        'Bearer stale-token',
        'Bearer fresh-token',
      ]);
    });

    test('vehicle client does not retry when the session cannot be recovered',
        () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('unauthorized', 401);
      });

      final api = VehicleApiClient(
        httpClient: client,
        onUnauthorized: () async => null,
      );

      await expectLater(
        api.assignDriverToVehicle(
          vehicleId: 1,
          driverId: 2,
          accessToken: 'stale-token',
        ),
        throwsA(isA<VehicleApiException>()),
      );
      expect(calls, 1);
    });

    test('trip client retries a 401 with the refreshed token', () async {
      final authHeaders = <String?>[];
      var calls = 0;
      final client = MockClient((request) async {
        authHeaders.add(request.headers['Authorization']);
        calls++;
        if (calls == 1) return http.Response('unauthorized', 401);
        return http.Response('{}', 200);
      });

      final api = TripApiClient(
        httpClient: client,
        onUnauthorized: () async => 'fresh-token',
      );
      final result = await api.deleteTripById(
        tripId: 9,
        accessToken: 'stale-token',
      );

      expect(result, isA<RemoteResultSuccess<void>>());
      expect(calls, 2);
      expect(authHeaders, [
        'Bearer stale-token',
        'Bearer fresh-token',
      ]);
    });
  });
}
