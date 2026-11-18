import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../sync/local_sync_database.dart';
import 'auth_api_client.dart';
import 'auth_models.dart';

/// Testable seam for the session data needed by [FleetAccessController].
abstract class FleetCredentials {
  Future<String?> getAccessToken();

  Future<void> saveSyncProfile(SyncProfileDto profile);

  Future<bool> hasFleetManagerRole();

  Future<int?> getCompanyId();

  Future<List<String>> getNexxauthRoles();

  Future<String?> getBackendRole();

  Future<String?> getRefreshToken();

  Future<bool> refreshNow();

  Future<void> signOut();
}

class CredentialsManager implements FleetCredentials {
  CredentialsManager._();

  static final CredentialsManager instance = CredentialsManager._();

  static const _keyAccessToken = 'auth_access_token';
  static const _keyRefreshToken = 'auth_refresh_token';
  static const _keyTokenExpiresAt = 'auth_token_expires_at';
  static const _keyUserId = 'auth_user_id';
  static const _keyUsername = 'auth_username';
  static const _keyEmail = 'auth_email';
  static const _keyRoles = 'auth_roles';
  static const _keyCompanyName = 'auth_company_name';
  static const _keyCompanyId = 'auth_company_id';
  static const _keyBackendRole = 'auth_backend_role';
  static const _keyAccessRequestStatus = 'auth_access_request_status';
  static const _keyAccessRequestReason = 'auth_access_request_reason';

  /// Refresh proactively five minutes before expiry, like twese-web/android.
  static const int _refreshSkewSeconds = 5 * 60;

  final LocalSyncDatabase _db = LocalSyncDatabase.instance;
  final AuthApiClient _authApi = AuthApiClient();

  Future<String?>? _refreshInFlight;

  // Expose observable login/profile state.
  final ValueNotifier<bool> isLoggedInNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> currentUsername = ValueNotifier<String>('');
  final ValueNotifier<String> currentCompanyName = ValueNotifier<String>('');

  Future<void> init() async {
    final token = await _db.getStateValue(_keyAccessToken);
    if (token != null && token.isNotEmpty) {
      isLoggedInNotifier.value = true;
      currentUsername.value = await _db.getStateValue(_keyUsername) ?? '';
      currentCompanyName.value = await _db.getStateValue(_keyCompanyName) ?? '';
    } else {
      isLoggedInNotifier.value = false;
    }
  }

  Future<void> saveUserData(NexxAuthResponse response) async {
    await _storeTokens(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      expiresAt: response.expiresAt,
    );
    await _db.setStateValue(_keyUserId, response.user.id.toString());
    await _db.setStateValue(_keyUsername, response.user.displayName);
    await _db.setStateValue(_keyEmail, response.user.email ?? '');
    await _db.setStateValue(_keyRoles, jsonEncode(response.user.roles));

    // Company membership and effective role come from the backend, not Nexxauth.
    await _db.deleteStateValue(_keyCompanyId);
    await _db.deleteStateValue(_keyCompanyName);
    await _db.deleteStateValue(_keyBackendRole);
    await _db.deleteStateValue(_keyAccessRequestStatus);
    await _db.deleteStateValue(_keyAccessRequestReason);

    currentUsername.value = response.user.displayName;
    currentCompanyName.value = '';
    isLoggedInNotifier.value = true;
  }

  @override
  Future<void> saveSyncProfile(SyncProfileDto profile) async {
    if (profile.company != null) {
      await _db.setStateValue(
        _keyCompanyId,
        profile.company!.companyId.toString(),
      );
      await _db.setStateValue(
        _keyCompanyName,
        profile.company!.companyName ?? '',
      );
    } else {
      await _db.deleteStateValue(_keyCompanyId);
      await _db.deleteStateValue(_keyCompanyName);
    }

    if (profile.user.role != null) {
      await _db.setStateValue(_keyBackendRole, profile.user.role!);
    } else {
      await _db.deleteStateValue(_keyBackendRole);
    }

    final request = profile.accessRequest;
    if (request != null) {
      await _db.setStateValue(_keyAccessRequestStatus, request.status);
      await _db.setStateValue(
        _keyAccessRequestReason,
        request.rejectionReason ?? '',
      );
    } else {
      await _db.deleteStateValue(_keyAccessRequestStatus);
      await _db.deleteStateValue(_keyAccessRequestReason);
    }

    currentCompanyName.value = profile.company?.companyName ?? '';
  }

