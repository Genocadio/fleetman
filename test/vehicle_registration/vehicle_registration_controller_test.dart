import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fleetman/auth/access_api_client.dart';
import 'package:fleetman/auth/auth_models.dart';
import 'package:fleetman/auth/credentials_manager.dart';
import 'package:fleetman/vehicle_registration/vehicle_registration_api_client.dart';
import 'package:fleetman/vehicle_registration/vehicle_registration_controller.dart';
import 'package:fleetman/vehicle_registration/vehicle_registration_models.dart';

VehicleRegistrationDraft _draft() {
  return const VehicleRegistrationDraft(
    make: 'Toyota',
    model: 'Hiace',
    licensePlate: 'RAB123X',
    capacity: 14,
    vehicleType: VehicleRegistrationType.van,
    pubKey: 'key1',
  );
}

class FakeRegistrationApi implements VehicleRegistrationApi {
  Object? error;
  Future<void>? gate;
  int calls = 0;
  String? token;
  VehicleRegistrationDraft? draft;

  @override
  Future<RegisteredVehicle> register(
    String accessToken, {
    required VehicleRegistrationDraft draft,
  }) async {
    calls++;
    token = accessToken;
    this.draft = draft;
    if (gate != null) await gate;
    if (error != null) throw error!;
    return RegisteredVehicle(
      id: 11,
      companyId: 3,
      make: draft.make,
      model: draft.model,
      licensePlate: draft.licensePlate,
      capacity: draft.capacity,
      vehicleType: draft.vehicleType.apiValue,
      status: draft.status.apiValue,
      initialPassword: '482913',
    );
  }
}

class FakeSession implements FleetCredentials {
  String? token = 'tok';
  int? companyId = 3;
  int signOutCalls = 0;

  @override
  Future<String?> getAccessToken() async => token;

  @override
  Future<int?> getCompanyId() async => companyId;

  @override
  Future<void> saveSyncProfile(SyncProfileDto profile) async {}

  @override
  Future<bool> hasFleetManagerRole() async => true;

  @override
  Future<List<String>> getNexxauthRoles() async => ['fleet_manager'];

  @override
  Future<String?> getBackendRole() async => 'FLEET_MANAGER';

  @override
  Future<String?> getRefreshToken() async => 'refresh';

  @override
  Future<bool> refreshNow() async => true;

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

void main() {
  late FakeRegistrationApi api;
  late FakeSession session;
  late VehicleRegistrationController controller;

  setUp(() {
    api = FakeRegistrationApi();
    session = FakeSession();
    controller = VehicleRegistrationController(api: api, credentials: session);
    addTearDown(controller.dispose);
  });

  test(
    'success stores the created vehicle and the one-time password',
    () async {
      final ok = await controller.register(_draft());

      expect(ok, isTrue);
      expect(api.calls, 1);
      expect(api.token, 'tok');
      expect(api.draft!.vehicleType, VehicleRegistrationType.van);
      expect(controller.created!.id, 11);
      expect(controller.created!.initialPassword, '482913');
      expect(controller.isCreating, isFalse);
      expect(controller.error, isNull);
    },
  );

  test('a missing company session blocks the call', () async {
    session.companyId = null;

    final ok = await controller.register(_draft());

    expect(ok, isFalse);
    expect(api.calls, 0);
    expect(controller.error, contains('company session'));
    expect(controller.isCreating, isFalse);
  });

  test('local validation blocks an invalid draft', () async {
    final ok = await controller.register(
      const VehicleRegistrationDraft(
        make: '',
        model: 'Hiace',
        licensePlate: 'RAB123X',
        capacity: 14,
        vehicleType: VehicleRegistrationType.van,
        pubKey: 'key1',
      ),
    );

    expect(ok, isFalse);
    expect(api.calls, 0);
    expect(controller.error, 'Enter the vehicle make.');
  });

  test('a backend error is surfaced once with no implicit retry', () async {
    api.error = AccessApiException(
      "A vehicle with license plate 'RAB123X' already exists. Please use a different license plate.",
      statusCode: 400,
    );

    final ok = await controller.register(_draft());

    expect(ok, isFalse);
    expect(api.calls, 1);
    expect(controller.error, contains('already exists'));
    expect(controller.created, isNull);
    expect(controller.isCreating, isFalse);
  });

  test('403 does not sign the manager out', () async {
    api.error = AccessApiException('Company access denied', statusCode: 403);

    final ok = await controller.register(_draft());

    expect(ok, isFalse);
    expect(controller.error, 'Company access denied');
    expect(session.signOutCalls, 0);
  });

  test('401 signs the manager out', () async {
    api.error = const AccessApiUnauthorizedException();

    final ok = await controller.register(_draft());

    expect(ok, isFalse);
    expect(controller.error, contains('expired'));
    expect(session.signOutCalls, 1);
    expect(controller.isCreating, isFalse);
  });

  test('loading state is exposed while a registration is in flight', () async {
    final gate = Completer<void>();
    api.gate = gate.future;

    final pending = controller.register(_draft());
    await Future<void>.delayed(Duration.zero);

    expect(controller.isCreating, isTrue);
    expect(await controller.register(_draft()), isFalse);
    expect(api.calls, 1);

    gate.complete();
    await pending;
    expect(controller.isCreating, isFalse);
    expect(controller.created, isNotNull);
  });

  test('unexpected errors become readable messages', () async {
    api.error = const HttpExceptionLike('socket closed');

    final ok = await controller.register(_draft());

    expect(ok, isFalse);
    expect(controller.error, contains('socket closed'));
    expect(controller.isCreating, isFalse);
  });

  test('dismissing an error clears the banner', () async {
    api.error = AccessApiException('Permission denied', statusCode: 403);

    await controller.register(_draft());
    expect(controller.error, 'Permission denied');

    controller.dismissError();
    expect(controller.error, isNull);
  });
}

class HttpExceptionLike implements Exception {
  const HttpExceptionLike(this.message);
  final String message;
  @override
  String toString() => 'Exception: $message';
}
