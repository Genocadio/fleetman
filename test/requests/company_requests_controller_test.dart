import 'package:flutter_test/flutter_test.dart';
import 'package:fleetman/auth/access_api_client.dart';
import 'package:fleetman/auth/auth_models.dart';
import 'package:fleetman/auth/credentials_manager.dart';
import 'package:fleetman/requests/company_requests_api_client.dart';
import 'package:fleetman/requests/company_requests_controller.dart';
import 'package:fleetman/requests/request_models.dart';

CompanyRequestItem _item(int id, {String status = 'PENDING'}) =>
    CompanyRequestItem.fromAccessJson({
      'id': id,
      'firstName': 'Ada',
      'lastName': 'Nexx',
      'role': 'FLEET_MANAGER',
      'status': status,
      'companyId': 3,
      'createdAt': '2026-01-01T10:00:00',
    });

class FakeRequestsApi implements CompanyRequestsApi {
  List<CompanyRequestItem> items = [_item(1), _item(2)];
  Object? error;
  Object? actionError;
  int loadCalls = 0;
  int approveCalls = 0;
  int rejectCalls = 0;
  int? companyId;
  bool? pendingOnly;
  String? rejectReason;

  @override
  Future<List<CompanyRequestItem>> fetchRequests(
    String token, {
    required int companyId,
    bool pendingOnly = false,
  }) async {
    loadCalls++;
    this.companyId = companyId;
    this.pendingOnly = pendingOnly;
    if (error != null) throw error!;
    return items;
  }

  @override
  Future<CompanyRequestItem> approve(
    String token,
    CompanyRequestItem request,
  ) async {
    approveCalls++;
    if (actionError != null) throw actionError!;
    return request;
  }

  @override
  Future<CompanyRequestItem> reject(
    String token,
    CompanyRequestItem request, {
    String? reason,
  }) async {
    rejectCalls++;
    rejectReason = reason;
    return request;
  }
}

class FakeSession implements FleetCredentials {
  @override
  Future<String?> getAccessToken() async => 'tok';

  @override
  Future<void> saveSyncProfile(SyncProfileDto profile) async {}

  @override
  Future<bool> hasFleetManagerRole() async => true;

  @override
  Future<int?> getCompanyId() async => 3;

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

  int signOutCalls = 0;
}

void main() {
  late FakeRequestsApi api;
  late FakeSession session;
  late CompanyRequestsController controller;

  setUp(() {
    api = FakeRequestsApi();
    session = FakeSession();
    controller = CompanyRequestsController(api: api, credentials: session);
    addTearDown(controller.dispose);
  });

  test('loads pending requests for the current company', () async {
    await controller.load();

    expect(api.companyId, 3);
    expect(api.pendingOnly, isTrue);
    expect(controller.items.length, 2);
    expect(controller.pendingCount, 2);
    expect(controller.error, isNull);
  });

  test('switching to all requests reloads with the new filter', () async {
    await controller.load();
    await controller.setPendingOnly(false);

    expect(api.loadCalls, 2);
    expect(api.pendingOnly, isFalse);
  });

  test('approve acts then refreshes the queue', () async {
    await controller.load();
    final item = controller.items.first;

    final ok = await controller.approve(item);

    expect(ok, isTrue);
    expect(api.approveCalls, 1);
    expect(api.loadCalls, 2);
    expect(controller.isActing, isFalse);
    expect(controller.actingRequestId, isNull);
  });

  test('reject forwards the reason', () async {
    await controller.load();

    final ok = await controller.reject(controller.items.first, reason: 'Duplicate');

    expect(ok, isTrue);
    expect(api.rejectCalls, 1);
    expect(api.rejectReason, 'Duplicate');
  });

  test('an expired session signs the user out', () async {
    api.error = const AccessApiUnauthorizedException();

    await controller.load();

    expect(session.signOutCalls, 1);
    expect(controller.error, contains('expired'));
    expect(controller.isLoading, isFalse);
  });

  test('a stale request surfaces a friendly message and refreshes', () async {
    await controller.load();
    api.actionError = AccessApiException(
      'Request is not pending — current status: APPROVED',
      statusCode: 400,
    );

    final ok = await controller.approve(controller.items.first);

    expect(ok, isFalse);
    expect(controller.error, contains('already handled'));
    expect(api.loadCalls, 2);
  });
}
