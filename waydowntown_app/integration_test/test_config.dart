/// Configuration for integration tests that run against a real backend.
class TestConfig {
  /// API base URL for the test backend.
  /// Can be overridden via --dart-define=API_BASE_URL=<url>
  /// Default: http://localhost:4001
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4001',
  );
}
