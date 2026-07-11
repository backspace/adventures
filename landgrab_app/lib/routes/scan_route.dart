import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/l10n/player_strings.dart';
import 'package:landgrab/models/pole.dart';
import 'package:landgrab/routes/puzzlet_route.dart';

class ScanRoute extends StatefulWidget {
  final LandgrabApi api;
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
      final outcome = await widget.api.scan(barcode);
      if (!mounted) return;

      switch (outcome) {
        case ScanUnknownBarcode():
          await _showUnknownBarcodeDialog(barcode);
          if (!mounted) return;
          setState(() => _processing = false);
          _controller.start();
          return;

        case ScanAlreadyOwner(:final pole):
          await _showAlreadyOwnerDialog(pole);
          if (!mounted) return;
          Navigator.of(context).pop(barcode);
          return;

        case ScanTeamLockedOut(:final pole):
          await _showTeamLockedOutDialog(pole);
          if (!mounted) return;
          Navigator.of(context).pop(barcode);
          return;

        case ScanFound(:final result):
          if (result.activePuzzlet == null) {
            _showSnack(result.pole.locked
                ? ScanStrings.poleFullyCaptured
                : ScanStrings.noActivePuzzlet);
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
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(ScanStrings.scanFailed(e.toString()));
      setState(() => _processing = false);
      _controller.start();
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showUnknownBarcodeDialog(String barcode) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(ScanStrings.unknownBarcodeTitle),
        content: Text(ScanStrings.unknownBarcodeBody(barcode)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
            child: const Text(ScanStrings.unknownBarcodeBack),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(ScanStrings.unknownBarcodeRetry),
          ),
        ],
      ),
    );
  }

  Future<void> _showAlreadyOwnerDialog(Pole pole) {
    final name = pole.label ?? pole.barcode;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(ScanStrings.alreadyOwnerTitle),
        content: Text(ScanStrings.alreadyOwnerBody(name)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(ScanStrings.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _showTeamLockedOutDialog(Pole pole) {
    final name = pole.label ?? pole.barcode;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(ScanStrings.lockedOutTitle),
        content: Text(ScanStrings.lockedOutBody(name)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(ScanStrings.ok),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(ScanStrings.appBarTitle)),
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
