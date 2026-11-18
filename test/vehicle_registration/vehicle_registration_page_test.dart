import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleetman/auth/access_api_client.dart';
import 'package:fleetman/auth/auth_models.dart';
import 'package:fleetman/auth/credentials_manager.dart';
import 'package:fleetman/vehicle_registration/vehicle_registration_api_client.dart';
import 'package:fleetman/vehicle_registration/vehicle_registration_controller.dart';
import 'package:fleetman/vehicle_registration/vehicle_registration_models.dart';
import 'package:fleetman/vehicle_registration/vehicle_registration_page.dart';

class FakeRegistrationApi implements VehicleRegistrationApi {
  Object? error;
  Future<void>? gate;
  int calls = 0;
  VehicleRegistrationDraft? draft;

  @override
  Future<RegisteredVehicle> register(
    String accessToken, {
    required VehicleRegistrationDraft draft,
  }) async {
    calls++;
    this.draft = draft;
    if (gate != null) await gate;
    if (error != null) throw error!;
    return RegisteredVehicle(
      id: 11,
      companyId: 3,
      companyName: 'Acme Logistics',
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
  @override
  Future<String?> getAccessToken() async => 'tok';

  @override
  Future<int?> getCompanyId() async => 3;

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
  Future<void> signOut() async {}
}

Future<void> _fillValidForm(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('vehicle-make-field')), 'Toyota');
  await tester.enterText(find.byKey(const Key('vehicle-model-field')), 'Hiace');
  await tester.enterText(
    find.byKey(const Key('vehicle-plate-field')),
    'RAB123X',
  );
  await tester.enterText(find.byKey(const Key('vehicle-capacity-field')), '14');
  await tester.enterText(find.byKey(const Key('vehicle-pubkey-field')), 'key1');
  await tester.tap(find.byKey(const Key('vehicle-type-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Van').last);
  await tester.pumpAndSettle();
}

Future<void> _tapRegister(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('register-vehicle-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('register-vehicle-button')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('registration form validates before any network call', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = FakeRegistrationApi();
    final controller = VehicleRegistrationController(
      api: api,
      credentials: FakeSession(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: VehicleRegistrationPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(FilledButton, 'Register Vehicle'),
      findsOneWidget,
    );
    expect(find.text('Vehicle registration'), findsOneWidget);
    expect(find.text('Registered under your company'), findsOneWidget);

    await _tapRegister(tester);
    expect(find.text('Enter the vehicle make.'), findsOneWidget);
    expect(api.calls, 0);
  });

  testWidgets('successful registration shows the password once', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = FakeRegistrationApi();
    final controller = VehicleRegistrationController(
      api: api,
      credentials: FakeSession(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: VehicleRegistrationPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    await _fillValidForm(tester);
    await _tapRegister(tester);

    expect(api.calls, 1);
    expect(api.draft!.make, 'Toyota');
    expect(api.draft!.vehicleType, VehicleRegistrationType.van);
    expect(api.draft!.status, VehicleRegistrationStatus.available);

    expect(find.text('Vehicle registered'), findsOneWidget);
    expect(find.byKey(const Key('initial-password-text')), findsOneWidget);
    expect(find.text('482913'), findsOneWidget);
    expect(
      find.text('Shown only once. Copy it before closing this screen.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);
  });

  testWidgets('backend errors are shown with dismiss, not retry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const error =
        "A vehicle with license plate 'RAB123X' already exists. Please use a different license plate.";
    final api = FakeRegistrationApi()
      ..error = AccessApiException(error, statusCode: 400);
    final controller = VehicleRegistrationController(
      api: api,
      credentials: FakeSession(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: VehicleRegistrationPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    await _fillValidForm(tester);
    await _tapRegister(tester);

    expect(find.text(error), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(api.calls, 1);

    await tester.tap(find.widgetWithText(TextButton, 'Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text(error), findsNothing);
    expect(api.calls, 1);
  });

  testWidgets('shows an action-specific loading state while submitting', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gate = Completer<void>();
    final api = FakeRegistrationApi()..gate = gate.future;
    final controller = VehicleRegistrationController(
      api: api,
      credentials: FakeSession(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: VehicleRegistrationPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    await _fillValidForm(tester);
    await tester.tap(find.byKey(const Key('register-vehicle-button')));
    await tester.pump();

    expect(find.text('Registering vehicle…'), findsOneWidget);
    expect(find.byKey(const Key('register-vehicle-button')), findsOneWidget);
    expect(api.calls, 1);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Vehicle registered'), findsOneWidget);
  });
}
