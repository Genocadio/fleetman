import 'package:flutter/foundation.dart';

import '../auth/access_api_client.dart';
import '../auth/credentials_manager.dart';
import 'company_requests_api_client.dart';
import 'request_models.dart';

/// Which mutation is currently in flight. Exposed so the UI can show an
/// action-specific loading state instead of a generic spinner.
enum RequestAction { approve, reject }

extension RequestActionLabel on RequestAction {
  String get label => switch (this) {
    RequestAction.approve => 'Approving',
    RequestAction.reject => 'Rejecting',
  };
}

/// Loads and acts on the request queues for the signed-in Fleet Manager's
/// company. Kept separate from the access gate so approvals can be tested in
/// isolation and the UI only renders state.
///
/// Action failures are never retried automatically: the error is surfaced, the
/// acting state is cleared, and the user decides what to do next.
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
  RequestAction? _actingAction;
  int? _actingRequestId;
  int? _errorRequestId;
  String? _error;

  List<CompanyRequestItem> get items => _items;
  bool get pendingOnly => _pendingOnly;
  bool get isLoading => _isLoading;
  bool get isActing => _isActing;
  RequestAction? get actingAction => _actingAction;
  int? get actingRequestId => _actingRequestId;
  int? get errorRequestId => _errorRequestId;
  String? get error => _error;
  int get pendingCount => _items.where((item) => item.isPending).length;

  void _update(void Function() change) {
    change();
    notifyListeners();
  }

  void _clearActing() {
    _isActing = false;
    _actingAction = null;
    _actingRequestId = null;
  }

  /// Dismisses the error banner without touching the queue.
  void dismissError() {
    if (_error == null && _errorRequestId == null) return;
    _update(() {
      _error = null;
      _errorRequestId = null;
    });
  }

  Future<void> setPendingOnly(bool value) async {
    if (_pendingOnly == value) return;
    _update(() {
      _pendingOnly = value;
      _error = null;
      _errorRequestId = null;
    });
    await load();
  }

  Future<void> load() async {
    _update(() {
      _isLoading = true;
      _error = null;
      _errorRequestId = null;
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
        _error = 'Could not load requests. ${_unexpectedMessage(e)}';
      });
    }
  }

  /// Approves a request and refreshes the queue so the card moves out of the
  /// pending list with its authoritative status.
  Future<bool> approve(CompanyRequestItem item) => _act(
    item,
    RequestAction.approve,
    (token, target) => _api.approve(token, target),
  );

  Future<bool> reject(CompanyRequestItem item, {String? reason}) => _act(
    item,
    RequestAction.reject,
    (token, target) => _api.reject(token, target, reason: reason),
  );

  Future<bool> _act(
    CompanyRequestItem item,
    RequestAction action,
    Future<CompanyRequestItem> Function(String token, CompanyRequestItem target)
    actionCall,
  ) async {
    if (_isActing) return false;
    _update(() {
      _isActing = true;
      _actingAction = action;
      _actingRequestId = item.id;
      _error = null;
      _errorRequestId = null;
    });

    try {
      final token = await _credentials.getAccessToken();
      if (token == null || token.isEmpty) {
        _update(() {
          _clearActing();
          _error = 'Your session has expired. Please sign in again.';
          _errorRequestId = item.id;
        });
        return false;
      }

      await actionCall(token, item);
      // A successful action always refreshes so the queue is authoritative.
      // This is a post-success refresh, not a retry of the failed call.
      await load();
      _update(_clearActing);
      return true;
    } on AccessApiUnauthorizedException {
      await _handleUnauthorized();
      return false;
    } on AccessApiException catch (e) {
      // No implicit refresh on failure — the user must decide what to do.
      _update(() {
        _clearActing();
        _error = e.message;
        _errorRequestId = item.id;
      });
      return false;
    } catch (e) {
      _update(() {
        _clearActing();
        _error =
            'Could not ${action.label.toLowerCase()} this request. '
            '${_unexpectedMessage(e)}';
        _errorRequestId = item.id;
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
      _isLoading = false;
      _clearActing();
      _error = 'Your session has expired. Please sign in again.';
    });
  }
}