  Future<void> _storeTokens({
    required String accessToken,
    required String? refreshToken,
    required int expiresAt,
  }) async {
    await _db.setStateValue(_keyAccessToken, accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _db.setStateValue(_keyRefreshToken, refreshToken);
    }
    await _db.setStateValue(_keyTokenExpiresAt, expiresAt.toString());
  }

  Future<void> clearUserData() async {
    for (final key in <String>[
      _keyAccessToken,
      _keyRefreshToken,
      _keyTokenExpiresAt,
      _keyUserId,
      _keyUsername,
      _keyEmail,
      _keyRoles,
      _keyCompanyName,
      _keyCompanyId,
      _keyBackendRole,
      _keyAccessRequestStatus,
      _keyAccessRequestReason,
    ]) {
      await _db.deleteStateValue(key);
    }

    currentUsername.value = '';
    currentCompanyName.value = '';
    isLoggedInNotifier.value = false;
  }

  @override
  Future<String?> getRefreshToken() =>
      _db.getStateValue(_keyRefreshToken);

  /// Best-effort Nexxauth logout followed by local session cleanup.
  @override
  Future<void> signOut() async {
    final refreshToken = await getRefreshToken();
    try {
      await _authApi.logout(refreshToken);
    } catch (_) {
      // Revocation failure must not block local sign-out.
    }
    await clearUserData();
  }

  /// Returns a usable access token, refreshing it via Nexxauth when it is
  /// expired or close to expiry. Refreshes are deduplicated so the single-use
  /// rotating refresh token is never consumed twice.
  @override
  Future<String?> getAccessToken() async {
    final token = await _db.getStateValue(_keyAccessToken);
    if (token == null || token.isEmpty) return null;

    final expiresAt =
        int.tryParse(await _db.getStateValue(_keyTokenExpiresAt) ?? '') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (expiresAt - now > _refreshSkewSeconds) return token;

    return _refreshOnce();
  }

  /// Deduplicates refreshes: Nexxauth refresh tokens are single-use, so two
  /// concurrent 401s must never consume the same token twice.
  Future<String?> _refreshOnce() {
    final pending = _refreshInFlight;
    if (pending != null) return pending;

    final future = _refreshAccessToken().whenComplete(() {
      _refreshInFlight = null;
    });
    _refreshInFlight = future;
    return future;
  }

  /// Force a token refresh (e.g. after an access request was approved and the
  /// current token still carries the old role).
  @override
  Future<bool> refreshNow() async {
    final token = await _refreshOnce();
    return token != null && token.isNotEmpty;
  }

  /// Recover from a backend 401. Returns the refreshed access token, or null
  /// when the session was cleared and the user must sign in again.
  Future<String?> refreshAccessTokenForRetry() => _refreshOnce();

  Future<String?> _refreshAccessToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await clearUserData();
      return null;
    }
    try {
      final result = await _authApi.refresh(refreshToken);
      await _storeTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 +
            result.expiresInSeconds,
      );
      if (result.user != null) {
        await _db.setStateValue(_keyRoles, jsonEncode(result.user!.roles));
        await _db.setStateValue(_keyUsername, result.user!.displayName);
      }
      return result.accessToken;
    } on AuthApiException catch (e) {
      if (e.statusCode == 400 ||
          e.statusCode == 401 ||
          e.statusCode == 403) {
        // A rejected/replayed refresh token invalidates the whole session.
        await clearUserData();
      }
      return null;
    }
  }

  @override
  Future<int?> getCompanyId() async {
    final raw = await _db.getStateValue(_keyCompanyId);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return int.tryParse(raw.trim());
  }

  @override
  Future<List<String>> getNexxauthRoles() async {
    final raw = await _db.getStateValue(_keyRoles);
    if (raw == null || raw.isEmpty) return const <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {
      // ignore malformed cached roles
    }
    return const <String>[];
  }

  @override
  Future<String?> getBackendRole() =>
      _db.getStateValue(_keyBackendRole);

  Future<String?> getAccessRequestStatus() =>
      _db.getStateValue(_keyAccessRequestStatus);

  /// True when the identity provider has granted the Fleet Manager role.
  /// Company membership is checked separately via [getCompanyId].
  @override
  Future<bool> hasFleetManagerRole() async {
    final roles = await getNexxauthRoles();
    if (roles.any((r) => r.toLowerCase() == kFleetManagerRole)) return true;
    final backendRole = await getBackendRole();
    return backendRole?.toUpperCase() == 'FLEET_MANAGER';
  }
}
