import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleetman/auth/auth_models.dart';
import 'package:fleetman/auth/credentials_manager.dart';
import 'package:fleetman/offices/office_models.dart';
import 'package:fleetman/offices/offices_api_client.dart';
import 'package:fleetman/offices/offices_controller.dart';
import 'package:fleetman/offices/offices_page.dart';
import 'package:fleetman/sync/sync_models.dart';

class FakeOfficesApi implements OfficesApi {
  final List<OfficeItem> offices = [
    OfficeItem(
      id: 1,
      companyId: 3,
      name: 'Kigali Main Office',
      companyCode: 'ACME-KIG',
      googlePlaceName: 'Kigali Downtown',
      email: 'kigali@example.com',
    ),
  ];
  int createCalls = 0;
  OfficeDraft? lastDraft;

  @override
  Future<List<OfficeItem>> fetchOffices(
    String token, {
    required int companyId,
  }) async =>
      offices;

  @override
  Future<OfficeItem> createOffice(
    String token, {
    required int companyId,
    required OfficeDraft draft,
  }) async {
    createCalls++;
    lastDraft = draft;
    return OfficeItem(id: 2, companyId: companyId, name: draft.name);
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

class FakeLocations implements OfficeLocationLookup {
  @override
  Future<List<LocationEntity>> search(String query) async => [
    const LocationEntity(
      id: 45,
      latitude: -1.9441,
      longitude: 30.0444,
      googlePlaceName: 'Kigali Downtown',
      placeId: 'loc-45',
    ),
  ];
}

Future<void> _tapCreate(WidgetTester tester) async {
  const key = Key('create-office-button');
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('offices screen lists the company offices natively', (tester) async {
    final controller = OfficesController(
      api: FakeOfficesApi(),
      credentials: FakeSession(),
      locations: FakeLocations(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(home: OfficesPage(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.text('Offices'), findsOneWidget);
    expect(find.text('Company offices'), findsOneWidget);
    expect(find.text('Kigali Main Office'), findsOneWidget);
    expect(find.text('kigali@example.com'), findsOneWidget);
    expect(find.text('Kigali Downtown'), findsOneWidget);
    expect(find.text('ACME-KIG'), findsOneWidget);
    expect(find.widgetWithText(FloatingActionButton, 'New Office'), findsOneWidget);
  });

  testWidgets('new office form validates, picks a location and creates',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = FakeOfficesApi();
    final controller = OfficesController(
      api: api,
      credentials: FakeSession(),
      locations: FakeLocations(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(home: OfficesPage(controller: controller)));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(FloatingActionButton, 'New Office'),
    );
    await tester.pumpAndSettle();

    expect(find.text('New Office'), findsOneWidget);
    expect(find.text('Office details'), findsOneWidget);

    // Required fields are validated before any network call.
    await _tapCreate(tester);
    expect(find.text('Enter an office name.'), findsOneWidget);
    expect(api.createCalls, 0);

    await tester.enterText(
      find.widgetWithText(TextField, 'Office name *'),
      'Butare Depot',
    );
    await _tapCreate(tester);
    expect(
      find.text('Select a location from the synced trips locations.'),
      findsOneWidget,
    );
    expect(api.createCalls, 0);

    // Pick a cavgotrips location from the local sync database.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Select location *'));
    await tester.pumpAndSettle();
    expect(find.text('Select location'), findsOneWidget);
    expect(find.text('Kigali Downtown'), findsOneWidget);

    await tester.tap(find.text('Kigali Downtown'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, 'Kigali Downtown'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Contact emails'),
      'ops@example.com, hr@example.com',
    );

    await _tapCreate(tester);

    expect(api.createCalls, 1);
    expect(api.lastDraft!.name, 'Butare Depot');
    expect(api.lastDraft!.location.id, 45);
    expect(api.lastDraft!.contactEmails, ['ops@example.com', 'hr@example.com']);
    expect(find.text('Office created successfully.'), findsOneWidget);

    // Let the toast auto-dismiss so no timer is left pending.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
