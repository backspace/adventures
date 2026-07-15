import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/l10n/player_strings.dart';
import 'package:landgrab/models/pole.dart';
import 'package:landgrab/routes/puzzlet_route.dart';

/// What the scan flow hands back to the map: the scanned barcode
/// (signals a refresh is worthwhile) and, when the flow ended in a
/// successful capture, the captured pole's id so the map can replay
/// the territory animation.
typedef ScanRouteResult = ({String barcode, String? capturedPoleId});

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
          Navigator.of(context).pop((barcode: barcode, capturedPoleId: null));
          return;

        case ScanTeamLockedOut(:final pole):
          await _showTeamLockedOutDialog(pole);
          if (!mounted) return;
          Navigator.of(context).pop((barcode: barcode, capturedPoleId: null));
          return;

        case ScanOwnCreation(:final pole):
          await _showOwnCreationDialog(pole);
          if (!mounted) return;
          Navigator.of(context).pop((barcode: barcode, capturedPoleId: null));
          return;

        case ScanOutsideZone(:final pole):
          await _showOutsideZoneDialog(pole);
          if (!mounted) return;
          Navigator.of(context).pop((barcode: barcode, capturedPoleId: null));
          return;

        case ScanAtCapacity(:final active):
          await _showAtCapacityDialog(active);
          if (!mounted) return;
          Navigator.of(context).pop((barcode: barcode, capturedPoleId: null));
          return;

        case ScanFound(:final result):
          if (result.activePuzzlet == null) {
            _showSnack(result.pole.locked
                ? ScanStrings.poleFullyCaptured
                : ScanStrings.noActivePuzzlet);
            Navigator.of(context).pop((barcode: barcode, capturedPoleId: null));
            return;
          }

          // PuzzletRoute pops `true` after a successful capture (and
          // its celebration). Relay the captured pole's id to the map so
          // it can replay the territory animation on arrival — the
          // socket broadcast usually fires while the player is still
          // on the puzzlet screen, so without this they'd miss it.
          final captured = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => PuzzletRoute(
                api: widget.api,
                pole: result.pole,
                puzzlet: result.activePuzzlet!,
              ),
            ),
          );

          if (!mounted) return;
          Navigator.of(context).pop((
            barcode: barcode,
            capturedPoleId: captured == true ? result.pole.id : null,
          ));
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(ScanStrings.scanFailed(e.toString()));
      setState(() => _processing = false);
      _controller.start();
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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

  Future<void> _showOwnCreationDialog(Pole pole) {
    final name = pole.label ?? pole.barcode;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(ScanStrings.ownCreationTitle),
        content: Text(ScanStrings.ownCreationBody(name)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(ScanStrings.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _showAtCapacityDialog(List<ScanResult> active) {
    final current = active.isEmpty
        ? 'another puzzlet'
        : (active.first.pole.label ?? active.first.pole.barcode);
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(GameplayStrings.atCapacityTitle),
        content: Text(GameplayStrings.atCapacityBody(current)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(ScanStrings.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _showOutsideZoneDialog(Pole pole) {
    final name = pole.label ?? pole.barcode;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(ScanStrings.outsideZoneTitle),
        content: Text(ScanStrings.outsideZoneBody(name)),
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
