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

  testWidgets('string_collector: collect all items to win', (tester) async {
    final resetData =
        await testClient.resetDatabase(game: 'string_collector');
    final email = resetData['email'] as String;
    final tokens = await testClient.login(
      email,
      resetData['password'] as String,
    );
    await UserService.setTokens(tokens.accessToken, tokens.renewalToken);

    await tester.pumpWidget(const Waydowntown());
    await waitFor(tester, find.text(email));

    // Scroll to and tap the game button
    final gameButton = find.text('String\nCollector');
    await waitFor(tester, gameButton);
    await tester.ensureVisible(gameButton);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(gameButton);

    // Wait for run creation and RunLaunchRoute to appear
    // WebSocket connection can be slow on CI emulators without hardware acceleration
    await waitFor(tester, find.text('String Collector'),
        timeout: const Duration(seconds: 120),
        failOn: find.textContaining('Error'));

    // The ready button may be below the viewport on small screens due to
    // Instructions, Players, Starting point, Goal, Duration, and Location cards.
    // Use scrollUntilVisible to scroll the ListView until the button appears.
    await tester.scrollUntilVisible(
      find.textContaining('ready'),
      200.0,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.textContaining('ready'));

    // Wait for countdown and navigation to game
    await waitFor(
      tester,
      find.text('Enter a string!'),
      timeout: const Duration(seconds: 30),
    );

    // Verify initial progress shows 0/3
    expect(find.text('0/3'), findsOneWidget);

    // Submit first item
    await tester.enterText(find.byType(TextField), 'apple');
    await tester.tap(find.text('Submit'));
    await waitFor(tester, find.text('1/3'));

    // Submit second item
    await tester.enterText(find.byType(TextField), 'banana');
    await tester.tap(find.text('Submit'));
    await waitFor(tester, find.text('2/3'));

    // Submit third item - should win
    await tester.enterText(find.byType(TextField), 'cherry');
    await tester.tap(find.text('Submit'));
    await waitFor(tester, find.textContaining('Congratulations'));

    // Let confetti animation timers fire while widget tree is still alive
    await tester.pump(const Duration(seconds: 1));
  });
}
