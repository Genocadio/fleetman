class AppConfig {
  /// CavGo API gateway. Canonical production origin has no `/api` prefix.
  static const String baseUrl = 'https://api.gocavgo.com';

  /// Nexxauth is a separate identity host and is never proxied through the gateway.
  /// The base URL includes the platform slug.
  static const String nexxauthBaseUrl = 'https://auth.nexxserve.dev/cavgo';

  /// Public Nexxauth client key for the Fleetman Android client (X-Client-Id).
  /// Inject at build time, e.g.:
  ///   flutter build apk --dart-define=NEXXAUTH_CLIENT_ID=cli_...
  static const String nexxauthClientId = String.fromEnvironment(
    'NEXXAUTH_CLIENT_ID',
  );

  /// Mirrors the ANDROID client's Origin header used by twese-android.
  static const String nexxauthOrigin = String.fromEnvironment(
    'NEXXAUTH_ORIGIN',
    defaultValue: 'android://com.example.fleetman',
  );

  static bool get isNexxauthConfigured => nexxauthClientId.isNotEmpty;
}
