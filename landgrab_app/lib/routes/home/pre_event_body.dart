import 'dart:async';

import 'package:flutter/material.dart';
import 'package:landgrab/l10n/player_strings.dart';
import 'package:landgrab/models/landgrab_event.dart';
import 'package:landgrab/routes/barcode_scanner_route.dart';
import 'package:landgrab/routes/nfc_scanner_route.dart';

/// The pre-event home screen: a live countdown to the start, role shortcuts
/// (author/validator/supervisor), and practice scanners. Shown by HomeRoute
/// until the server reports the event started.
class PreEventBody extends StatefulWidget {
  final LandgrabEvent event;
  final bool isAuthor;
  final bool isValidator;
  final bool isSupervisor;
  final VoidCallback onAuthor;
  final VoidCallback onValidate;
  final VoidCallback onSupervise;

  /// Fired a few seconds after the countdown reaches the start time — and then
  /// periodically — so the parent re-fetches the event. `started` is a server
  /// flag, so the map only appears once a reload reports the event underway.
  final VoidCallback onStarted;

  const PreEventBody({
    super.key,
    required this.event,
    required this.isAuthor,
    required this.isValidator,
    required this.isSupervisor,
    required this.onAuthor,
    required this.onValidate,
    required this.onSupervise,
    required this.onStarted,
  });

  @override
  State<PreEventBody> createState() => _PreEventBodyState();
}

class _PreEventBodyState extends State<PreEventBody> {
  Timer? _ticker;
  String? _lastBarcode;
  String? _lastBarcodeFormat;
  String? _lastNfcUid;

  // `started` is a server flag, so when our local countdown crosses zero the
  // map doesn't appear on its own. A few seconds after the start passes we
  // nudge the parent to re-fetch the event, retrying every few seconds in case
  // the server clock lags ours, until `started` flips and this screen is gone.
  static const _startGrace = Duration(seconds: 3);
  static const _startPollInterval = Duration(seconds: 4);
  DateTime? _lastStartPoll;

  @override
  void initState() {
    super.initState();
    // Only run the countdown ticker when we have a target to count
    // down TO. If the event has no start time yet, the display shows
    // "not yet scheduled" and there's nothing to tick.
    if (widget.event.startTime != null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        _maybePollForStart();
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _maybePollForStart() {
    final start = widget.event.startTime;
    if (start == null) return;
    final now = DateTime.now();
    if (now.isBefore(start.add(_startGrace))) return;
    if (_lastStartPoll != null &&
        now.difference(_lastStartPoll!) < _startPollInterval) {
      return;
    }
    _lastStartPoll = now;
    widget.onStarted();
  }

  Future<void> _openBarcodeScanner() async {
    String? format;
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => BarcodeScannerRoute(
          title: PreEventStrings.barcodePracticeTitle,
          onFormat: (f) => format = f,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _lastBarcode = result;
      _lastBarcodeFormat = format;
    });
  }

  Future<void> _openNfcScanner() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            const NfcScannerRoute(title: PreEventStrings.nfcPracticeTitle),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _lastNfcUid = result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = widget.event.startTime;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (start == null)
              Text(PreEventStrings.notYetScheduled,
                  style: theme.textTheme.titleLarge)
            else
              _Countdown(startTime: start),
            const SizedBox(height: 12),
            Text(
              PreEventStrings.openingCopy,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (widget.isAuthor)
              _BigButton(
                icon: Icons.edit_note,
                label: GameplayStrings.author,
                onPressed: widget.onAuthor,
              ),
            if (widget.isValidator) ...[
              const SizedBox(height: 12),
              _BigButton(
                icon: Icons.fact_check_outlined,
                label: GameplayStrings.validate,
                onPressed: widget.onValidate,
              ),
            ],
            if (widget.isSupervisor) ...[
              const SizedBox(height: 12),
              _BigButton(
                icon: Icons.supervisor_account,
                label: GameplayStrings.supervise,
                onPressed: widget.onSupervise,
              ),
            ],
            const SizedBox(height: 32),
            Text(PreEventStrings.practiceHeading,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _ScannerTile(
              icon: Icons.qr_code_scanner,
              label: PreEventStrings.barcodePracticeLabel,
              lastResult: _lastBarcode,
              resultDetail: _lastBarcodeFormat,
              onPressed: _openBarcodeScanner,
            ),
            const SizedBox(height: 8),
            _ScannerTile(
              icon: Icons.nfc,
              label: PreEventStrings.nfcPracticeLabel,
              lastResult: _lastNfcUid,
              onPressed: _openNfcScanner,
            ),
          ],
        ),
      ),
    );
  }
}

/// Live-updating countdown for the event start. Rebuilds each second
/// from the parent's ticker; hides its subtitle line once the
/// remaining duration crosses zero (server flips `started` at that
/// point and this whole widget is swapped out anyway).
class _Countdown extends StatelessWidget {
  final DateTime startTime;
  const _Countdown({required this.startTime});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = startTime.difference(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(PreEventStrings.countdownHeading,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
        const SizedBox(height: 4),
        Text(
          _formatRemaining(remaining),
          style: theme.textTheme.displaySmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(_formatStart(startTime),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
      ],
    );
  }

  /// "3d 14:22:07" when > 1 day away, "14:22:07" when < 1 day, and
  /// "starting now" once the remaining crosses zero (a transient
  /// state until the server flips `started`).
  static String _formatRemaining(Duration r) {
    if (r.isNegative || r.inSeconds == 0) return PreEventStrings.startingNow;
    final days = r.inDays;
    final hours = r.inHours.remainder(24);
    final minutes = r.inMinutes.remainder(60);
    final seconds = r.inSeconds.remainder(60);
    final hhmmss =
        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    return days > 0 ? '${days}d $hhmmss' : hhmmss;
  }

  static String _formatStart(DateTime utc) {
    final local = utc.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

class _ScannerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? lastResult;
  // Extra detail shown alongside the value — the barcode symbology for the
  // barcode tile (e.g. "Code 128"); null for tiles that have no type (NFC).
  final String? resultDetail;
  final VoidCallback onPressed;

  const _ScannerTile({
    required this.icon,
    required this.label,
    required this.lastResult,
    this.resultDetail,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: lastResult == null
            ? Text(PreEventStrings.noScansYet, style: theme.textTheme.bodySmall)
            : Text(
                resultDetail == null
                    ? PreEventStrings.lastScan(lastResult!)
                    : PreEventStrings.lastScanWithType(
                        lastResult!, resultDetail!),
                style: theme.textTheme.bodySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()]),
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onPressed,
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _BigButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 32),
        label: Text(label, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}
