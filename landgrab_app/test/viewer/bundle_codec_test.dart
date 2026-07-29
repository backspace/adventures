import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:landgrab/viewer/bundle_codec.dart';
import 'package:landgrab/viewer/viewer_dataset.dart';

void main() {
  // Representative-sized dataset so the size numbers below are realistic.
  ViewerDataset sample({int puzzlets = 350}) => ViewerDataset(
        poles: List.generate(
          46,
          (i) => ViewerPole(
            id: 'pole-$i',
            name: 'Stake $i',
            latitude: 49.89 + i * 0.0001,
            longitude: -97.13 - i * 0.0001,
          ),
        ),
        regions: List.generate(
          25,
          (i) => ViewerRegion(id: 'region-$i', name: 'Region $i'),
        ),
        puzzlets: List.generate(
          puzzlets,
          (i) => ViewerPuzzlet(
            id: 'puz-$i',
            poleId: 'pole-${i % 46}',
            regionId: 'region-${i % 25}',
            instructions:
                'Find the object described in clue $i and read the label.',
            answer: 'answer-$i',
            answerType:
                const ['loose_text', 'strict_text', 'barcode', 'nfc'][i % 4],
            difficulty: i % 3,
          ),
        ),
      );

  test('encode produces a random 256-bit key and round-trips with it', () async {
    final data = sample();
    final enc = await ViewerBundle.encode(data);
    expect(enc.key.length, ViewerBundle.keyLen); // 32 bytes

    final back = await ViewerBundle.decode(enc.bytes, enc.key);
    expect(back.itemCount, data.itemCount);
    expect(jsonEncode(back.toJson()), jsonEncode(data.toJson()));
  });

  test('each encode uses a fresh key', () async {
    final a = await ViewerBundle.encode(sample(puzzlets: 1));
    final b = await ViewerBundle.encode(sample(puzzlets: 1));
    expect(a.key, isNot(equals(b.key)));
  });

  test('the wrong key fails to authenticate (not silent garbage)', () async {
    final enc = await ViewerBundle.encode(sample());
    final wrongKey = Uint8List(ViewerBundle.keyLen); // all zeros
    await expectLater(
      ViewerBundle.decode(enc.bytes, wrongKey),
      throwsA(isA<ViewerBundleAuthException>()),
    );
  });

  test('a tampered byte is rejected', () async {
    final enc = await ViewerBundle.encode(sample());
    enc.bytes[enc.bytes.length - 1] ^= 0xFF;
    await expectLater(
      ViewerBundle.decode(enc.bytes, enc.key),
      throwsA(isA<ViewerBundleAuthException>()),
    );
  });

  test('non-bundle bytes raise a FormatException', () async {
    final enc = await ViewerBundle.encode(sample(puzzlets: 1));
    await expectLater(
      ViewerBundle.decode(
          Uint8List.fromList(utf8.encode('hello there')), enc.key),
      throwsA(isA<FormatException>()),
    );
  });

  test('transport packs/splits key + bundle', () async {
    final enc = await ViewerBundle.encode(sample());
    final wire = ViewerBundle.forTransport(enc.bytes, enc.key);
    expect(wire.length, ViewerBundle.keyLen + enc.bytes.length);

    final parts = ViewerBundle.fromTransport(wire);
    expect(parts.key, equals(enc.key));
    expect(parts.bundle, equals(enc.bytes));

    final back = await ViewerBundle.decode(parts.bundle, parts.key);
    expect(back.itemCount, isPositive);
  });

  test('fromTransport rejects a truncated wire payload', () {
    expect(() => ViewerBundle.fromTransport(Uint8List(8)),
        throwsA(isA<FormatException>()));
  });

  test('reports payload sizes (raw vs gzip+encrypted)', () async {
    final data = sample();
    final raw = data.toJsonBytes().length;
    final enc = await ViewerBundle.encode(data);
    final ratio = (enc.bytes.length / raw * 100).toStringAsFixed(1);
    // ignore: avoid_print
    print('viewer bundle: raw=${raw}B  bundle=${enc.bytes.length}B  ($ratio% of '
        'raw, ${(enc.bytes.length / 1024).toStringAsFixed(1)} kB over the wire)');
    expect(enc.bytes.length, lessThan(raw));
  });
}
