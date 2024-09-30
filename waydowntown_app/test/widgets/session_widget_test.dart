import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:waydowntown/refresh_token_interceptor.dart';
import 'package:waydowntown/widgets/session_widget.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;

  late Dio renewalDio;
  late DioAdapter renewalDioAdapter;

  late Dio postRenewalDio;
  late DioAdapter postRenewalDioAdapter;

  late FlutterSecureStorage secureStorage;

  setUp(() async {
    renewalDio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    renewalDio.interceptors
        .add(PrettyDioLogger(requestBody: true, requestHeader: true));
    renewalDioAdapter = DioAdapter(dio: renewalDio, printLogs: true);

    postRenewalDio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    postRenewalDio.interceptors
        .add(PrettyDioLogger(requestBody: true, requestHeader: true));
    postRenewalDioAdapter = DioAdapter(dio: postRenewalDio);

    dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    dio.interceptors.add(PrettyDioLogger());
    dio.interceptors.add(RefreshTokenInterceptor(
        dio: dio, renewalDio: renewalDio, postRenewalDio: postRenewalDio));
    dioAdapter = DioAdapter(dio: dio);

    secureStorage = const FlutterSecureStorage();
  });

  testWidgets('SessionWidget shows login button when not logged in',
      (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});

    dioAdapter.onGet(
      'http://example.com/fixme/session',
      (server) => server.reply(401, {
        'data': {
          'attributes': {'email': 'test@example.com'}
        }
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: SessionWidget(dio: dio, apiBaseUrl: 'http://example.com'),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('SessionWidget shows email and logout button when logged in',
      (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'abc123',
    });

    dioAdapter.onGet(
      'http://example.com/fixme/session',
      (server) => server.reply(200, {
        'data': {
          'attributes': {'email': 'test@example.com'}
        }
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: SessionWidget(dio: dio, apiBaseUrl: 'http://example.com'),
    ));

    await tester.pumpAndSettle();

    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);
    expect(find.text('Log in'), findsNothing);
  });

  testWidgets('Logout button clears cookie and shows login button',
      (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'abc123',
    });

    dioAdapter.onGet(
      'http://example.com/fixme/session',
      (server) => server.reply(200, {
        'data': {
          'attributes': {'email': 'test@example.com'}
        }
      }),
      headers: {
        'Authorization': 'abc123',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );

    await tester.pumpWidget(MaterialApp(
      home: SessionWidget(dio: dio, apiBaseUrl: 'http://example.com'),
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

    expect(await secureStorage.read(key: 'access_token'), isNull);
    expect(await secureStorage.read(key: 'renewal_token'), isNull);
  });

  testWidgets('SessionWidget renews session on 401 and retries',
      (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'expired_token',
      'renewal_token': 'valid_renewal_token',
    });

    dioAdapter.onGet(
      'http://example.com/fixme/session',
      (server) => server.reply(401, {}),
      headers: {
        'Authorization': 'expired_token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );

    renewalDioAdapter.onPost(
      '/powapi/session/renew',
      (server) => server.reply(200, {
        'data': {
          'access_token': 'new_access_token',
          'renewal_token': 'new_renewal_token',
        }
      }),
      data: null,
      headers: {
        'Authorization': 'valid_renewal_token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );

    postRenewalDioAdapter.onGet(
      'http://example.com/fixme/session',
      (server) => server.reply(200, {
        'data': {
          'attributes': {'email': 'test@example.com'}
        }
      }),
      headers: {
        'Authorization': 'new_access_token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );

    await tester.pumpWidget(MaterialApp(
      home: SessionWidget(dio: dio, apiBaseUrl: 'http://example.com'),
    ));

    await tester.pumpAndSettle();

    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);
    expect(find.text('Log in'), findsNothing);

    expect(await secureStorage.read(key: 'access_token'),
        equals('new_access_token'));
    expect(await secureStorage.read(key: 'renewal_token'),
        equals('new_renewal_token'));
  });
}
