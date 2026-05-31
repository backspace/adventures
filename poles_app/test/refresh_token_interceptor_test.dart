import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:poles/refresh_token_interceptor.dart';
import 'package:poles/services/user_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final storage = <String, String>{};

  setUp(() {
    storage.clear();
    UserService.setCurrentApiRoot('http://test.invalid');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>();
      final key = args?['key'] as String?;
      switch (call.method) {
        case 'read':
          return storage[key];
        case 'write':
          storage[key!] = args!['value'] as String;
          return null;
        case 'delete':
          storage.remove(key);
          return null;
        case 'readAll':
          return Map<String, String>.from(storage);
        case 'deleteAll':
          storage.clear();
          return null;
        case 'containsKey':
          return storage.containsKey(key);
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  test('concurrent 401s share a single renewal', () async {
    await UserService.setTokens('old_access', 'old_renewal');

    final baseOptions = BaseOptions(baseUrl: 'http://test.invalid');
    final dio = Dio(baseOptions);
    final renewalDio = Dio(baseOptions);
    final postRenewalDio = Dio(baseOptions);

    final adapter = DioAdapter(dio: dio);
    final renewalAdapter = DioAdapter(dio: renewalDio);
    final postRenewalAdapter = DioAdapter(dio: postRenewalDio);

    var renewCalls = 0;
    renewalAdapter.onPost(
      '/powapi/session/renew',
      (server) {
        renewCalls++;
        server.reply(200, {
          'data': {
            'access_token': 'new_access',
            'renewal_token': 'new_renewal',
          }
        });
      },
    );

    // Original requests through `dio` always 401 — the retry goes through
    // postRenewalDio, which is mocked separately.
    adapter.onGet('/poles/event', (s) => s.reply(401, {'error': 'unauthorized'}));
    adapter.onGet('/poles/poles', (s) => s.reply(401, {'error': 'unauthorized'}));

    postRenewalAdapter.onGet('/poles/event', (s) => s.reply(200, {'ok': 'event'}));
    postRenewalAdapter.onGet('/poles/poles', (s) => s.reply(200, {'ok': 'poles'}));

    dio.interceptors.add(RefreshTokenInterceptor(
      dio: dio,
      renewalDio: renewalDio,
      postRenewalDio: postRenewalDio,
    ));

    final responses = await Future.wait([
      dio.get('/poles/event'),
      dio.get('/poles/poles'),
    ]);

    expect(renewCalls, 1,
        reason: 'concurrent 401s should share a single /session/renew call');
    expect(responses[0].statusCode, 200);
    expect(responses[1].statusCode, 200);
    expect(responses[0].data, {'ok': 'event'});
    expect(responses[1].data, {'ok': 'poles'});
    expect(await UserService.getAccessToken(), 'new_access');
    expect(await UserService.getRenewalToken(), 'new_renewal');
  });

  test('renewal failure clears tokens and propagates the original 401',
      () async {
    await UserService.setTokens('old_access', 'old_renewal');

    final baseOptions = BaseOptions(baseUrl: 'http://test.invalid');
    final dio = Dio(baseOptions);
    final renewalDio = Dio(baseOptions);
    final postRenewalDio = Dio(baseOptions);

    final adapter = DioAdapter(dio: dio);
    final renewalAdapter = DioAdapter(dio: renewalDio);

    adapter.onGet('/poles/event', (s) => s.reply(401, {'error': 'x'}));
    renewalAdapter.onPost(
      '/powapi/session/renew',
      (s) => s.reply(401, {'error': 'session_expired'}),
    );

    dio.interceptors.add(RefreshTokenInterceptor(
      dio: dio,
      renewalDio: renewalDio,
      postRenewalDio: postRenewalDio,
    ));

    await expectLater(
      dio.get('/poles/event'),
      throwsA(isA<DioException>()
          .having((e) => e.response?.statusCode, 'statusCode', 401)),
    );

    expect(await UserService.getAccessToken(), isNull);
    expect(await UserService.getRenewalToken(), isNull);
  });
}
