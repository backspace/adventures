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

  testWidgets('team game: teammate submissions appear via WebSocket',
      (tester) async {
    // 1. Reset DB with team game
    final resetData =
        await testClient.resetDatabase(game: 'string_collector_team');
    final email = resetData['email'] as String;

    // 2. Login user 1, set tokens, pump widget
    final tokens1 = await testClient.login(email, resetData['password'] as String);
    await UserService.setTokens(tokens1.accessToken, tokens1.renewalToken);

    // 3. Login user 2 via API
    final user2Email = resetData['user2_email'] as String;
    final user2Password = resetData['user2_password'] as String;
    final tokens2 = await testClient.login(user2Email, user2Password);
    final dio2 = testClient.createAuthenticatedDio(tokens2.accessToken);

    // 4. User 1 launches the app
    await tester.pumpWidget(const Waydowntown());
    await waitFor(tester, find.text(email));

    // 5. User 1 taps String Collector button
    final gameButton = find.text('String\nCollector');
    await waitFor(tester, gameButton);
    await tester.ensureVisible(gameButton);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(gameButton);

    // 6. Wait for RunLaunchRoute to appear (confirms run exists + WebSocket)
    await waitFor(tester, find.text('String Collector'),
        timeout: const Duration(seconds: 120),
        failOn: find.textContaining('Error'));

    // 7. User 2 lists runs and finds the newly created run
    final runs = await testClient.listRuns(dio2);
    expect(runs, isNotEmpty, reason: 'User 2 should see at least one run');
    final runId = runs.first['id'] as String;

    // 8. User 2 joins the run
    final participation = await testClient.joinRun(dio2, runId);
    final participationId = participation['id'] as String;

    // 9. Wait for user 1 to see 2 players (broadcast_participation_update)
    await waitFor(tester, find.textContaining('2'),
        timeout: const Duration(seconds: 15));

    // 10. User 1 scrolls to and taps "I'm ready"
    await tester.scrollUntilVisible(
      find.textContaining('ready'),
      200.0,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.textContaining('ready'));

    // 11. User 2 marks ready via API
    await testClient.markReady(dio2, participationId);

    // 12. Wait for game screen (auto-start after countdown)
    await waitFor(
      tester,
      find.text('Enter a string!'),
      timeout: const Duration(seconds: 30),
    );

    // 13. User 2 submits "apple" (correct) via API
    await testClient.submitAnswer(dio2, runId, 'apple');

    // 14. User 1 should see "apple" and "Teammate" appear in timeline
    await waitFor(tester, find.text('apple'),
        timeout: const Duration(seconds: 15));
    expect(find.text('Teammate'), findsOneWidget);

    // 15. User 2 submits "banana" (correct) via API
    await testClient.submitAnswer(dio2, runId, 'banana');

    // 16. User 1 should see "banana" and two "Teammate" labels
    await waitFor(tester, find.text('banana'),
        timeout: const Duration(seconds: 15));
    expect(find.text('Teammate'), findsNWidgets(2));

    // 17. User 2 submits "cherry" (correct, triggers win)
    await testClient.submitAnswer(dio2, runId, 'cherry');

    // 18. User 1 should see Congratulations
    await waitFor(tester, find.textContaining('Congratulations'),
        timeout: const Duration(seconds: 15));

    // 19. Let confetti animation timers fire
    await tester.pump(const Duration(seconds: 1));
  });
}
