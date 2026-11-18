import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fleetman/auth/auth_api_client.dart';
import 'package:fleetman/auth/auth_models.dart';
import 'package:fleetman/core/app_config.dart';

http.Response _json(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'Content-Type': 'application/json'},
  );
}

Map<String, dynamic> _loginUser({List<String> roles = const ['fleet_manager']}) {
  return {
    'id': 5,
    'firstName': 'Ada',
    'lastName': 'Nexx',
    'email': 'ada@example.com',
    'enabled': true,
    'roles': roles,
    'authTypes': ['PASSWORD'],
  };
}

AuthApiClient _client(http.Client httpClient) => AuthApiClient(
      httpClient: httpClient,
      clientId: 'cli_test',
      origin: 'android://com.example.fleetman',
    );

void main() {
  group('AuthApiClient', () {
    test('login posts the Nexxauth payload and headers', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return _json({
          'accessToken': 'access-1',
          'refreshToken': 'refresh-1',
          'tokenType': 'Bearer',
          'expiresInSeconds': 3600,
          'user': _loginUser(),
          'actions': [],
        });
      });

      final response = await _client(client).login(
        LoginRequestDto.fromInput(' ada@example.com ', 'secret'),
      );

      expect(captured!.method, 'POST');
      expect(captured!.url.toString(),
          '${AppConfig.nexxauthBaseUrl}/auth/login');
      expect(captured!.headers['X-Client-Id'], 'cli_test');
      expect(captured!.headers['Origin'], 'android://com.example.fleetman');
      expect(captured!.headers['Accept'], 'application/json');

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['identifier'], 'ada@example.com');
      expect(body['identifierType'], 'EMAIL');
      expect(body['authType'], 'PASSWORD');
      expect(body['password'], 'secret');

      expect(response.accessToken, 'access-1');
      expect(response.user.hasRole('fleet_manager'), isTrue);
    });

    test('identifier type is PHONE for phone numbers', () async {
      Map<String, dynamic>? body;
      final client = MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return _json({
          'accessToken': 'a',
          'refreshToken': 'r',
          'expiresInSeconds': 60,
          'user': _loginUser(),
        });
      });

      await _client(client).login(LoginRequestDto.fromInput('+250788123456', 'p'));

      expect(body!['identifier'], '+250788123456');
      expect(body!['identifierType'], 'PHONE');
    });

    test('identifier type is omitted for usernames', () async {
      Map<String, dynamic>? body;
      final client = MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return _json({
          'accessToken': 'a',
          'refreshToken': 'r',
          'expiresInSeconds': 60,
          'user': _loginUser(),
        });
      });

      await _client(client).login(LoginRequestDto.fromInput('ada.nex', 'p'));

      expect(body!.containsKey('identifierType'), isFalse);
    });

    test('refresh keeps the rotated token and refreshed roles', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return _json({
          'accessToken': 'access-2',
          'refreshToken': 'refresh-2',
          'expiresInSeconds': 1800,
          'user': _loginUser(roles: const ['worker']),
        });
      });

      final result = await _client(client).refresh('refresh-1');

      expect(captured!.url.toString(),
          '${AppConfig.nexxauthBaseUrl}/auth/refresh');
      expect(jsonDecode(captured!.body), {'refreshToken': 'refresh-1'});
      expect(result.refreshToken, 'refresh-2');
      expect(result.user?.roles, ['worker']);
    });

    test('Nexxauth error messages are surfaced', () async {
      final client = MockClient(
        (_) async => _json({'message': 'Invalid credentials'}, statusCode: 401),
      );

      expect(
        () => _client(client).login(
          LoginRequestDto.fromInput('ada@example.com', 'wrong'),
        ),
        throwsA(
          isA<AuthApiException>().having(
            (e) => e.message,
            'message',
            'Invalid credentials',
          ),
        ),
      );
    });

    test('missing client key fails before any network call', () async {
      final client = MockClient((_) async {
        fail('should not perform a request');
      });

      expect(
        () => AuthApiClient(httpClient: client).login(
          LoginRequestDto.fromInput('ada@example.com', 'secret'),
        ),
        throwsA(isA<AuthApiException>()),
      );
    });
  });
}
