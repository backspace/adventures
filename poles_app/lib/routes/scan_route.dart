import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/pole.dart';
import 'package:poles/routes/puzzlet_route.dart';

class ScanRoute extends StatefulWidget {
  final PolesApi api;
  const ScanRoute({super.key, required this.api});

  @override
  State<ScanRoute> createState() => _ScanRouteState();
}

class _ScanRouteState extends State<ScanRoute> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null) return;

    setState(() => _processing = true);
    await _controller.stop();

    try {
      final ScanResult result = await widget.api.scan(barcode);
      if (!mounted) return;

      if (result.activePuzzlet == null) {
        _showSnack(result.pole.locked
            ? 'This pole is fully captured.'
            : 'No active puzzlet for this pole.');
        Navigator.of(context).pop(barcode);
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PuzzletRoute(
            api: widget.api,
            pole: result.pole,
            puzzlet: result.activePuzzlet!,
          ),
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(barcode);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Scan failed: $e');
      setState(() => _processing = false);
      _controller.start();
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan a pole')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          if (_processing)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
