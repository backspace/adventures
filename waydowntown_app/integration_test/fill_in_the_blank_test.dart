import 'package:flutter/material.dart';
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

  testWidgets('fill_in_the_blank: play complete game through UI',
      (tester) async {
    final resetData =
        await testClient.resetDatabase(game: 'fill_in_the_blank');
    final email = resetData['email'] as String;
    final tokens = await testClient.login(
      email,
      resetData['password'] as String,
    );
    await UserService.setTokens(tokens.accessToken, tokens.renewalToken);

    await tester.pumpWidget(const Waydowntown());

    // Wait for session check to complete
    await waitFor(tester, find.text(email));

    // Scroll to and tap the game button on the home screen
    final gameButton = find.text('Fill in the\nBlank');
    await tester.ensureVisible(gameButton);
    await tester.tap(gameButton);

    // Wait for run creation and RunLaunchRoute to appear
    await waitFor(tester, find.textContaining('ready'));

    // Tap the ready button to start the game
    await tester.tap(find.textContaining('ready'));

    // Wait for WebSocket countdown (~5s) and navigation to game widget.
    // The answer label appears once we're in the game.
    await waitFor(
      tester,
      find.text('The answer is ____'),
      timeout: const Duration(seconds: 15),
    );

    // Submit a wrong answer
    await tester.enterText(find.byType(TextFormField), 'wrong');
    await tester.tap(find.text('Submit'));
    await waitFor(tester, find.text('Wrong'));

    // Submit the correct answer
    await tester.enterText(find.byType(TextFormField), 'correct');
    await tester.tap(find.text('Submit'));
    await waitFor(tester, find.textContaining('Congratulations'));
  });
}
