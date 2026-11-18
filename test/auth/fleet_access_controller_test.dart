import 'package:flutter_test/flutter_test.dart';
import 'package:fleetman/auth/access_api_client.dart';
import 'package:fleetman/auth/auth_models.dart';
import 'package:fleetman/auth/credentials_manager.dart';
import 'package:fleetman/auth/fleet_access_controller.dart';

SyncProfileDto _profile({
  String? role,
  int? companyId,
  AccessRequestDto? request,
}) {
  return SyncProfileDto(
    user: SyncUserDto(role: role),
    company: companyId == null
        ? null
        : CompanyContextDto(
            companyId: companyId,
            companyName: 'Acme',
            companyCode: 'ACME',
          ),
    accessRequest: request,
  );
}

AccessRequestDto _request(String status) => AccessRequestDto(
  id: 7,
  status: status,
  companyCode: 'ACME',
  companyId: 3,
  companyName: 'Acme',
);

class FakeAccessApi implements AccessApi {
  SyncProfileDto syncProfile = _profile();
  AccessRequestLookup lookup = AccessRequestLookup.none();
  AccessApiException? postError;

  /// When set, the sync payload returned after a POST differs from the initial
  /// one, so tests can model the approval workflow.
  SyncProfileDto? syncAfterPost;

  int syncCalls = 0;
  int lookupCalls = 0;
  int postCalls = 0;
  String? postedCode;

  @override
  Future<SyncProfileDto> fetchSyncProfile(String accessToken) async {
    syncCalls++;
    return postCalls > 0 && syncAfterPost != null ? syncAfterPost! : syncProfile;
  }

  @override
  Future<AccessRequestLookup> fetchMyAccessRequest(String accessToken) async {
    lookupCalls++;
    return lookup;
  }

  @override
  Future<AccessRequestDto> requestFleetManagerAccess(
    String accessToken,
    String companyCode,
  ) async {
    postCalls++;
    postedCode = companyCode;
    if (postError != null) throw postError!;
    return _request('PENDING');
  }
}

class FakeCredentials implements FleetCredentials {
  FakeCredentials({
    this.token = 'tok',
    this.roles = const <String>[],
    this.companyId,
    this.backendRole,
  });

  String? token;
  List<String> roles;
  int? companyId;
  String? backendRole;
  bool refreshResult = true;
  int signOutCalls = 0;

  @override
  Future<String?> getAccessToken() async => token;

  @override
  Future<void> saveSyncProfile(SyncProfileDto profile) async {
    companyId = profile.company?.companyId;
    backendRole = profile.user.role;
  }

  @override
  Future<bool> hasFleetManagerRole() async =>
      roles.any((r) => r.toLowerCase() == kFleetManagerRole) ||
      backendRole?.toUpperCase() == 'FLEET_MANAGER';

  @override
  Future<int?> getCompanyId() async => companyId;

  @override
  Future<List<String>> getNexxauthRoles() async => roles;

  @override
  Future<String?> getBackendRole() async => backendRole;

  @override
  Future<String?> getRefreshToken() async => 'refresh';

