import 'package:flutter/material.dart';
import 'package:landgrab/widgets/landgrab_app_bar.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Full-screen scanner that pops with the first scanned barcode string,
/// or null if the user backs out without scanning.
class BarcodeScannerRoute extends StatefulWidget {
  final String title;

  /// Optional: reports the detected symbology (e.g. "Code 128", "EAN-13")
  /// just before popping with the value. The practice scanner uses it to
  /// show the barcode type; every other caller ignores it and keeps
  /// receiving a plain string from the pop.
  final ValueChanged<String>? onFormat;

  const BarcodeScannerRoute({
    super.key,
    this.title = 'Scan barcode',
    this.onFormat,
  });

  @override
  State<BarcodeScannerRoute> createState() => _BarcodeScannerRouteState();
}

class _BarcodeScannerRouteState extends State<BarcodeScannerRoute> {
  final _controller = MobileScannerController();
  bool _popping = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_popping) return;
    final barcode = capture.barcodes.firstOrNull;
    final value = barcode?.rawValue;
    if (barcode == null || value == null) return;
    _popping = true;
    widget.onFormat?.call(_formatLabel(barcode.format));
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
      appBar: LandgrabAppBar(title: widget.title),
      body: MobileScanner(controller: _controller, onDetect: _onDetect),
    );
  }
}

/// Human-readable label for a scanned symbology, falling back to the raw
/// enum name for anything not spelled out here.
String _formatLabel(BarcodeFormat format) => switch (format) {
      BarcodeFormat.code128 => 'Code 128',
      BarcodeFormat.code39 => 'Code 39',
      BarcodeFormat.code93 => 'Code 93',
      BarcodeFormat.codabar => 'Codabar',
      BarcodeFormat.ean13 => 'EAN-13',
      BarcodeFormat.ean8 => 'EAN-8',
      BarcodeFormat.upcA => 'UPC-A',
      BarcodeFormat.upcE => 'UPC-E',
      BarcodeFormat.qrCode => 'QR',
      BarcodeFormat.dataMatrix => 'Data Matrix',
      BarcodeFormat.aztec => 'Aztec',
      BarcodeFormat.pdf417 => 'PDF417',
      _ => format.name,
    };

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
