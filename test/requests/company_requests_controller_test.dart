import 'dart:async';

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
  Future<void>? actionGate;
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
    if (actionGate != null) await actionGate;
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
    if (actionGate != null) await actionGate;
    if (actionError != null) throw actionError!;
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

    final ok = await controller.reject(
      controller.items.first,
      reason: 'Duplicate',
    );

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

  test('an action error is surfaced verbatim with no implicit retry', () async {
    await controller.load();
    api.actionError = AccessApiException(
      'Request is not pending — current status: APPROVED',
      statusCode: 400,
    );

    final ok = await controller.approve(controller.items.first);

    expect(ok, isFalse);
    expect(
      controller.error,
      'Request is not pending — current status: APPROVED',
    );
    expect(controller.errorRequestId, 1);
    expect(api.loadCalls, 1);
    expect(controller.isActing, isFalse);
    expect(controller.actingAction, isNull);
  });

  test('acting state exposes which action is in flight', () async {
    await controller.load();
    final gate = Completer<void>();
    api.actionGate = gate.future;

    final pending = controller.reject(controller.items.first, reason: 'test');
    await Future<void>.delayed(Duration.zero);

    expect(controller.isActing, isTrue);
    expect(controller.actingAction, RequestAction.reject);
    expect(controller.actingRequestId, 1);

    // A second action is ignored while one is in flight.
    expect(await controller.approve(controller.items.first), isFalse);
    expect(api.approveCalls, 0);

    gate.complete();
    await pending;
    expect(controller.isActing, isFalse);
    expect(controller.actingAction, isNull);
  });

  test(
    'dismissing an error clears both the banner and the card marker',
    () async {
      await controller.load();
      api.actionError = AccessApiException(
        'Permission denied',
        statusCode: 403,
      );

      await controller.approve(controller.items.first);
      expect(controller.error, 'Permission denied');
      expect(controller.errorRequestId, 1);

      controller.dismissError();
      expect(controller.error, isNull);
      expect(controller.errorRequestId, isNull);
    },
  );

  test('unexpected errors become readable messages', () async {
    await controller.load();
    api.actionError = const HttpExceptionLike('socket closed');

    final ok = await controller.approve(controller.items.first);

    expect(ok, isFalse);
    expect(controller.error, contains('socket closed'));
    expect(controller.isActing, isFalse);
  });
}

class HttpExceptionLike implements Exception {
  const HttpExceptionLike(this.message);
  final String message;
  @override
  String toString() => 'Exception: $message';
}
