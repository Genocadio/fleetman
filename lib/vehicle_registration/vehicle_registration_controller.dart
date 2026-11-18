import 'package:flutter/foundation.dart';

import '../auth/access_api_client.dart';
import '../auth/credentials_manager.dart';
import 'vehicle_registration_api_client.dart';
import 'vehicle_registration_models.dart';

/// Drives the native vehicle registration form.
///
/// The company is never selected here: registration requires an approved
/// company session, but `companyCode` is intentionally omitted from the wire
/// body so the backend resolves the signed-in manager's own company.
///
/// Failures are surfaced once and never retried automatically. A successful
/// response is kept only for the one-time display of `initialPassword`.
class VehicleRegistrationController extends ChangeNotifier {
  VehicleRegistrationController({
    VehicleRegistrationApi? api,
    FleetCredentials? credentials,
  }) : _api = api ?? VehicleRegistrationApiClient(),
       _credentials = credentials ?? CredentialsManager.instance;

  final VehicleRegistrationApi _api;
  final FleetCredentials _credentials;

  bool _isCreating = false;
  String? _error;
  RegisteredVehicle? _created;

  bool get isCreating => _isCreating;
  String? get error => _error;
  RegisteredVehicle? get created => _created;

  void _update(void Function() change) {
    change();
    notifyListeners();
  }

  /// Clears the error banner without submitting anything again.
  void dismissError() {
    if (_error == null) return;
    _update(() => _error = null);
  }

  Future<bool> register(VehicleRegistrationDraft draft) async {
    final validationError = draft.validate();
    if (validationError != null) {
      _update(() => _error = validationError);
      return false;
    }
    if (_isCreating) return false;

    _update(() {
      _isCreating = true;
      _error = null;
      _created = null;
    });

    try {
      final token = await _credentials.getAccessToken();
      final companyId = await _credentials.getCompanyId();
      if (token == null || token.isEmpty || companyId == null) {
        _update(() {
          _isCreating = false;
          _error = 'Your company session is unavailable. Please sign in again.';
        });
        return false;
      }

      // companyId is a session check only; it is never sent to the backend.
      final result = await _api.register(token, draft: draft);
      _update(() {
        _isCreating = false;
        _created = result;
      });
      return true;
    } on AccessApiUnauthorizedException {
      await _handleUnauthorized();
      return false;
    } on AccessApiException catch (e) {
      _update(() {
        _isCreating = false;
        _error = e.message;
      });
      return false;
    } catch (e) {
      _update(() {
        _isCreating = false;
        _error = 'Could not register the vehicle. ${_unexpectedMessage(e)}';
      });
      return false;
    }
  }

  String _unexpectedMessage(Object error) {
    final text = error.toString().trim();
    if (text.isEmpty) return 'An unexpected error occurred.';
    if (text.startsWith('Exception:') || text.startsWith('Error:')) {
      return text.split(':').skip(1).join(':').trim();
    }
    return text;
  }

  Future<void> _handleUnauthorized() async {
    await _credentials.signOut();
    _update(() {
      _isCreating = false;
      _error = 'Your session has expired. Please sign in again.';
    });
  }
}
