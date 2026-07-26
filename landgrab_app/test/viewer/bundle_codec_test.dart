import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:landgrab/viewer/bundle_codec.dart';
import 'package:landgrab/viewer/viewer_dataset.dart';

void main() {
  // A dataset roughly the shape/size of the real content (a few poles/regions,
  // a few hundred puzzlets of short instruction text) so the size numbers below
  // are representative rather than toy.
  ViewerDataset sample({int puzzlets = 350}) => ViewerDataset(
        poles: List.generate(
          46,
          (i) => ViewerPole(
            id: 'pole-$i',
            name: 'Stake $i',
            latitude: 49.89 + i * 0.0001,
            longitude: -97.13 - i * 0.0001,
            accessibilityTags: i.isEven ? const ['stairs'] : const [],
          ),
        ),
        regions: List.generate(
          25,
          (i) => ViewerRegion(
            id: 'region-$i',
            name: 'Region $i',
            entryInstructions: 'Enter via door $i and proceed to the far wall.',
          ),
        ),
        puzzlets: List.generate(
          puzzlets,
          (i) => ViewerPuzzlet(
            id: 'puz-$i',
            poleId: 'pole-${i % 46}',
            regionId: 'region-${i % 25}',
            instructions:
                'Find the object described in clue $i and read the label on it.',
            answer: 'answer-$i',
            answerType: const ['loose_text', 'strict_text', 'barcode', 'nfc'][i % 4],
            difficulty: i % 3,
          ),
        ),
      );

  test('round-trips through an encrypted bundle', () async {
    final data = sample();
    final bytes = await ViewerBundle.encode(data, passphrase: 'correct horse');
    final back = await ViewerBundle.decode(bytes, passphrase: 'correct horse');

    expect(back.itemCount, data.itemCount);
    expect(back.puzzlets.first.instructions, data.puzzlets.first.instructions);
    expect(back.puzzlets.first.answer, data.puzzlets.first.answer);
    // Structural equality via canonical JSON.
    expect(jsonEncode(back.toJson()), jsonEncode(data.toJson()));
  });

  test('wrong passphrase fails to authenticate (not silent garbage)', () async {
    final bytes = await ViewerBundle.encode(sample(), passphrase: 'right');
    await expectLater(
      ViewerBundle.decode(bytes, passphrase: 'wrong'),
      throwsA(isA<ViewerBundleAuthException>()),
    );
  });

  test('a tampered byte is rejected', () async {
    final bytes = await ViewerBundle.encode(sample(), passphrase: 'k');
    bytes[bytes.length - 1] ^= 0xFF; // flip a ciphertext bit
    await expectLater(
      ViewerBundle.decode(bytes, passphrase: 'k'),
      throwsA(isA<ViewerBundleAuthException>()),
    );
  });

  test('non-bundle bytes raise a FormatException', () async {
    await expectLater(
      ViewerBundle.decode(
          Uint8List.fromList(utf8.encode('hello there')), passphrase: 'k'),
      throwsA(isA<FormatException>()),
    );
  });

  test('reports payload sizes (raw vs gzip+encrypted)', () async {
    final data = sample();
    final raw = data.toJsonBytes().length;
    final bundle = await ViewerBundle.encode(data, passphrase: 'x');
    final ratio = (bundle.length / raw * 100).toStringAsFixed(1);
    // ignore: avoid_print
    print('viewer bundle: raw=${raw}B  bundle=${bundle.length}B  ($ratio% of raw, '
        '${(bundle.length / 1024).toStringAsFixed(1)} kB over the wire)');
    // Compression should beat the ~48-byte crypto envelope overhead comfortably.
    expect(bundle.length, lessThan(raw));
  });
}
