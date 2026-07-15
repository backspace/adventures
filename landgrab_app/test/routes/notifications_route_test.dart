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
}

LandgrabNotification _notification({
  String id = 'n1',
  String type = 'attack',
  String body = 'qfabrv scanned 2066297',
  DateTime? readAt,
}) =>
    LandgrabNotification(
      id: id,
      type: type,
      recipientTeamId: 't1',
      senderTeamId: 't2',
      body: body,
      metadata: const {},
      insertedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      readAt: readAt,
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
}
