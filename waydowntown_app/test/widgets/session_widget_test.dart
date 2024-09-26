import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waydowntown/widgets/session_widget.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;

  setUp(() {
    dio = Dio(BaseOptions());
    dio.interceptors.add(PrettyDioLogger());
    dioAdapter = DioAdapter(dio: dio);
  });

  testWidgets('SessionWidget shows login button when not logged in',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(MaterialApp(
      home: SessionWidget(dio: dio, apiBaseUrl: 'https://example.com'),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('SessionWidget shows email and logout button when logged in',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'abc123',
    });

    dioAdapter.onGet(
      'https://example.com/fixme/session',
      (server) => server.reply(200, {
        'data': {
          'attributes': {'email': 'test@example.com'}
        }
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: SessionWidget(dio: dio, apiBaseUrl: 'https://example.com'),
    ));

    await tester.pumpAndSettle();

    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);
    expect(find.text('Log in'), findsNothing);
  });

  testWidgets('Logout button clears cookie and shows login button',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'abc123',
    });
    dioAdapter.onGet(
      'https://example.com/fixme/session',
      (server) => server.reply(200, {
        'data': {
          'attributes': {'email': 'test@example.com'}
        }
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: SessionWidget(dio: dio, apiBaseUrl: 'https://example.com'),
    ));

    await tester.pumpAndSettle();

    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);

    expect(find.text('test@example.com'), findsNothing);
    expect(find.byIcon(Icons.logout), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('access_token'), isNull);
  });

  testWidgets('SessionWidget clears cookie on 401',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'abc123',
    });
    dioAdapter.onGet(
      'https://example.com/fixme/session',
      (server) => server.reply(401, {}),
    );

    await tester.pumpWidget(MaterialApp(
      home: SessionWidget(dio: dio, apiBaseUrl: 'https://example.com'),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('access_token'), isNull);
  });
}
