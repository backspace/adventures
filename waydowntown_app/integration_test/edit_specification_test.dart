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

  testWidgets('edit specification: add and modify string_collector answers',
      (tester) async {
    // 1. Reset DB with string_collector game (creator_id set to test user)
    final resetData =
        await testClient.resetDatabase(game: 'string_collector');
    final email = resetData['email'] as String;

    // 2. Login and set tokens
    final tokens =
        await testClient.login(email, resetData['password'] as String);
    await UserService.setTokens(tokens.accessToken, tokens.renewalToken);

    // 3. Launch app
    await tester.pumpWidget(const Waydowntown());
    await waitFor(tester, find.text(email));

    // 4. Navigate to My specifications
    final mySpecsButton = find.text('My specifications');
    await tester.ensureVisible(mySpecsButton);
    await tester.tap(mySpecsButton);

    // 5. Wait for specifications table to load
    await waitFor(tester, find.text('My Specifications'),
        timeout: const Duration(seconds: 15));
    await waitFor(tester, find.text('3'),
        timeout: const Duration(seconds: 15));

    // 6. Tap edit button on the specification
    final editButton = find.byIcon(Icons.edit);
    await waitFor(tester, editButton);
    await tester.scrollUntilVisible(
      editButton,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(editButton);

    // 7. Wait for edit screen to load
    await waitFor(tester, find.text('Edit Specification'),
        timeout: const Duration(seconds: 15));

    // 8. Verify existing answers are loaded
    await waitFor(tester, find.byKey(const Key('answer-card-0')));
    expect(find.byKey(const Key('answer-card-1')), findsOneWidget);
    expect(find.byKey(const Key('answer-card-2')), findsOneWidget);

    // 9. Scroll down and add a new answer
    final addButton = find.byKey(const Key('add-answer'));
    await tester.scrollUntilVisible(
      addButton,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    // 10. Fill in the new answer
    final newAnswerField = find.byKey(const Key('answer-text-3'));
    await tester.scrollUntilVisible(
      newAnswerField,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(newAnswerField, 'dragonfruit');

    // 11. Add a hint for the new answer
    final newHintField = find.byKey(const Key('answer-hint-3'));
    await tester.scrollUntilVisible(
      newHintField,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(newHintField, 'near the exit');

    // 12. Save
    final saveButton = find.text('Save');
    await tester.scrollUntilVisible(
      saveButton,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(saveButton);

    // 13. Should return to specifications table with updated answer count
    await waitFor(tester, find.text('My Specifications'),
        timeout: const Duration(seconds: 15));
    await waitFor(tester, find.text('4'),
        timeout: const Duration(seconds: 15));

    // 14. Re-open edit to verify the new answer persisted
    final editButton2 = find.byIcon(Icons.edit);
    await waitFor(tester, editButton2);
    await tester.scrollUntilVisible(
      editButton2,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(editButton2);
    await waitFor(tester, find.text('Edit Specification'),
        timeout: const Duration(seconds: 15));

    // 15. Verify all 4 answers are present
    await waitFor(tester, find.byKey(const Key('answer-card-3')));

    // 16. Scroll down to verify the new answer's text
    final answerField3 = find.byKey(const Key('answer-text-3'));
    await tester.scrollUntilVisible(
      answerField3,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );

    final answerTextField =
        tester.widget<TextField>(answerField3);
    expect(answerTextField.controller!.text, equals('dragonfruit'));
  });
}
