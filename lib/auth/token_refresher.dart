/// Refreshes the Nexxauth session and returns a usable access token, or null
/// when the session can no longer be recovered. Data API clients call this once
/// after an HTTP 401 so a revoked/rotated token does not require a full
/// sign-out when the local expiry check did not catch it.
typedef TokenRefresher = Future<String?> Function();
