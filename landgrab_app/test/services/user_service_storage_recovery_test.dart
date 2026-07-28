import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:landgrab/services/user_service.dart';

// Regression for the Android BAD_DECRYPT boot crash: when the keystore key is
// invalidated, secure-storage `read` throws a PlatformException. That used to
// propagate out of isLoggedIn and wedge the app at launch. It must now recover.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final calls = <String>[];

  setUp(() {
    calls.clear();
    UserService.setCurrentApiRoot('http://test.invalid');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'read') {
        throw PlatformException(
            code: 'Exception', message: 'BadPaddingException');
      }
      return null; // deleteAll / write succeed
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('a read decrypt failure recovers into a clean logged-out state',
      () async {
    // isLoggedIn → getAccessToken → _read, which throws on the platform side.
    final loggedIn = await UserService.isLoggedIn();

    expect(loggedIn, isFalse); // treated as "no value" — no exception escapes
    expect(calls.contains('deleteAll'), isTrue); // corrupt store wiped to recover
  });
}
