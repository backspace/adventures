import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:waydowntown/refresh_token_interceptor.dart';
import 'package:waydowntown/services/user_service.dart';
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

  testWidgets(
      'SessionWidget shows name, email, admin icon, and logout button when logged in as admin',
      (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'abc123',
    });

    dioAdapter.onGet(
      'http://example.com/fixme/session',
      (server) => server.reply(200, {
        'data': {
          'id': '1',
          'attributes': {
            'email': 'test@example.com',
            'name': 'Test User',
            'admin': true
          }
        }
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: SessionWidget(dio: dio, apiBaseUrl: 'http://example.com'),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.byIcon(Icons.admin_panel_settings), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);
    expect(find.text('Log in'), findsNothing);

    expect(await secureStorage.read(key: 'user_email'),
        equals('test@example.com'));
    expect(await secureStorage.read(key: 'user_name'), equals('Test User'));
    expect(await secureStorage.read(key: 'user_is_admin'), equals('true'));
    expect(await UserService.getUserId(), equals('1'));
  });

  testWidgets(
      'SessionWidget shows name, email and logout button when logged in as non-admin',
      (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'abc123',
    });

    dioAdapter.onGet(
      'http://example.com/fixme/session',
      (server) => server.reply(200, {
        'data': {
          'id': '1',
          'attributes': {
            'email': 'test@example.com',
            'name': 'Test User',
            'admin': false
          }
        }
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: SessionWidget(dio: dio, apiBaseUrl: 'http://example.com'),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.byIcon(Icons.admin_panel_settings), findsNothing);
    expect(find.byIcon(Icons.logout), findsOneWidget);
    expect(find.text('Log in'), findsNothing);

    expect(await secureStorage.read(key: 'user_email'),
        equals('test@example.com'));
    expect(await secureStorage.read(key: 'user_name'), equals('Test User'));
    expect(await secureStorage.read(key: 'user_is_admin'), equals('false'));
  });

  testWidgets('Logout button clears user data and shows login button',
      (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'abc123',
    });

    dioAdapter.onGet(
      'http://example.com/fixme/session',
      (server) => server.reply(200, {
        'data': {
          'id': '1',
          'attributes': {'email': 'test@example.com', 'name': 'Test User'}
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

    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);

    expect(find.text('Test User'), findsNothing);
    expect(find.text('test@example.com'), findsNothing);
    expect(find.byIcon(Icons.logout), findsNothing);

    expect(await secureStorage.read(key: 'access_token'), isNull);
    expect(await secureStorage.read(key: 'renewal_token'), isNull);
    expect(await secureStorage.read(key: 'user_email'), isNull);
    expect(await secureStorage.read(key: 'user_name'), isNull);
    expect(await secureStorage.read(key: 'user_is_admin'), isNull);
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
          'id': '1',
          'attributes': {
            'email': 'test@example.com',
            'name': 'Test User',
            'admin': false
          }
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

  testWidgets('User can edit their name successfully',
      (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'abc123',
      'user_id': '1',
    });

    dioAdapter.onGet(
      'http://example.com/fixme/session',
      (server) => server.reply(200, {
        'data': {
          'id': '1',
          'attributes': {
            'email': 'test@example.com',
            'name': 'Original Name',
            'admin': false
          }
        }
      }),
    );

    dioAdapter.onPost(
      'http://example.com/fixme/me',
      (server) => server.reply(200, {
        'data': {
          'id': '1',
          'attributes': {
            'email': 'test@example.com',
            'name': 'Octavia',
            'admin': false
          }
        }
      }),
      data: {
        'data': {
          'type': 'users',
          'id': '1',
          'attributes': {'name': 'Octavia'}
        }
      },
      headers: {
        'Accept': 'application/vnd.api+json',
        'Content-Type': 'application/vnd.api+json',
      },
    );

    await tester.pumpWidget(MaterialApp(
      home: SessionWidget(dio: dio, apiBaseUrl: 'http://example.com'),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Original Name'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Octavia');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Octavia'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
    expect(await secureStorage.read(key: 'user_name'), equals('Octavia'));
  });

  testWidgets('Name update shows error when API returns validation error',
      (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'abc123',
      'user_id': '1',
    });

    dioAdapter.onGet(
      'http://example.com/fixme/session',
      (server) => server.reply(200, {
        'data': {
          'id': '1',
          'attributes': {
            'email': 'test@example.com',
            'name': 'Original Name',
            'admin': false
          }
        }
      }),
    );

    dioAdapter.onPost(
      'http://example.com/fixme/me',
      (server) => server.reply(422, {
        'errors': [
          {
            'source': {'pointer': '/data/attributes/name'},
            'detail': "can't be blank"
          }
        ]
      }),
      data: {
        'data': {
          'type': 'users',
          'id': '1',
          'attributes': {'name': ''}
        }
      },
      headers: {
        'Accept': 'application/vnd.api+json',
        'Content-Type': 'application/vnd.api+json',
      },
    );

    await tester.pumpWidget(MaterialApp(
      home: SessionWidget(dio: dio, apiBaseUrl: 'http://example.com'),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Original Name'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text("Name can't be blank"), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);

    expect(find.byType(TextField), findsOneWidget);

    expect(await secureStorage.read(key: 'user_name'), equals('Original Name'));
  });
}
