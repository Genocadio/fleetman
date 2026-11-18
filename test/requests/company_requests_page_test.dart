import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleetman/auth/auth_models.dart';
import 'package:fleetman/auth/credentials_manager.dart';
import 'package:fleetman/requests/company_requests_api_client.dart';
import 'package:fleetman/requests/company_requests_controller.dart';
import 'package:fleetman/requests/company_requests_page.dart';
import 'package:fleetman/requests/request_models.dart';

CompanyRequestItem _pending() => CompanyRequestItem.fromAccessJson({
  'id': 1,
  'firstName': 'Ada',
  'lastName': 'Nexx',
  'email': 'ada@example.com',
  'role': 'FLEET_MANAGER',
  'companyName': 'Acme Logistics',
  'status': 'PENDING',
  'createdAt': '2026-01-01T10:00:00',
});

class FakeRequestsApi implements CompanyRequestsApi {
  final List<CompanyRequestItem> items = [_pending()];
  int approveCalls = 0;
  int rejectCalls = 0;
  String? rejectReason;

  @override
  Future<List<CompanyRequestItem>> fetchRequests(
    String token, {
    required int companyId,
    bool pendingOnly = false,
  }) async =>
      List.unmodifiable(items);

  @override
  Future<CompanyRequestItem> approve(
    String token,
    CompanyRequestItem request,
  ) async {
    approveCalls++;
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
  Future<void> signOut() async {}
}

void main() {
  testWidgets('request review screen renders a pending card natively',
      (tester) async {
    final controller = CompanyRequestsController(
      api: FakeRequestsApi(),
      credentials: FakeSession(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: CompanyRequestsPage(controller: controller),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Requests'), findsOneWidget);
    expect(find.text('Company requests'), findsOneWidget);
    expect(find.text('Ada Nexx'), findsOneWidget);
    expect(find.text('ada@example.com'), findsOneWidget);
    expect(find.text('Fleet Manager'), findsOneWidget);
    expect(find.text('1 pending'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Approve'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Reject'), findsOneWidget);
  });

  testWidgets('approve asks for confirmation and shows a success toast',
      (tester) async {
    final api = FakeRequestsApi();
    final controller = CompanyRequestsController(
      api: api,
      credentials: FakeSession(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: CompanyRequestsPage(controller: controller),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();

    expect(find.text('Approve request?'), findsOneWidget);
    expect(find.textContaining('Grant Ada Nexx access'), findsOneWidget);

    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Approve'),
    ));
    await tester.pumpAndSettle();

    expect(api.approveCalls, 1);
    expect(find.textContaining('Request approved'), findsOneWidget);

    // Let the toast's auto-dismiss timer complete so no timer is left pending.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('reject forwards the typed reason', (tester) async {
    final api = FakeRequestsApi();
    final controller = CompanyRequestsController(
      api: api,
      credentials: FakeSession(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: CompanyRequestsPage(controller: controller),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Reject'));
    await tester.pumpAndSettle();

    expect(find.text('Reject request?'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Reason (optional)'),
      'Unknown employee',
    );
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Reject'),
    ));
    await tester.pumpAndSettle();

    expect(api.rejectCalls, 1);
    expect(api.rejectReason, 'Unknown employee');
    expect(find.textContaining('Request from Ada Nexx rejected'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
