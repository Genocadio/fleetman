import 'package:flutter/foundation.dart';

import '../auth/access_api_client.dart';
import '../auth/credentials_manager.dart';
import 'company_requests_api_client.dart';
import 'request_models.dart';

/// Loads and acts on the request queues for the signed-in Fleet Manager's
/// company. Kept separate from the access gate so approvals can be tested in
/// isolation and the UI only renders state.
class CompanyRequestsController extends ChangeNotifier {
  CompanyRequestsController({
    CompanyRequestsApi? api,
    FleetCredentials? credentials,
  })  : _api = api ?? CompanyRequestsApiClient(),
        _credentials = credentials ?? CredentialsManager.instance;

  final CompanyRequestsApi _api;
  final FleetCredentials _credentials;

  List<CompanyRequestItem> _items = const [];
  bool _pendingOnly = true;
  bool _isLoading = false;
  bool _isActing = false;
  int? _actingRequestId;
  String? _error;

  List<CompanyRequestItem> get items => _items;
  bool get pendingOnly => _pendingOnly;
  bool get isLoading => _isLoading;
  bool get isActing => _isActing;
  int? get actingRequestId => _actingRequestId;
  String? get error => _error;
  int get pendingCount => _items.where((item) => item.isPending).length;

  void _update(void Function() change) {
    change();
    notifyListeners();
  }

  Future<void> setPendingOnly(bool value) async {
    if (_pendingOnly == value) return;
    _update(() {
      _pendingOnly = value;
      _error = null;
    });
    await load();
  }

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

      final items = await _api.fetchRequests(
        token,
        companyId: companyId,
        pendingOnly: _pendingOnly,
      );
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

  /// Approves a request and refreshes the queue so the card moves out of the
  /// pending list with its authoritative status.
  Future<bool> approve(CompanyRequestItem item) => _act(
    item,
    (token, target) => _api.approve(token, target),
  );

  Future<bool> reject(CompanyRequestItem item, {String? reason}) => _act(
    item,
    (token, target) => _api.reject(token, target, reason: reason),
  );

  Future<bool> _act(
    CompanyRequestItem item,
    Future<CompanyRequestItem> Function(String token, CompanyRequestItem target)
        action,
  ) async {
    if (_isActing) return false;
    _update(() {
      _isActing = true;
      _actingRequestId = item.id;
      _error = null;
    });

    try {
      final token = await _credentials.getAccessToken();
      if (token == null || token.isEmpty) {
        _update(() {
          _isActing = false;
          _actingRequestId = null;
          _error = 'Your session has expired. Please sign in again.';
        });
        return false;
      }

      await action(token, item);
      await load();
      _update(() {
        _isActing = false;
        _actingRequestId = null;
      });
      return true;
    } on AccessApiUnauthorizedException {
      await _handleUnauthorized();
      return false;
    } on AccessApiException catch (e) {
      final message = e.message.toLowerCase().contains('not pending')
          ? 'This request was already handled. Refreshing the list.'
          : e.message;
      // Refresh first so a stale card is removed, then surface the friendly
      // message. `load()` clears `_error`, so it must be set afterwards.
      await load();
      _update(() {
        _isActing = false;
        _actingRequestId = null;
        _error = message;
      });
      return false;
    } catch (e) {
      _update(() {
        _isActing = false;
        _actingRequestId = null;
        _error = e.toString();
      });
      return false;
    }
  }

  Future<void> _handleUnauthorized() async {
    await _credentials.signOut();
    _update(() {
      _isLoading = false;
      _isActing = false;
      _actingRequestId = null;
      _error = 'Your session has expired. Please sign in again.';
    });
  }
}
