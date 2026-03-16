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

  testWidgets('validator flow: view assignment, start, add comment, submit',
      (tester) async {
    // 1. Reset DB with validation game data
    final resetData = await testClient.resetDatabase(game: 'validation');
    final validatorEmail = resetData['validator_email'] as String;
    final validatorPassword = resetData['validator_password'] as String;

    // 2. Login as validator and set tokens
    final tokens = await testClient.login(validatorEmail, validatorPassword);
    await UserService.setTokens(tokens.accessToken, tokens.renewalToken);

    // 3. Launch app
    await tester.pumpWidget(const Waydowntown());
    await waitFor(tester, find.text(validatorEmail));

    // 4. Tap Validate button (visible because user has validator role)
    final validateButton = find.text('Validate');
    await waitFor(tester, validateButton);
    await tester.tap(validateButton);

    // 5. Wait for My Validations screen with the assignment
    await waitFor(tester, find.text('My Validations'));
    await waitFor(tester, find.text('assigned'));

    // 6. Tap the assignment to open detail
    await tester.tap(find.text('string_collector'));

    // 7. Wait for validation detail screen
    await waitFor(tester, find.text('Play Mode'));

    // 8. Select "Play with answers" mode
    await tester.tap(find.text('Play with answers'));
    await tester.pumpAndSettle();

    // 9. Tap "Start Validation" to move to in_progress
    final startButton = find.text('Start Validation');
    await tester.scrollUntilVisible(
      startButton,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(startButton);

    // 10. Wait for status to update to in_progress
    await waitFor(tester, find.text('in progress'));

    // 11. Verify answer cards are shown
    await waitFor(tester, find.text('Answers'));

    // 12. Expand first answer card to add a comment
    final expandButtons = find.byIcon(Icons.expand_more);
    await waitFor(tester, expandButtons);
    await tester.tap(expandButtons.first);
    await tester.pumpAndSettle();

    // 13. Enter a comment
    final commentField = find.widgetWithText(TextField, 'Comment');
    await tester.scrollUntilVisible(
      commentField,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(commentField, 'This answer needs clarification');

    // 14. Enter a suggested value
    final suggestedField = find.widgetWithText(TextField, 'Suggested value');
    await tester.scrollUntilVisible(
      suggestedField,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(suggestedField, 'green apple');

    // 15. Save the comment
    final addCommentButton = find.text('Add Comment');
    await tester.scrollUntilVisible(
      addCommentButton,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(addCommentButton);

    // 16. Wait for comment badge to appear (indicates save succeeded)
    await waitFor(tester, find.byIcon(Icons.comment),
        timeout: const Duration(seconds: 10));

    // 17. Add overall notes
    final notesField = find.widgetWithText(TextField,
        'Add overall notes about this specification...');
    await tester.scrollUntilVisible(
      notesField,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(notesField, 'Spec works but needs tweaks');

    // 18. Submit the validation
    final submitButton = find.text('Submit Validation');
    await tester.scrollUntilVisible(
      submitButton,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(submitButton);

    // 19. Wait for status to change to submitted
    await waitFor(tester, find.text('submitted'));
  });

  testWidgets('supervisor flow: view submitted validation, accept it',
      (tester) async {
    // 1. Reset DB with validation game data
    final resetData = await testClient.resetDatabase(game: 'validation');
    final validatorEmail = resetData['validator_email'] as String;
    final validatorPassword = resetData['validator_password'] as String;
    final supervisorEmail = resetData['supervisor_email'] as String;
    final supervisorPassword = resetData['supervisor_password'] as String;

    // 2. First, login as validator and submit the validation
    final validatorTokens =
        await testClient.login(validatorEmail, validatorPassword);
    final validatorDio =
        testClient.createAuthenticatedDio(validatorTokens.accessToken);

    // Move validation to in_progress
    final validationId = resetData['validation_id'] as String;
    await validatorDio.patch(
      '/waydowntown/specification-validations/$validationId',
      data: {
        'data': {
          'type': 'specification-validations',
          'id': validationId,
          'attributes': {
            'status': 'in_progress',
            'play_mode': 'blind',
          },
        }
      },
    );

    // Submit validation with notes
    await validatorDio.patch(
      '/waydowntown/specification-validations/$validationId',
      data: {
        'data': {
          'type': 'specification-validations',
          'id': validationId,
          'attributes': {
            'status': 'submitted',
            'overall_notes': 'Looks good overall',
          },
        }
      },
    );

    // 3. Now login as supervisor
    final supervisorTokens =
        await testClient.login(supervisorEmail, supervisorPassword);
    await UserService.setTokens(
        supervisorTokens.accessToken, supervisorTokens.renewalToken);

    // 4. Launch app
    await tester.pumpWidget(const Waydowntown());
    await waitFor(tester, find.text(supervisorEmail));

    // 5. Tap Supervise button
    final superviseButton = find.text('Supervise');
    await waitFor(tester, superviseButton);
    await tester.tap(superviseButton);

    // 6. Wait for Supervisor Dashboard
    await waitFor(tester, find.text('Supervisor Dashboard'));

    // 7. The "Pending Review" tab should show the submitted validation
    await waitFor(tester, find.text('string_collector'));

    // 8. Tap to review
    await tester.tap(find.text('string_collector'));

    // 9. Wait for review screen
    await waitFor(tester, find.text('Review Validation'));
    await waitFor(tester, find.text('submitted'));

    // 10. Verify validator's notes are shown
    await waitFor(tester, find.text('Looks good overall'));

    // 11. Accept the validation
    final acceptButton = find.text('Accept');
    await tester.scrollUntilVisible(
      acceptButton,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(acceptButton);

    // 12. Verify status changes to accepted
    await waitFor(tester, find.text('accepted'));
  });
}
