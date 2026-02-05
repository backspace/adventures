import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:waydowntown/refresh_token_interceptor.dart';
import 'package:waydowntown/services/user_service.dart';

import 'test_backend_client.dart';
import 'test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestBackendClient testClient;
  late TestUserCredentials credentials;
  late TestTokens tokens;

  setUp(() async {
    // Initialize mock storage for tests
    FlutterSecureStorage.setMockInitialValues({});

    testClient = TestBackendClient();

    // Reset database and create test user
    final creds = await testClient.resetDatabase(createUser: true);
    credentials = creds!;

    // Login to get tokens
    tokens = await testClient.login(credentials.email, credentials.password);

    // Store tokens in secure storage
    await UserService.setTokens(tokens.accessToken, tokens.renewalToken);
  });

  testWidgets('login and access protected resource', (tester) async {
    // Create Dio instances matching the app.dart pattern
    final dio = Dio(BaseOptions(
      baseUrl: TestConfig.apiBaseUrl,
      headers: {
        'Content-Type': 'application/vnd.api+json',
        'Accept': 'application/vnd.api+json',
      },
    ));

    final renewalDio = Dio(BaseOptions(
      baseUrl: TestConfig.apiBaseUrl,
    ));

    final postRenewalDio = Dio(BaseOptions(
      baseUrl: TestConfig.apiBaseUrl,
      headers: {
        'Content-Type': 'application/vnd.api+json',
        'Accept': 'application/vnd.api+json',
      },
    ));

    dio.interceptors.add(RefreshTokenInterceptor(
      dio: dio,
      renewalDio: renewalDio,
      postRenewalDio: postRenewalDio,
    ));

    // Access a protected endpoint (session check)
    final sessionDio = Dio(BaseOptions(
      baseUrl: TestConfig.apiBaseUrl,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    sessionDio.interceptors.add(RefreshTokenInterceptor(
      dio: sessionDio,
      renewalDio: renewalDio,
      postRenewalDio: postRenewalDio,
    ));

    final response = await sessionDio.get('/fixme/session');

    expect(response.statusCode, equals(200));
    expect(response.data['data']['attributes']['email'],
        equals(credentials.email));
  });

  testWidgets('token refresh works with invalid access token + valid renewal token',
      (tester) async {
    // Invalidate the access token but keep valid renewal token
    await UserService.setTokens('invalid_access_token', tokens.renewalToken);

    // Create Dio instances matching the app.dart pattern
    final dio = Dio(BaseOptions(
      baseUrl: TestConfig.apiBaseUrl,
      headers: {
        'Content-Type': 'application/vnd.api+json',
        'Accept': 'application/vnd.api+json',
      },
    ));

    final renewalDio = Dio(BaseOptions(
      baseUrl: TestConfig.apiBaseUrl,
    ));

    final postRenewalDio = Dio(BaseOptions(
      baseUrl: TestConfig.apiBaseUrl,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    dio.interceptors.add(RefreshTokenInterceptor(
      dio: dio,
      renewalDio: renewalDio,
      postRenewalDio: postRenewalDio,
    ));

    // Access protected endpoint - should fail initially, then refresh and succeed
    final sessionDio = Dio(BaseOptions(
      baseUrl: TestConfig.apiBaseUrl,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    sessionDio.interceptors.add(RefreshTokenInterceptor(
      dio: sessionDio,
      renewalDio: renewalDio,
      postRenewalDio: postRenewalDio,
    ));

    final response = await sessionDio.get('/fixme/session');

    // The interceptor should have refreshed the token and retried
    expect(response.statusCode, equals(200));
    expect(response.data['data']['attributes']['email'],
        equals(credentials.email));

    // Verify tokens were updated
    final newAccessToken = await UserService.getAccessToken();
    final newRenewalToken = await UserService.getRenewalToken();

    expect(newAccessToken, isNot(equals('invalid_access_token')));
    expect(newAccessToken, isNotNull);
    expect(newRenewalToken, isNotNull);
  });
}
