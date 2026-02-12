import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/services/user_service.dart';

import 'helpers.dart';
import 'test_backend_client.dart';
import 'test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestBackendClient testClient;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    dotenv.testLoad(fileInput: 'API_ROOT=${TestConfig.apiBaseUrl}');
    testClient = TestBackendClient();
  });

  testWidgets('refreshes expired token and shows user email', (tester) async {
    final resetData = await testClient.resetDatabase();
    final email = resetData['email'] as String;
    final tokens = await testClient.login(
      email,
      resetData['password'] as String,
    );

    // Store an invalid access token with a valid renewal token.
    // When SessionWidget checks the session, it will get a 401,
    // the RefreshTokenInterceptor will use the renewal token to get
    // a fresh access token, and retry the request.
    await UserService.setTokens('expired_invalid_token', tokens.renewalToken);

    await tester.pumpWidget(const Waydowntown());

    await waitFor(tester, find.text(email));
  });
}
