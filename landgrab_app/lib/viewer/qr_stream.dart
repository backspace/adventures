import 'dart:convert';
import 'dart:typed_data';

/// Frame wire format (one per QR):
///   `LGVQ1|{sessionId}|{index}|{total}|{base64(chunk)}`
///
/// The bundle bytes are sliced into [chunkSize] pieces; each piece is one QR.
/// base64 keeps the payload text-safe for `qr_flutter` (which encodes strings),
/// at ~33% overhead — fine at these sizes. The receiver only needs to collect
/// all `total` distinct indices, in any order, tolerating repeats (the sender
/// just loops), so missed frames are caught on the next pass.
const String _framePrefix = 'LGVQ1';

/// Split an encrypted bundle into QR frame strings.
List<String> encodeQrFrames(
  Uint8List bundle, {
  required String sessionId,
  int chunkSize = 800,
}) {
  assert(chunkSize > 0);
  assert(!sessionId.contains('|'), 'sessionId must not contain the delimiter');
  final total = bundle.isEmpty ? 1 : (bundle.length / chunkSize).ceil();
  final frames = <String>[];
  for (var i = 0; i < total; i++) {
    final start = i * chunkSize;
    final end = (start + chunkSize) < bundle.length ? start + chunkSize : bundle.length;
    final chunk = bundle.sublist(start, end);
    frames.add('$_framePrefix|$sessionId|$i|$total|${base64.encode(chunk)}');
  }
  return frames;
}

/// Collects scanned frames and reassembles the bundle once every index is seen.
///
/// Locks onto the first session it sees and ignores frames from any other
/// stream, so two people transferring nearby don't cross-contaminate.
class QrStreamAssembler {
  String? _sessionId;
  int? _total;
  final Map<int, Uint8List> _chunks = {};

  /// Feed a scanned QR's raw string. Returns true iff it was a valid, *new*
  /// frame for the active session (so callers can ignore repeats cheaply).
  bool addFrame(String raw) {
    final parts = raw.split('|');
    if (parts.length != 5 || parts[0] != _framePrefix) return false;
    final session = parts[1];
    final index = int.tryParse(parts[2]);
    final total = int.tryParse(parts[3]);
    if (index == null || total == null || total <= 0) return false;
    if (index < 0 || index >= total) return false;

    if (_sessionId == null) {
      _sessionId = session;
      _total = total;
    }
    if (session != _sessionId || total != _total) return false;
    if (_chunks.containsKey(index)) return false;

    final Uint8List chunk;
    try {
      chunk = base64.decode(parts[4]);
    } catch (_) {
      return false;
    }
    _chunks[index] = chunk;
    return true;
  }

  int get total => _total ?? 0;
  int get received => _chunks.length;
  bool get isComplete => _total != null && _chunks.length == _total;
  double get progress =>
      (_total == null || _total == 0) ? 0 : _chunks.length / _total!;

  /// Indexes still missing — handy for a "waiting for 3, 7…" hint.
  List<int> get missing => _total == null
      ? const []
      : [for (var i = 0; i < _total!; i++) if (!_chunks.containsKey(i)) i];

  Uint8List assemble() {
    if (!isComplete) {
      throw StateError('QR stream incomplete: $received/$total frames');
    }
    final builder = BytesBuilder(copy: false);
    for (var i = 0; i < _total!; i++) {
      builder.add(_chunks[i]!);
    }
    return builder.toBytes();
  }

  void reset() {
    _sessionId = null;
    _total = null;
    _chunks.clear();
  }
}
