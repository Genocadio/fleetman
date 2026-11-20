import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleetman/auth/access_api_client.dart';
import 'package:fleetman/auth/auth_models.dart';
import 'package:fleetman/auth/credentials_manager.dart';
import 'package:fleetman/auth/fleet_access_controller.dart';
import 'package:fleetman/auth/fleet_access_gate.dart';
import 'package:fleetman/core/app_skeleton.dart';

class _Api implements AccessApi {
  _Api({this.fail = false});

  final bool fail;

  @override
  Future<SyncProfileDto> fetchSyncProfile(String accessToken) async {
    if (fail) throw const AccessApiException('offline');
    throw UnimplementedError();
  }

  @override
  Future<AccessRequestLookup> fetchMyAccessRequest(String accessToken) =>
      throw UnimplementedError();

  @override
  Future<AccessRequestDto> requestFleetManagerAccess(
    String accessToken,
    String companyCode,
  ) =>
      throw UnimplementedError();
}

class _Credentials implements FleetCredentials {
  @override
  Future<String?> getAccessToken() async => 'tok';

  @override
  Future<void> saveSyncProfile(SyncProfileDto profile) async {}

  @override
  Future<bool> hasFleetManagerRole() async => false;

  @override
  Future<int?> getCompanyId() async => null;

  @override
  Future<List<String>> getNexxauthRoles() async => const [];

  @override
  Future<String?> getBackendRole() async => null;

  @override
  Future<String?> getRefreshToken() async => 'refresh';

  @override
  Future<bool> refreshNow() async => false;

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets(
    'sign-in access check stays hidden behind a neutral skeleton',
    (tester) async {
      final controller = FleetAccessController(
        api: _Api(),
        credentials: _Credentials(),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(home: FleetAccessScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(controller.state, FleetAccessState.checking);
      expect(find.text('Checking your Fleet Manager access…'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(AppSkeleton), findsWidgets);
    },
  );

  testWidgets(
    'gate screens refresh by pull-down instead of refresh icon buttons',
    (tester) async {
      final controller = FleetAccessController(
        api: _Api(fail: true),
        credentials: _Credentials(),
      );
      addTearDown(controller.dispose);
      await controller.refresh();

      await tester.pumpWidget(
        MaterialApp(home: FleetAccessScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(controller.state, FleetAccessState.error);
      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsNothing);
      expect(find.byIcon(Icons.refresh_rounded), findsNothing);
      expect(find.text('Pull down to try again.'), findsOneWidget);
    },
  );
}
