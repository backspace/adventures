import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:landgrab/viewer/qr_stream.dart';

/// Displays an encrypted bundle as a looping animated QR stream for another
/// device to scan (see [QrStreamReceiver]). Purely one-way and offline — no
/// pairing, no network. It just cycles frames; the receiver catches whatever it
/// misses on the next pass.
class QrStreamSender extends StatefulWidget {
  final Uint8List bundle;
  final int chunkSize;
  final Duration frameInterval;
  final double size;

  const QrStreamSender({
    super.key,
    required this.bundle,
    this.chunkSize = 800,
    this.frameInterval = const Duration(milliseconds: 180),
    this.size = 300,
  });

  @override
  State<QrStreamSender> createState() => _QrStreamSenderState();
}

class _QrStreamSenderState extends State<QrStreamSender> {
  late final List<String> _frames;
  Timer? _timer;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    _frames = encodeQrFrames(
      widget.bundle,
      sessionId: _newSessionId(),
      chunkSize: widget.chunkSize,
    );
    if (_frames.length > 1) {
      _timer = Timer.periodic(widget.frameInterval, (_) {
        if (!mounted) return;
        setState(() => _i = (_i + 1) % _frames.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static String _newSessionId() {
    final r = Random();
    return List.generate(
        4, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // White quiet-zone padding matters for reliable scanning off a screen.
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: QrImageView(
            data: _frames[_i],
            version: QrVersions.auto,
            size: widget.size,
            backgroundColor: Colors.white,
            // Low ECC packs more bytes/frame; the loop covers reliability.
            errorCorrectionLevel: QrErrorCorrectLevel.L,
          ),
        ),
        const SizedBox(height: 12),
        Text('Frame ${_i + 1} of ${_frames.length}',
            style: theme.textTheme.titleMedium),
        Text('Point the other phone here — it grabs frames as they cycle.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
