import 'dart:async';

import 'package:flutter/foundation.dart';

import 'access_api_client.dart';
import 'auth_models.dart';
import 'credentials_manager.dart';

enum FleetAccessState {
  checking,
  allowed,
  needsRoleRequest,
  roleRequired,
  pendingApproval,
  rejected,
  error,
}

/// Decides whether the signed-in Nexxauth user may use Fleetman.
///
/// A valid identity is not enough: the user must have the FLEET_MANAGER role
/// AND an approved company membership from cavgomain. An existing
/// company-access request is always checked before a new one is submitted so
/// duplicate PENDING requests are never created.
class FleetAccessController extends ChangeNotifier {
  FleetAccessController({
    AccessApi? api,
    FleetCredentials? credentials,
  })  : _api = api ?? AccessApiClient(),
        _credentials = credentials ?? CredentialsManager.instance;

  final AccessApi _api;
  final FleetCredentials _credentials;

  static const Duration _pendingPollInterval = Duration(seconds: 20);

  FleetAccessState _state = FleetAccessState.checking;
  String _message = '';
  AccessRequestDto? _request;
  bool _busy = false;
  Timer? _pollTimer;
  bool _disposed = false;

  FleetAccessState get state => _state;
  String get message => _message;
  AccessRequestDto? get request => _request;
  bool get busy => _busy;

  void _update({
    required FleetAccessState state,
    String message = '',
    AccessRequestDto? request,
    bool? busy,
  }) {
    if (_disposed) return;
    _state = state;
    _message = message;
    _request = request;
    if (busy != null) _busy = busy;
    _syncPolling();
    notifyListeners();
  }