  @override
  Future<bool> refreshNow() async => refreshResult;

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

void main() {
  late FakeAccessApi api;
  late FakeCredentials credentials;
  late FleetAccessController controller;

  FleetAccessController build() {
    final built = FleetAccessController(api: api, credentials: credentials);
    addTearDown(built.dispose);
    return built;
  }

  setUp(() {
    api = FakeAccessApi();
    credentials = FakeCredentials();
  });

  test('unlocks for a fleet manager with an approved company', () async {
    api.syncProfile = _profile(role: 'FLEET_MANAGER', companyId: 7);
    credentials = FakeCredentials(roles: const ['fleet_manager']);
    controller = build();

    await controller.refresh();

    expect(controller.state, FleetAccessState.allowed);
    expect(api.postCalls, 0);
  });

  test('non-staff user is blocked before a request can be submitted', () async {
    api.syncProfile = _profile();
    credentials = FakeCredentials(roles: const ['customer']);
    controller = build();

    await controller.refresh();

    expect(controller.state, FleetAccessState.roleRequired);
    expect(controller.message, contains('administrator'));
    expect(api.postCalls, 0);
  });

  test('staff role without company shows the company-code form', () async {
    api.syncProfile = _profile();
    credentials = FakeCredentials(roles: const ['fleet_manager']);
    controller = build();

    await controller.refresh();

    expect(controller.state, FleetAccessState.needsRoleRequest);
    expect(api.postCalls, 0);
  });

  test('pending request in the sync payload skips the status lookup', () async {
    api.syncProfile = _profile(request: _request('PENDING'));
    credentials = FakeCredentials(roles: const ['fleet_manager']);
    controller = build();

    await controller.refresh();

    expect(controller.state, FleetAccessState.pendingApproval);
    expect(api.lookupCalls, 0);
    expect(api.postCalls, 0);
  });

  test('pending request found via my-status blocks the form', () async {
    api.syncProfile = _profile();
    api.lookup = AccessRequestLookup.found(_request('PENDING'));
    credentials = FakeCredentials(roles: const ['fleet_manager']);
    controller = build();

    await controller.refresh();

    expect(controller.state, FleetAccessState.pendingApproval);
    expect(api.lookupCalls, 1);
    expect(api.postCalls, 0);
  });

  test('submitRequest rechecks and refuses when a request just appeared',
      () async {
    api.syncProfile = _profile();
    credentials = FakeCredentials(roles: const ['fleet_manager']);
    controller = build();
    await controller.refresh();
    expect(controller.state, FleetAccessState.needsRoleRequest);

    api.lookup = AccessRequestLookup.found(_request('PENDING'));
    final submitted = await controller.submitRequest('ACME');

    expect(submitted, isFalse);
    expect(api.postCalls, 0);
    expect(controller.state, FleetAccessState.pendingApproval);
  });

  test('submitRequest posts once and moves to pending approval', () async {
    api.syncProfile = _profile();
    api.syncAfterPost = _profile(request: _request('PENDING'));
    credentials = FakeCredentials(roles: const ['fleet_manager']);
    controller = build();
    await controller.refresh();

    final submitted = await controller.submitRequest(' ACME ');

    expect(submitted, isTrue);
    expect(api.postCalls, 1);
    expect(api.postedCode, 'ACME');
    expect(controller.state, FleetAccessState.pendingApproval);
  });

  test('backend duplicate conflict is treated as pending, not retried',
      () async {
    api.syncProfile = _profile();
    api.syncAfterPost = _profile(request: _request('PENDING'));
    api.postError = AccessApiException(
      'You already have a pending company access request. Please wait.',
      statusCode: 400,
    );
    credentials = FakeCredentials(roles: const ['fleet_manager']);
    controller = build();
    await controller.refresh();

    final submitted = await controller.submitRequest('ACME');

    expect(submitted, isFalse);
    expect(api.postCalls, 1);
    expect(controller.state, FleetAccessState.pendingApproval);
  });

  test('rejected request allows one fresh submission', () async {
    api.syncProfile = _profile(request: _request('REJECTED'));
    api.syncAfterPost = _profile(request: _request('PENDING'));
    credentials = FakeCredentials(roles: const ['fleet_manager']);
    controller = build();
    await controller.refresh();
    expect(controller.state, FleetAccessState.rejected);

    controller.showRequestForm();
    expect(controller.state, FleetAccessState.needsRoleRequest);

    final submitted = await controller.submitRequest('ACME');

    expect(submitted, isTrue);
    expect(api.postCalls, 1);
    expect(controller.state, FleetAccessState.pendingApproval);
  });

  test('status lookup failure surfaces an error and blocks submission',
      () async {
    api.syncProfile = _profile();
    api.lookup = AccessRequestLookup.error('Network unavailable');
    credentials = FakeCredentials(roles: const ['fleet_manager']);
    controller = build();

    await controller.refresh();

    expect(controller.state, FleetAccessState.error);
    expect(controller.message, contains('Network unavailable'));
    expect(await controller.submitRequest('ACME'), isFalse);
    expect(api.postCalls, 0);
  });

  test('approval that granted a non-manager role explains the mismatch',
      () async {
    api.syncProfile = _profile(
      role: 'WORKER',
      request: _request('APPROVED'),
    );
    credentials = FakeCredentials(
      roles: const ['worker'],
      backendRole: 'WORKER',
    );
    controller = build();

    await controller.refresh();

    expect(controller.state, FleetAccessState.error);
    expect(controller.message, contains('WORKER'));
    expect(controller.message, contains('FLEET_MANAGER'));
  });
}
