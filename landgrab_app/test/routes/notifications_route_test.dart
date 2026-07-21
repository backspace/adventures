import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/l10n/player_strings.dart';
import 'package:landgrab/models/notification.dart';
import 'package:landgrab/routes/notifications_route.dart';

class _FakeApi extends LandgrabApi {
  _FakeApi() : super(Dio(BaseOptions(baseUrl: 'http://test.invalid')));

  NotificationsResult result = (notifications: [], unread: 0);
  int markReadCalls = 0;
  final List<({String id, bool read})> toggles = [];

  @override
  Future<NotificationsResult> listNotifications() async => result;

  @override
  Future<void> markNotificationsRead() async {
    markReadCalls += 1;
  }

  @override
  Future<void> setNotificationRead(String id, bool read) async {
    toggles.add((id: id, read: read));
  }

  // What respondToNotification returns — set to something other than
  // the sent response to simulate a teammate having answered first.
  String? respondResult;
  final List<({String id, String response})> responses = [];

  @override
  Future<String> respondToNotification(String id, String response) async {
    responses.add((id: id, response: response));
    return respondResult ?? response;
  }
}

LandgrabNotification _notification({
  String id = 'n1',
  String type = 'attack',
  String body = 'qfabrv scanned 2066297',
  DateTime? readAt,
  Map<String, dynamic> metadata = const {},
  String? response,
}) =>
    LandgrabNotification(
      id: id,
      type: type,
      recipientTeamId: 't1',
      senderTeamId: 't2',
      body: body,
      metadata: metadata,
      insertedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      readAt: readAt,
      response: response,
    );

Future<void> _pump(WidgetTester tester, _FakeApi api) async {
  await tester.pumpWidget(MaterialApp(home: NotificationsRoute(api: api)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the empty message when there is no history',
      (tester) async {
    final api = _FakeApi();
    await _pump(tester, api);

    expect(find.text(NotificationStrings.empty), findsOneWidget);
    expect(api.markReadCalls, 0);
  });

  testWidgets('lists notifications and marks unread ones read', (tester) async {
    final api = _FakeApi()
      ..result = (
        notifications: [
          _notification(),
          _notification(
            id: 'n2',
            type: 'pole_lost',
            body: 'qfabrv captured 2066297 from you',
            readAt: DateTime.now().toUtc(),
          ),
        ],
        unread: 1,
      );
    await _pump(tester, api);

    expect(find.text('qfabrv scanned 2066297'), findsOneWidget);
    expect(find.text('qfabrv captured 2066297 from you'), findsOneWidget);
    expect(find.text(NotificationStrings.minutesAgo(5)), findsNWidgets(2));
    expect(api.markReadCalls, 1);
  });

  testWidgets('does not mark read when everything is already read',
      (tester) async {
    final api = _FakeApi()
      ..result = (
        notifications: [_notification(readAt: DateTime.now().toUtc())],
        unread: 0,
      );
    await _pump(tester, api);

    expect(api.markReadCalls, 0);
  });

  testWidgets('swiping a read notification marks it unread', (tester) async {
    final api = _FakeApi()
      ..result = (
        notifications: [_notification(readAt: DateTime.now().toUtc())],
        unread: 0,
      );
    await _pump(tester, api);

    await tester.drag(
        find.text('qfabrv scanned 2066297'), const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(api.toggles, hasLength(1));
    expect(api.toggles.first.id, 'n1');
    expect(api.toggles.first.read, isFalse);
  });

  testWidgets('no "View on map" when the notification points at no stake',
      (tester) async {
    final api = _FakeApi()
      ..result = (notifications: [_notification()], unread: 0);
    await _pump(tester, api);

    expect(find.text(NotificationStrings.viewOnMap), findsNothing);
  });

  testWidgets('"View on map" pops with the stake id for a stake notification',
      (tester) async {
    final api = _FakeApi()
      ..result = (
        notifications: [_notification(metadata: const {'pole_id': 'p1'})],
        unread: 0,
      );

    String? popped;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<String>(
                  MaterialPageRoute(builder: (_) => NotificationsRoute(api: api)),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(NotificationStrings.viewOnMap), findsOneWidget);

    await tester.tap(find.text(NotificationStrings.viewOnMap));
    await tester.pumpAndSettle();

    expect(popped, 'p1');
  });

  LandgrabNotification invite({String? response}) => _notification(
        id: 'inv1',
        type: 'liberation_invite',
        body: 'Will you join me?',
        readAt: DateTime.now().toUtc(),
        response: response,
      );

  testWidgets('an unanswered invite offers accept and decline',
      (tester) async {
    final api = _FakeApi()..result = (notifications: [invite()], unread: 0);
    await _pump(tester, api);

    expect(find.text(NotificationStrings.inviteAccept), findsOneWidget);
    expect(find.text(NotificationStrings.inviteDecline), findsOneWidget);
  });

  testWidgets('accepting records the answer and shows the answered state',
      (tester) async {
    final api = _FakeApi()..result = (notifications: [invite()], unread: 0);
    await _pump(tester, api);

    await tester.tap(find.text(NotificationStrings.inviteAccept));
    await tester.pumpAndSettle();

    expect(api.responses, hasLength(1));
    expect(api.responses.first.id, 'inv1');
    expect(api.responses.first.response, 'accepted');
    expect(find.text(NotificationStrings.inviteAccept), findsNothing);
    expect(find.text(NotificationStrings.inviteAccepted), findsOneWidget);
  });

  testWidgets('declining shows the declined state', (tester) async {
    final api = _FakeApi()..result = (notifications: [invite()], unread: 0);
    await _pump(tester, api);

    await tester.tap(find.text(NotificationStrings.inviteDecline));
    await tester.pumpAndSettle();

    expect(api.responses.first.response, 'declined');
    expect(find.text(NotificationStrings.inviteDeclined), findsOneWidget);
  });

  testWidgets('a teammate answering first wins and is surfaced',
      (tester) async {
    // The API resolves the server's 409 to the recorded answer; the tile
    // should show THAT, not what was tapped, plus an explanatory toast.
    final api = _FakeApi()
      ..result = (notifications: [invite()], unread: 0)
      ..respondResult = 'declined';
    await _pump(tester, api);

    await tester.tap(find.text(NotificationStrings.inviteAccept));
    await tester.pumpAndSettle();

    expect(find.text(NotificationStrings.inviteDeclined), findsOneWidget);
    expect(
        find.text(NotificationStrings.inviteAlreadyAnswered), findsOneWidget);
  });

  testWidgets('an answered invite shows no buttons', (tester) async {
    final api = _FakeApi()
      ..result = (notifications: [invite(response: 'accepted')], unread: 0);
    await _pump(tester, api);

    expect(find.text(NotificationStrings.inviteAccept), findsNothing);
    expect(find.text(NotificationStrings.inviteDecline), findsNothing);
    expect(find.text(NotificationStrings.inviteAccepted), findsOneWidget);
  });
}
