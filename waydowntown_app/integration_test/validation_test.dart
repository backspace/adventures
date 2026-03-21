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

  testWidgets(
      'validator flow: add comment, verify it persists, add another, see both',
      (tester) async {
    // 1. Reset DB with validation game data
    final resetData = await testClient.resetDatabase(game: 'validation');
    final validatorEmail = resetData['validator_email'] as String;
    final validatorPassword = resetData['validator_password'] as String;
    final validationId = resetData['validation_id'] as String;

    // 2. Start validation via API (skip UI for play mode selection)
    final validatorTokens =
        await testClient.login(validatorEmail, validatorPassword);
    final validatorDio =
        testClient.createAuthenticatedDio(validatorTokens.accessToken);

    await validatorDio.patch(
      '/waydowntown/specification-validations/$validationId',
      data: {
        'data': {
          'type': 'specification-validations',
          'id': validationId,
          'attributes': {
            'status': 'in_progress',
            'play_mode': 'with_answers',
          },
        }
      },
    );

    // 3. Add a comment via API so we can verify it's visible in UI
    final answerId = (resetData['answer_ids'] as List<dynamic>).first;
    await validatorDio.post(
      '/waydowntown/validation-comments',
      data: {
        'data': {
          'type': 'validation-comments',
          'attributes': {
            'comment': 'First API comment',
            'field': 'answer',
          },
          'relationships': {
            'specification-validation': {
              'data': {
                'type': 'specification-validations',
                'id': validationId,
              }
            },
            'answer': {
              'data': {
                'type': 'answers',
                'id': answerId,
              }
            },
          },
        }
      },
    );

    // 4. Login and launch app
    await UserService.setTokens(
        validatorTokens.accessToken, validatorTokens.renewalToken);
    await tester.pumpWidget(const Waydowntown());
    await waitFor(tester, find.text(validatorEmail));

    // 5. Navigate to My Validations
    final validateButton = find.text('Validate');
    await waitFor(tester, validateButton);
    await tester.tap(validateButton);

    await waitFor(tester, find.text('My Validations'));
    await waitFor(tester, find.text('in progress'));

    // 6. Open the validation detail
    await tester.tap(find.text('string_collector'));
    await waitFor(tester, find.text('in progress'));
    await waitFor(tester, find.text('Answers'));

    // 7. Verify existing comment badge is shown (from API comment)
    await waitFor(tester, find.byIcon(Icons.comment),
        timeout: const Duration(seconds: 10));

    // 8. Expand the first answer card to see existing comment
    final expandButtons = find.byIcon(Icons.expand_more);
    await waitFor(tester, expandButtons);
    await tester.tap(expandButtons.first);
    await tester.pumpAndSettle();

    // 9. Verify the API-created comment is visible
    await waitFor(tester, find.text('First API comment'));

    // 10. Add a second comment through UI
    final commentField = find.widgetWithText(TextField, 'Comment');
    await tester.scrollUntilVisible(
      commentField,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(commentField, 'Second UI comment');

    final addCommentButton = find.text('Add Comment');
    await tester.scrollUntilVisible(
      addCommentButton,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(addCommentButton);

    // 11. Wait for refresh and verify both comments are visible
    await waitFor(tester, find.text('Second UI comment'),
        timeout: const Duration(seconds: 10));
    // Re-expand if needed (refresh may collapse)
    if (find.text('First API comment').evaluate().isEmpty) {
      final expandBtns = find.byIcon(Icons.expand_more);
      if (expandBtns.evaluate().isNotEmpty) {
        await tester.tap(expandBtns.first);
        await tester.pumpAndSettle();
      }
    }
    await waitFor(tester, find.text('First API comment'));

    // 12. Submit the validation
    final notesField = find.widgetWithText(TextField,
        'Add overall notes about this specification...');
    await tester.scrollUntilVisible(
      notesField,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(notesField, 'Spec works but needs tweaks');

    final submitButton = find.text('Submit Validation');
    await tester.scrollUntilVisible(
      submitButton,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(submitButton);

    await waitFor(tester, find.text('submitted'));
  });

  testWidgets('multiple validations per spec: validator sees all assignments',
      (tester) async {
    // 1. Reset DB
    final resetData = await testClient.resetDatabase(game: 'validation');
    final validatorEmail = resetData['validator_email'] as String;
    final validatorPassword = resetData['validator_password'] as String;
    final validatorId = resetData['validator_id'] as String;
    final supervisorId = resetData['supervisor_id'] as String;
    final specificationId = resetData['specification_id'] as String;
    final validationId = resetData['validation_id'] as String;

    // 2. Submit the first validation via API
    final validatorTokens =
        await testClient.login(validatorEmail, validatorPassword);
    final validatorDio =
        testClient.createAuthenticatedDio(validatorTokens.accessToken);

    await validatorDio.patch(
      '/waydowntown/specification-validations/$validationId',
      data: {
        'data': {
          'type': 'specification-validations',
          'id': validationId,
          'attributes': {
            'status': 'in_progress',
            'play_mode': 'without_answers',
          },
        }
      },
    );
    await validatorDio.patch(
      '/waydowntown/specification-validations/$validationId',
      data: {
        'data': {
          'type': 'specification-validations',
          'id': validationId,
          'attributes': {
            'status': 'submitted',
            'overall_notes': 'First round of validation',
          },
        }
      },
    );

    // 3. Supervisor creates a second validation for the same spec + validator
    final supervisorTokens =
        await testClient.login(resetData['supervisor_email'], resetData['supervisor_password']);
    final supervisorDio =
        testClient.createAuthenticatedDio(supervisorTokens.accessToken);

    await supervisorDio.post(
      '/waydowntown/specification-validations',
      data: {
        'data': {
          'type': 'specification-validations',
          'attributes': {},
          'relationships': {
            'specification': {
              'data': {
                'type': 'specifications',
                'id': specificationId,
              }
            },
            'validator': {
              'data': {
                'type': 'users',
                'id': validatorId,
              }
            },
          },
        }
      },
    );

    // 4. Login as validator and launch app
    await UserService.setTokens(
        validatorTokens.accessToken, validatorTokens.renewalToken);
    await tester.pumpWidget(const Waydowntown());
    await waitFor(tester, find.text(validatorEmail));

    // 5. Navigate to My Validations
    final validateButton = find.text('Validate');
    await waitFor(tester, validateButton);
    await tester.tap(validateButton);

    await waitFor(tester, find.text('My Validations'));

    // 6. Verify both validations are shown (one submitted, one assigned)
    await waitFor(tester, find.text('submitted'));
    await waitFor(tester, find.text('assigned'));
  });

  testWidgets('in-game annotation: validator can add notes during gameplay',
      (tester) async {
    // 1. Reset DB
    final resetData = await testClient.resetDatabase(game: 'validation');
    final validatorEmail = resetData['validator_email'] as String;
    final validatorPassword = resetData['validator_password'] as String;
    final validationId = resetData['validation_id'] as String;

    // 2. Start validation via API
    final validatorTokens =
        await testClient.login(validatorEmail, validatorPassword);
    final validatorDio =
        testClient.createAuthenticatedDio(validatorTokens.accessToken);

    await validatorDio.patch(
      '/waydowntown/specification-validations/$validationId',
      data: {
        'data': {
          'type': 'specification-validations',
          'id': validationId,
          'attributes': {
            'status': 'in_progress',
            'play_mode': 'with_answers',
          },
        }
      },
    );

    // 3. Login and launch app
    await UserService.setTokens(
        validatorTokens.accessToken, validatorTokens.renewalToken);
    await tester.pumpWidget(const Waydowntown());
    await waitFor(tester, find.text(validatorEmail));

    // 4. Navigate to validation detail
    final validateButton = find.text('Validate');
    await waitFor(tester, validateButton);
    await tester.tap(validateButton);

    await waitFor(tester, find.text('My Validations'));
    await tester.tap(find.text('string_collector'));
    await waitFor(tester, find.text('Play Specification'));

    // 5. Tap Play Specification to enter the game
    await tester.tap(find.text('Play Specification'));

    // 6. Wait for RunLaunchRoute (game instructions screen)
    await waitFor(tester, find.text('String Collector'),
        timeout: const Duration(seconds: 120),
        failOn: find.textContaining('Error'));

    // 7. Tap ready to start the game
    await tester.scrollUntilVisible(
      find.textContaining('ready'),
      200.0,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.textContaining('ready'));

    // 8. Wait for game widget to load
    await waitFor(
      tester,
      find.text('Enter a string!'),
      timeout: const Duration(seconds: 30),
    );

    // 9. Verify the annotation FAB is present
    await waitFor(tester, find.byIcon(Icons.edit_note));

    // 10. Tap the annotation FAB to open the notes sheet
    await tester.tap(find.byIcon(Icons.edit_note));
    await tester.pumpAndSettle();

    // 11. Verify the annotation sheet is shown
    await waitFor(tester, find.text('Validation Notes'));

    // 12. Add a note
    final noteField = find.widgetWithText(TextField, 'Add a note...');
    await tester.enterText(noteField, 'Apple answer seems wrong');

    await tester.tap(find.byIcon(Icons.send));

    // 13. Verify note was saved (snackbar appears)
    await waitFor(tester, find.text('Note saved'),
        timeout: const Duration(seconds: 10));

    // 14. Verify note appears in the list
    await waitFor(tester, find.text('Apple answer seems wrong'));

    // 15. Close the bottom sheet and go back to game
    await tester.tapAt(const Offset(100, 50));
    await tester.pumpAndSettle();

    // 16. Let timers settle
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
      'supervisor flow: see unvalidated specs with creator, review and accept',
      (tester) async {
    // 1. Reset DB with validation game data
    final resetData = await testClient.resetDatabase(game: 'validation');
    final validatorEmail = resetData['validator_email'] as String;
    final validatorPassword = resetData['validator_password'] as String;
    final supervisorEmail = resetData['supervisor_email'] as String;
    final supervisorPassword = resetData['supervisor_password'] as String;

    // 2. Submit the validation via API so the supervisor can review it
    final validatorTokens =
        await testClient.login(validatorEmail, validatorPassword);
    final validatorDio =
        testClient.createAuthenticatedDio(validatorTokens.accessToken);

    final validationId = resetData['validation_id'] as String;
    await validatorDio.patch(
      '/waydowntown/specification-validations/$validationId',
      data: {
        'data': {
          'type': 'specification-validations',
          'id': validationId,
          'attributes': {
            'status': 'in_progress',
            'play_mode': 'without_answers',
          },
        }
      },
    );
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

    // 3. Login as supervisor
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

    // 6. Wait for Supervisor Dashboard — starts on Unvalidated tab
    await waitFor(tester, find.text('Supervisor Dashboard'));

    // 7. Verify the Unvalidated tab shows specs with creator name
    await waitFor(tester, find.textContaining('Test User'));

    // 8. Tap "Pending Review" tab to see the submitted validation
    final pendingTab = find.textContaining('Pending Review');
    await waitFor(tester, pendingTab);
    await tester.tap(pendingTab);
    await tester.pumpAndSettle();

    // 9. Should see the submitted validation
    await waitFor(tester, find.text('String Collector'));

    // 10. Tap to review
    await tester.tap(find.text('String Collector'));

    // 11. Wait for review screen
    await waitFor(tester, find.text('Review Validation'));
    await waitFor(tester, find.text('submitted'));

    // 12. Verify validator's notes are shown
    await waitFor(tester, find.text('Looks good overall'));

    // 13. Accept the validation
    final acceptButton = find.text('Accept');
    await tester.scrollUntilVisible(
      acceptButton,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(acceptButton);

    // 14. Verify status changes to accepted
    await waitFor(tester, find.text('accepted'));
  });
}
