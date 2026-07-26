import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:landgrab/viewer/bundle_codec.dart';
import 'package:landgrab/viewer/viewer_dataset.dart';
import 'package:landgrab/viewer/viewer_store.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.supportDir);
  final String supportDir;
  @override
  Future<String?> getApplicationSupportPath() async => supportDir;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secure = <String, String>{};
  late Directory tmp;

  setUp(() async {
    secure.clear();
    tmp = await Directory.systemTemp.createTemp('viewer_store');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>();
      final key = args?['key'] as String?;
      switch (call.method) {
        case 'read':
          return secure[key];
        case 'write':
          secure[key!] = args!['value'] as String;
          return null;
        case 'delete':
          secure.remove(key);
          return null;
        case 'readAll':
          return Map<String, String>.from(secure);
        case 'deleteAll':
          secure.clear();
          return null;
        case 'containsKey':
          return secure.containsKey(key);
        default:
          return null;
      }
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, null);
    await tmp.delete(recursive: true);
  });

  ViewerDataset sample() => ViewerDataset(
        regions: const [
          ViewerRegion(
              id: 'r', name: 'Server room', entryInstructions: 'badge in'),
        ],
        puzzlets: const [
          ViewerPuzzlet(
            id: 'z',
            instructions: 'read the label on the router',
            answer: 'A1',
            answerType: 'barcode',
            difficulty: 2,
          ),
        ],
      );

  test('save → exists → meta → load round-trips', () async {
    expect(await ViewerStore.exists(), isFalse);

    final data = sample();
    final bundle = await ViewerBundle.encode(data, passphrase: 'pw');
    await ViewerStore.save(bundle, passphrase: 'pw', itemCount: data.itemCount);

    expect(await ViewerStore.exists(), isTrue);
    final meta = await ViewerStore.meta();
    expect(meta, isNotNull);
    expect(meta!.itemCount, data.itemCount);
    expect(meta.syncedAt, isNotNull);

    final loaded = await ViewerStore.load();
    expect(loaded, isNotNull);
    expect(loaded!.puzzlets.single.instructions, 'read the label on the router');
    expect(loaded.regions.single.entryInstructions, 'badge in');
  });

  test('the at-rest file is ciphertext — plaintext never touches disk', () async {
    final data = sample();
    final bundle = await ViewerBundle.encode(data, passphrase: 'pw');
    await ViewerStore.save(bundle, passphrase: 'pw', itemCount: data.itemCount);

    final raw = await File('${tmp.path}/viewer/dataset.lgv').readAsBytes();
    expect(String.fromCharCodes(raw).contains('read the label'), isFalse);
  });

  test('clear removes file, key, and metadata', () async {
    final data = sample();
    final bundle = await ViewerBundle.encode(data, passphrase: 'pw');
    await ViewerStore.save(bundle, passphrase: 'pw', itemCount: data.itemCount);

    await ViewerStore.clear();
    expect(await ViewerStore.exists(), isFalse);
    expect(await ViewerStore.meta(), isNull);
    expect(await ViewerStore.load(), isNull);
  });
}
