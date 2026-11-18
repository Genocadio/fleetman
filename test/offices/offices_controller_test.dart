import 'package:flutter_test/flutter_test.dart';
import 'package:fleetman/auth/access_api_client.dart';
import 'package:fleetman/auth/auth_models.dart';
import 'package:fleetman/auth/credentials_manager.dart';
import 'package:fleetman/offices/office_models.dart';
import 'package:fleetman/offices/offices_api_client.dart';
import 'package:fleetman/offices/offices_controller.dart';
import 'package:fleetman/sync/sync_models.dart';

OfficeItem _office(int id) => OfficeItem(
  id: id,
  companyId: 3,
  name: 'Office $id',
  locationId: 40 + id,
);

class FakeOfficesApi implements OfficesApi {
  List<OfficeItem> offices = [_office(1), _office(2)];
  Object? loadError;
  Object? createError;
  int fetchCalls = 0;
  int createCalls = 0;
  int? fetchedCompanyId;
  int? createdCompanyId;
  OfficeDraft? createdDraft;

  @override
  Future<List<OfficeItem>> fetchOffices(
    String token, {
    required int companyId,
  }) async {
    fetchCalls++;
    fetchedCompanyId = companyId;
    if (loadError != null) throw loadError!;
    return offices;
  }

  @override
  Future<OfficeItem> createOffice(
    String token, {
    required int companyId,
    required OfficeDraft draft,
  }) async {
    createCalls++;
    createdCompanyId = companyId;
    createdDraft = draft;
    if (createError != null) throw createError!;
    return _office(3);
  }
}

class FakeSession implements FleetCredentials {
  int? companyId = 3;
  String? token = 'tok';
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

class FakeLocations implements OfficeLocationLookup {
  final List<LocationEntity> locations = [
    const LocationEntity(id: 45, googlePlaceName: 'Kigali Downtown'),
    const LocationEntity(id: 46, customName: 'Butare Depot'),
  ];

  @override
  Future<List<LocationEntity>> search(String query) async {
    if (query.trim().isEmpty) return locations;
    final lower = query.toLowerCase();
    return locations
        .where((l) => l.displayName.toLowerCase().contains(lower))
        .toList();
  }
}

OfficeDraft _draft() => OfficeDraft(
  name: 'New Office',
  location: const LocationEntity(id: 45, googlePlaceName: 'Kigali Downtown'),
);

void main() {
  late FakeOfficesApi api;
  late FakeSession session;
  late OfficesController controller;

  setUp(() {
    api = FakeOfficesApi();
    session = FakeSession();
    controller = OfficesController(
      api: api,
      credentials: session,
      locations: FakeLocations(),
    );
    addTearDown(controller.dispose);
  });

  test('load uses the company id from the session', () async {
    await controller.load();

    expect(api.fetchCalls, 1);
    expect(api.fetchedCompanyId, 3);
    expect(controller.items.map((e) => e.name), ['Office 1', 'Office 2']);
    expect(controller.error, isNull);
  });

  test('create injects the session company id and reports success', () async {
    final ok = await controller.create(_draft());

    expect(ok, isTrue);
    expect(api.createCalls, 1);
    expect(api.createdCompanyId, 3);
    expect(api.createdDraft!.name, 'New Office');
    expect(controller.isCreating, isFalse);
  });

  test('missing company session blocks both load and create', () async {
    session.companyId = null;

    await controller.load();
    expect(controller.error, contains('company session'));

    final ok = await controller.create(_draft());
    expect(ok, isFalse);
    expect(api.createCalls, 0);
    expect(controller.error, contains('company session'));
  });

  test('backend validation error is exposed', () async {
    api.createError = AccessApiException(
      'name is required when creating an office',
      statusCode: 400,
    );

    final ok = await controller.create(_draft());

    expect(ok, isFalse);
    expect(controller.error, 'name is required when creating an office');
  });

  test('expired session signs the manager out', () async {
    api.loadError = const AccessApiUnauthorizedException();

    await controller.load();

    expect(session.signOutCalls, 1);
    expect(controller.error, contains('expired'));
    expect(controller.isLoading, isFalse);
  });

  test('location search delegates to the synced locations source', () async {
    final results = await controller.searchLocations('Butare');

    expect(results, hasLength(1));
    expect(results.single.id, 46);
  });
}
