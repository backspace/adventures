import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:waydowntown/routes/team_negotiation_route.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'abc123',
      'user_id': '1',
    });

    dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    dioAdapter = DioAdapter(dio: dio);
  });

  Map<String, dynamic> buildNegotiationResponse({
    String? teamEmails,
    String? proposedTeamName,
    bool empty = true,
    bool onlyMutuals = false,
    Map<String, dynamic>? teamRelationship,
    List<Map<String, dynamic>> mutualsData = const [],
    List<Map<String, dynamic>> proposersData = const [],
    List<Map<String, dynamic>> proposeesData = const [],
    List<Map<String, dynamic>> invalidsData = const [],
    List<Map<String, dynamic>> included = const [],
  }) {
    return {
      'data': {
        'id': '1',
        'type': 'team-negotiations',
        'attributes': {
          'team_emails': teamEmails,
          'proposed_team_name': proposedTeamName,
          'risk_aversion': null,
          'empty': empty,
          'only_mutuals': onlyMutuals,
        },
        'relationships': {
          'team': {'data': teamRelationship},
          'mutuals': {'data': mutualsData},
          'proposers': {'data': proposersData},
          'proposees': {'data': proposeesData},
          'invalids': {'data': invalidsData},
        },
      },
      'included': included,
    };
  }

  testWidgets('shows empty state prompt when no team activity',
      (tester) async {
    dioAdapter.onGet(
      '/waydowntown/team-negotiation',
      (server) => server.reply(200, buildNegotiationResponse()),
    );

    await tester.pumpWidget(MaterialApp(
      home: TeamNegotiationRoute(dio: dio),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Enter email addresses below to propose team members.'),
        findsOneWidget);
    expect(find.text('Team Preferences'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('shows mutuals, proposers, proposees, and invalids',
      (tester) async {
    dioAdapter.onGet(
      '/waydowntown/team-negotiation',
      (server) => server.reply(
          200,
          buildNegotiationResponse(
            teamEmails: 'alice@example.com bob@example.com notanemail',
            empty: false,
            mutualsData: [
              {'type': 'team-members', 'id': 'alice-id'},
            ],
            proposersData: [
              {'type': 'team-members', 'id': 'carol-id'},
            ],
            proposeesData: [
              {'type': 'proposees', 'id': 'bob-email'},
            ],
            invalidsData: [
              {'type': 'invalids', 'id': 'notanemail'},
            ],
            included: [
              {
                'type': 'team-members',
                'id': 'alice-id',
                'attributes': {
                  'email': 'alice@example.com',
                  'name': 'Alice',
                  'risk_aversion': null,
                  'proposed_team_name': null,
                },
              },
              {
                'type': 'team-members',
                'id': 'carol-id',
                'attributes': {
                  'email': 'carol@example.com',
                  'name': 'Carol',
                  'risk_aversion': null,
                  'proposed_team_name': null,
                },
              },
              {
                'type': 'proposees',
                'id': 'bob-email',
                'attributes': {
                  'email': 'bob@example.com',
                  'invited': false,
                  'registered': true,
                },
              },
              {
                'type': 'invalids',
                'id': 'notanemail',
                'attributes': {
                  'value': 'notanemail',
                },
              },
            ],
          )),
    );

    await tester.pumpWidget(MaterialApp(
      home: TeamNegotiationRoute(dio: dio),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Team Status'), findsOneWidget);

    // Mutuals
    expect(find.text('Confirmed Team Members'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);

    // Proposers
    expect(find.text('Want to Team With You'), findsOneWidget);
    expect(find.text('Carol'), findsOneWidget);

    // Proposees
    expect(find.text('Waiting for Confirmation'), findsOneWidget);
    expect(find.text('bob@example.com'), findsOneWidget);
    expect(find.text('Registered'), findsOneWidget);

    // Invalids
    expect(find.text('Invalid Entries'), findsOneWidget);
    expect(find.text('notanemail'), findsOneWidget);
  });

  testWidgets('tapping a proposer adds their email to the form',
      (tester) async {
    dioAdapter.onGet(
      '/waydowntown/team-negotiation',
      (server) => server.reply(
          200,
          buildNegotiationResponse(
            empty: false,
            proposersData: [
              {'type': 'team-members', 'id': 'carol-id'},
            ],
            included: [
              {
                'type': 'team-members',
                'id': 'carol-id',
                'attributes': {
                  'email': 'carol@example.com',
                  'name': 'Carol',
                  'risk_aversion': null,
                  'proposed_team_name': null,
                },
              },
            ],
          )),
    );

    await tester.pumpWidget(MaterialApp(
      home: TeamNegotiationRoute(dio: dio),
    ));
    await tester.pumpAndSettle();

    // The proposer name is tappable
    await tester.tap(find.text('Carol'));
    await tester.pumpAndSettle();

    // The emails text field should now contain the proposer's email
    final emailsField = find.byWidgetPredicate((widget) =>
        widget is TextFormField &&
        widget.controller?.text == 'carol@example.com');
    expect(emailsField, findsOneWidget);
  });

  testWidgets('shows assigned team details when team exists', (tester) async {
    dioAdapter.onGet(
      '/waydowntown/team-negotiation',
      (server) => server.reply(
          200,
          buildNegotiationResponse(
            empty: false,
            onlyMutuals: true,
            teamRelationship: {'type': 'teams', 'id': 'team-1'},
            included: [
              {
                'type': 'teams',
                'id': 'team-1',
                'attributes': {
                  'name': 'The Explorers',
                  'notes': 'Ready to go!',
                  'risk_aversion': null,
                },
                'relationships': {
                  'members': {
                    'data': [
                      {'type': 'team-members', 'id': 'member-1'},
                      {'type': 'team-members', 'id': 'member-2'},
                    ],
                  },
                },
              },
              {
                'type': 'team-members',
                'id': 'member-1',
                'attributes': {
                  'email': 'alice@example.com',
                  'name': 'Alice',
                  'risk_aversion': null,
                  'proposed_team_name': null,
                },
              },
              {
                'type': 'team-members',
                'id': 'member-2',
                'attributes': {
                  'email': 'bob@example.com',
                  'name': null,
                  'risk_aversion': null,
                  'proposed_team_name': null,
                },
              },
            ],
          )),
    );

    await tester.pumpWidget(MaterialApp(
      home: TeamNegotiationRoute(dio: dio),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Your Team'), findsOneWidget);
    expect(find.text('The Explorers'), findsOneWidget);
    expect(find.text('Ready to go!'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    // Member without name shows email as title
    expect(find.text('bob@example.com'), findsOneWidget);
  });

  testWidgets('saving team preferences calls API and refreshes',
      (tester) async {
    dioAdapter.onGet(
      '/waydowntown/team-negotiation',
      (server) => server.reply(200, buildNegotiationResponse()),
    );

    dioAdapter.onPost(
      '/fixme/me',
      (server) => server.reply(200, {
        'data': {
          'id': '1',
          'attributes': {
            'email': 'test@example.com',
            'name': 'Test User',
          }
        }
      }),
      data: {
        'data': {
          'type': 'users',
          'id': '1',
          'attributes': {
            'team_emails': 'alice@example.com',
            'proposed_team_name': 'My Team',
          }
        }
      },
      headers: {
        'Accept': 'application/vnd.api+json',
        'Content-Type': 'application/vnd.api+json',
      },
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TeamNegotiationRoute(dio: dio)),
    ));
    await tester.pumpAndSettle();

    // Enter team emails
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Team member emails'),
      'alice@example.com',
    );

    // Enter proposed team name
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Proposed team name'),
      'My Team',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Should show success snackbar
    expect(find.text('Team preferences saved'), findsOneWidget);
  });

  testWidgets('shows error state with retry button', (tester) async {
    dioAdapter.onGet(
      '/waydowntown/team-negotiation',
      (server) => server.throws(
        500,
        DioException(
          requestOptions: RequestOptions(path: '/waydowntown/team-negotiation'),
          message: 'Server error',
        ),
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: TeamNegotiationRoute(dio: dio),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Error'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
