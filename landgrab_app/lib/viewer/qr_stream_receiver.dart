import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:landgrab/viewer/qr_stream.dart';

/// Scans a [QrStreamSender]'s animated QR until every frame is collected, then
/// hands the reassembled (still-encrypted) bundle bytes to [onComplete]. Order
/// and repeats don't matter; a live progress bar shows frames as they land.
class QrStreamReceiver extends StatefulWidget {
  final void Function(Uint8List bundle) onComplete;

  const QrStreamReceiver({super.key, required this.onComplete});

  @override
  State<QrStreamReceiver> createState() => _QrStreamReceiverState();
}

class _QrStreamReceiverState extends State<QrStreamReceiver> {
  final MobileScannerController _controller = MobileScannerController();
  final QrStreamAssembler _assembler = QrStreamAssembler();
  bool _done = false;

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    var changed = false;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && _assembler.addFrame(raw)) changed = true;
    }
    if (!changed) return;

    if (_assembler.isComplete) {
      _done = true;
      _controller.stop();
      widget.onComplete(_assembler.assemble());
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _assembler.total;
    final received = _assembler.received;
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  total == 0
                      ? 'Looking for the QR stream…'
                      : 'Received $received of $total frames',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 220,
                  child: LinearProgressIndicator(
                    value: total == 0 ? null : _assembler.progress,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
