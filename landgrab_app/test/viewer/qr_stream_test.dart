import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:landgrab/viewer/qr_stream.dart';

void main() {
  Uint8List payload(int n) =>
      Uint8List.fromList(List.generate(n, (i) => (i * 37 + 11) % 256));

  test('frames reassemble regardless of order, ignoring duplicates', () {
    final data = payload(5000);
    final frames = encodeQrFrames(data, sessionId: 'sess1', chunkSize: 800);
    expect(frames.length, (5000 / 800).ceil());

    final asm = QrStreamAssembler();
    final shuffled = [...frames]..shuffle(Random(42));
    // Feed shuffled + a duplicate of the first, to prove order/dupes are fine.
    for (final f in [...shuffled, shuffled.first]) {
      asm.addFrame(f);
    }
    expect(asm.isComplete, isTrue);
    expect(asm.assemble(), equals(data));
  });

  test('stays incomplete until the last frame arrives', () {
    final data = payload(3000);
    final frames = encodeQrFrames(data, sessionId: 's', chunkSize: 800);
    final asm = QrStreamAssembler();
    for (final f in frames.take(frames.length - 1)) {
      asm.addFrame(f);
    }
    expect(asm.isComplete, isFalse);
    expect(asm.missing, isNotEmpty);
    expect(asm.assemble, throwsStateError);

    asm.addFrame(frames.last);
    expect(asm.isComplete, isTrue);
    expect(asm.assemble(), equals(data));
  });

  test('ignores frames from a different session', () {
    final data = payload(2000);
    final mine = encodeQrFrames(data, sessionId: 'mine', chunkSize: 800);
    final theirs = encodeQrFrames(payload(2000), sessionId: 'theirs', chunkSize: 800);

    final asm = QrStreamAssembler();
    asm.addFrame(mine.first); // locks session to 'mine'
    for (final f in theirs) {
      expect(asm.addFrame(f), isFalse); // cross-stream frames rejected
    }
    for (final f in mine.skip(1)) {
      asm.addFrame(f);
    }
    expect(asm.assemble(), equals(data));
  });

  test('rejects malformed frames without throwing', () {
    final asm = QrStreamAssembler();
    expect(asm.addFrame('not a frame'), isFalse);
    expect(asm.addFrame('LGVQ1|s|x|3|zzz'), isFalse); // bad index
    expect(asm.addFrame('LGVQ1|s|0|0|'), isFalse); // total 0
    expect(asm.received, 0);
  });

  test('single tiny bundle is one frame', () {
    final frames = encodeQrFrames(payload(10), sessionId: 's', chunkSize: 800);
    expect(frames.length, 1);
  });
}
