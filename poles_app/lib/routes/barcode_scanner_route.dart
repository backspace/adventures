import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Full-screen scanner that pops with the first scanned barcode string,
/// or null if the user backs out without scanning.
class BarcodeScannerRoute extends StatefulWidget {
  final String title;
  const BarcodeScannerRoute({super.key, this.title = 'Scan barcode'});

  @override
  State<BarcodeScannerRoute> createState() => _BarcodeScannerRouteState();
}

class _BarcodeScannerRouteState extends State<BarcodeScannerRoute> {
  final _controller = MobileScannerController();
  bool _popping = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_popping) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null) return;
    _popping = true;
    await _controller.stop();
    if (!mounted) return;
    Navigator.of(context).pop<String>(value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: MobileScanner(controller: _controller, onDetect: _onDetect),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
