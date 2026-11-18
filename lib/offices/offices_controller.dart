import 'package:flutter/foundation.dart';

import '../auth/access_api_client.dart';
import '../auth/credentials_manager.dart';
import '../sync/sync_models.dart';
import '../sync/sync_repository.dart';
import 'office_models.dart';
import 'offices_api_client.dart';

/// Location source for the office form. Backed by the cavgotrips locations
/// already synced into Fleetman's local database; injectable for tests.
abstract class OfficeLocationLookup {
  Future<List<LocationEntity>> search(String query);
}

class SyncOfficeLocationLookup implements OfficeLocationLookup {
  @override
  Future<List<LocationEntity>> search(String query) =>
      SyncRepository.instance.searchLocations(query);
}

/// Loads the company's offices and creates new ones for the signed-in Fleet
/// Manager. The company id is always read from the session — never from UI —
/// so a manager cannot create an office for another company.
class OfficesController extends ChangeNotifier {
  OfficesController({
    OfficesApi? api,
    FleetCredentials? credentials,
    OfficeLocationLookup? locations,
  })  : _api = api ?? OfficesApiClient(),
        _credentials = credentials ?? CredentialsManager.instance,
        _locations = locations ?? SyncOfficeLocationLookup();

  final OfficesApi _api;
  final FleetCredentials _credentials;
  final OfficeLocationLookup _locations;

  List<OfficeItem> _items = const <OfficeItem>[];
  bool _isLoading = false;
  bool _isCreating = false;
  String? _error;

  List<OfficeItem> get items => _items;
  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;
  String? get error => _error;

  void _update(void Function() change) {
    change();
    notifyListeners();
  }

  Future<List<LocationEntity>> searchLocations(String query) =>
      _locations.search(query);

  Future<void> load() async {
    _update(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _credentials.getAccessToken();
      final companyId = await _credentials.getCompanyId();
      if (token == null || token.isEmpty || companyId == null) {
        _update(() {
          _isLoading = false;
          _error = 'Your company session is unavailable. Please sign in again.';
        });
        return;
      }

      final items = await _api.fetchOffices(token, companyId: companyId);
      _update(() {
        _items = items;
        _isLoading = false;
      });
    } on AccessApiUnauthorizedException {
      await _handleUnauthorized();
    } on AccessApiException catch (e) {
      _update(() {
        _isLoading = false;
        _error = e.message;
      });
    } catch (e) {
      _update(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  /// Creates an office for the signed-in manager's company. Returns true only
  /// when the backend accepted it; the caller refreshes the list afterwards.
  Future<bool> create(OfficeDraft draft) async {
    if (_isCreating) return false;
    _update(() {
      _isCreating = true;
      _error = null;
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

      await _api.createOffice(
        token,
        companyId: companyId,
        draft: draft,
      );
      _update(() => _isCreating = false);
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
        _error = e.toString();
      });
      return false;
    }
  }

  Future<void> _handleUnauthorized() async {
    await _credentials.signOut();
    _update(() {
      _isLoading = false;
      _isCreating = false;
      _error = 'Your session has expired. Please sign in again.';
    });
  }
}