  void _syncPolling() {
    if (_state == FleetAccessState.pendingApproval) {
      _pollTimer ??= Timer.periodic(_pendingPollInterval, (_) {
        refresh();
      });
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  /// Re-reads the authoritative profile and re-evaluates access.
  Future<void> refresh({bool allowRoleRefresh = true}) async {
    // Keep the pending-approval screen visible while polling instead of
    // flashing the generic "checking" spinner every 20 seconds.
    _update(
      state: _state == FleetAccessState.pendingApproval
          ? FleetAccessState.pendingApproval
          : FleetAccessState.checking,
      busy: true,
    );

    String? token;
    try {
      token = await _credentials.getAccessToken();
      if (token == null || token.isEmpty) {
        _update(
          state: FleetAccessState.error,
          message: 'Your session has expired. Please sign in again.',
          busy: false,
        );
        return;
      }

      final profile = await _api.fetchSyncProfile(token);
      await _credentials.saveSyncProfile(profile);

      final hasRole = await _credentials.hasFleetManagerRole();
      final companyId = await _credentials.getCompanyId();
      if (hasRole && companyId != null) {
        _update(state: FleetAccessState.allowed, busy: false);
        return;
      }

      // Approval may have just happened in Nexxauth while this token still
      // carries the old role. Ask Nexxauth for a fresh token and re-check once.
      if (allowRoleRefresh &&
          profile.accessRequest != null &&
          profile.accessRequest!.isApproved) {
        final refreshed = await _credentials.refreshNow();
        if (refreshed) {
          await refresh(allowRoleRefresh: false);
          return;
        }
      }

      var existing = profile.accessRequest;
      if (existing == null) {
        final lookup = await _api.fetchMyAccessRequest(token);
        if (lookup.error != null) {
          _update(
            state: FleetAccessState.error,
            message: lookup.error!,
            busy: false,
          );
          return;
        }
        existing = lookup.request;
      }

      if (existing != null && existing.isPending) {
        _update(
          state: FleetAccessState.pendingApproval,
          message: 'Your Fleet Manager access request is awaiting approval.',
          request: existing,
          busy: false,
        );
        return;
      }
      if (existing != null && existing.isApproved) {
        final approvedRole = await _credentials.getBackendRole();
        _update(
          state: FleetAccessState.error,
          message: approvedRole?.toUpperCase() == 'FLEET_MANAGER'
              ? 'Your request was approved. Sign out and back in to refresh your role.'
              : 'Your request was approved with the ${approvedRole ?? 'WORKER'} role, which cannot access Fleetman. Ask an administrator to grant the FLEET_MANAGER role.',
          request: existing,
          busy: false,
        );
        return;
      }
      if (existing != null && existing.isRejected) {
        _update(
          state: FleetAccessState.rejected,
          message: existing.rejectionReason ??
              'Your access request was not approved. You may submit a new one.',
          request: existing,
          busy: false,
        );
        return;
      }

      final roles = await _credentials.getNexxauthRoles();
      final hasStaffRole = roles.any(
        (r) => kStaffRoles.contains(r.toLowerCase()),
      );
      final backendRole = await _credentials.getBackendRole();
      final hasManagerRole = backendRole?.toUpperCase() == 'FLEET_MANAGER';

      if (!hasStaffRole && !hasManagerRole) {
        // The company-access workflow preserves the requester's existing
        // Nexxauth staff role; non-staff users are approved as WORKER. Sending
        // them through that form would create a request that can never unlock
        // Fleetman, so require the role to be granted first.
        _update(
          state: FleetAccessState.roleRequired,
          message:
              'Fleet Manager access is required. Ask an administrator to grant you the FLEET_MANAGER role in Nexxauth, then sign in again to request company access.',
          busy: false,
        );
        return;
      }

      _update(
        state: FleetAccessState.needsRoleRequest,
        message:
            'Your Fleet Manager role is active, but you are not assigned to a company yet. Enter the company code to request access.',
        busy: false,
      );
    } on AccessApiUnauthorizedException {
      _update(
        state: FleetAccessState.error,
        message: 'Your session has expired. Please sign in again.',
        busy: false,
      );
    } on AccessApiException catch (e) {
      _update(
        state: FleetAccessState.error,
        message: e.message,
        busy: false,
      );
    } catch (e) {
      _update(
        state: FleetAccessState.error,
        message: e.toString(),
        busy: false,
      );
    }
  }

  /// Submits a company-access request, but only after confirming that no
  /// PENDING request already exists (client-side guard against duplicates).
  Future<bool> submitRequest(String companyCode) async {
    final code = companyCode.trim();
    if (code.isEmpty || _busy) return false;
    _update(state: _state, message: 'Submitting your request…', busy: true);

    try {
      final token = await _credentials.getAccessToken();
      if (token == null || token.isEmpty) {
        _update(
          state: FleetAccessState.error,
          message: 'Your session has expired. Please sign in again.',
          busy: false,
        );
        return false;
      }

      final lookup = await _api.fetchMyAccessRequest(token);
      if (lookup.error != null) {
        _update(
          state: FleetAccessState.error,
          message: 'Could not verify existing requests: ${lookup.error}',
          busy: false,
        );
        return false;
      }
      if (lookup.found) {
        final existing = lookup.request!;
        if (existing.isPending) {
          await refresh();
          return false;
        }
        if (existing.isApproved) {
          await refresh();
          return false;
        }
      }

      await _api.requestFleetManagerAccess(token, code);
      await refresh();
      return _state == FleetAccessState.pendingApproval ||
          _state == FleetAccessState.allowed;
    } on AccessApiException catch (e) {
      final lower = e.message.toLowerCase();
      if (lower.contains('already have a pending') ||
          lower.contains('already have access to this company') ||
          e.statusCode == 409) {
        // A concurrent request won the race — reflect its state instead of
        // allowing another submission.
        await refresh();
        return false;
      }
      _update(
        state: FleetAccessState.error,
        message: e.message,
        busy: false,
      );
      return false;
    } catch (e) {
      _update(state: FleetAccessState.error, message: e.toString(), busy: false);
      return false;
    }
  }

  void showRequestForm() {
    _update(
      state: FleetAccessState.needsRoleRequest,
      message: '',
      request: null,
      busy: false,
    );
  }

  Future<void> signOut() => _credentials.signOut();

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    super.dispose();
  }
}
