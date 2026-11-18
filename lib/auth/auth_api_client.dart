import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import 'auth_models.dart';

class AuthApiException implements Exception {
  const AuthApiException(
    this.message, {
    this.statusCode,
    this.isTransient = false,
  });

  final String message;
  final int? statusCode;
  final bool isTransient;

  @override
  String toString() => 'AuthApiException: $message';
}

/// Direct client for Nexxauth. Nexxauth is a separate identity host and is
/// never proxied through the CavGo API gateway.
class AuthApiClient {
  AuthApiClient({
    http.Client? httpClient,
    String? clientId,
    String? origin,
  })  : _httpClient = httpClient ?? http.Client(),
        _clientId = clientId ?? AppConfig.nexxauthClientId,
        _origin = origin ?? AppConfig.nexxauthOrigin;

  final http.Client _httpClient;
  final String _clientId;
  final String _origin;
  static const String _noInternetMessage =
      'No internet connection. Please check your network and try again.';
  static const String _unavailableMessage =
      'The sign-in service is temporarily unavailable. Please try again shortly.';

  Future<AuthResponse> _post(String path, Map<String, dynamic> body) async {
    if (_clientId.isEmpty) {
      throw const AuthApiException(
        'Sign-in is not configured. Provide NEXXAUTH_CLIENT_ID at build time '
        '(flutter build --dart-define=NEXXAUTH_CLIENT_ID=cli_...).',
      );
    }

    final uri = Uri.parse('${AppConfig.nexxauthBaseUrl}$path');
    late final http.Response response;
    try {
      response = await _httpClient.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json; charset=utf-8',
          'X-Client-Id': _clientId,
          'Origin': _origin,
        },
        body: jsonEncode(body),
      );
    } on SocketException {
      throw const AuthApiException(_noInternetMessage, isTransient: true);
    } catch (e) {
      final lower = e.toString().toLowerCase();
      if (lower.contains('failed host lookup') ||
          lower.contains('no address associated with hostname') ||
          lower.contains('network is unreachable')) {
        throw const AuthApiException(_noInternetMessage, isTransient: true);
      }
      rethrow;
    }

    Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(response.body);
      decoded = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    } catch (_) {
      decoded = <String, dynamic>{};
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode >= 500) {
        throw AuthApiException(
          _unavailableMessage,
          statusCode: response.statusCode,
          isTransient: true,
        );
      }
      final message = decoded['message'] as String? ??
          decoded['error'] as String? ??
          'Sign-in request failed (HTTP ${response.statusCode})';
      throw AuthApiException(
        message,
        statusCode: response.statusCode,
        isTransient: response.statusCode >= 500,
      );
    }

    try {
      return AuthResponse.fromJson(decoded);
    } on FormatException catch (e) {
      throw AuthApiException(e.message, statusCode: response.statusCode);
    }
  }

  /// POST {NEXXAUTH_BASE_URL}/auth/login
  Future<NexxAuthResponse> login(LoginRequestDto request) async {
    final response = await _post('/auth/login', request.toJson());
    final login = response.login;
    if (login == null) {
      throw const AuthApiException('Unexpected login response from Nexxauth');
    }
    return login;
  }

  /// POST {NEXXAUTH_BASE_URL}/auth/refresh
  ///
  /// Refresh tokens are single-use and rotated: the returned refresh token
  /// must replace the stored one immediately.
  Future<NexxAuthRefreshResponse> refresh(String refreshToken) async {
    final response = await _post('/auth/refresh', {
      'refreshToken': refreshToken,
    });
    if (response.login != null) {
      return NexxAuthRefreshResponse(
        accessToken: response.login!.accessToken,
        refreshToken: response.login!.refreshToken,
        expiresInSeconds: response.login!.expiresInSeconds,
        user: response.login!.user,
      );
    }
    if (response.refresh != null) return response.refresh!;
    throw const AuthApiException('Unexpected refresh response from Nexxauth');
  }

  /// POST {NEXXAUTH_BASE_URL}/auth/logout — best effort.
  Future<void> logout(String? refreshToken) async {
    if (refreshToken == null || refreshToken.isEmpty) return;
    try {
      await _post('/auth/logout', {'refreshToken': refreshToken});
    } on AuthApiException {
      // Revocation failure must not block local sign-out.
    }
  }
}

/// Internal union used by [_post] because login and refresh have different
/// response shapes.
class AuthResponse {
  const AuthResponse._({this.login, this.refresh});

  final NexxAuthResponse? login;
  final NexxAuthRefreshResponse? refresh;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('user')) {
      return AuthResponse._(login: NexxAuthResponse.fromJson(json));
    }
    if (json.containsKey('accessToken')) {
      return AuthResponse._(refresh: NexxAuthRefreshResponse.fromJson(json));
    }
    return const AuthResponse._();
  }
}
