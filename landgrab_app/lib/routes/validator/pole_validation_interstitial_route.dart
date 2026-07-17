import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/validation.dart';
import 'package:landgrab/routes/barcode_scanner_route.dart';
import 'package:landgrab/routes/validator/pole_validation_form_route.dart';
import 'package:landgrab/widgets/mini_location_map.dart';
import 'package:landgrab/widgets/status_badge.dart';

/// The validator's first stop after tapping a pole — kept close to the
/// gameplay feel. Tapping a pin is only *intent*; the scan is what
/// confirms which physical pole they're actually at. From here they can
/// scan to verify, open the form for a desk review, or report it
/// unfindable.
class PoleValidationInterstitialRoute extends StatefulWidget {
  final LandgrabApi api;
  final PoleValidationModel validation;

  /// All the validator's active pole assignments, so a scan that matches
  /// a *different* assigned pole can route straight to it.
  final List<PoleValidationModel> assignments;

  const PoleValidationInterstitialRoute({
    super.key,
    required this.api,
    required this.validation,
    required this.assignments,
  });

  @override
  State<PoleValidationInterstitialRoute> createState() =>
      _PoleValidationInterstitialRouteState();
}

class _PoleValidationInterstitialRouteState
    extends State<PoleValidationInterstitialRoute> {
  bool _busy = false;

  PoleValidationModel get _v => widget.validation;

  Future<void> _openForm(
    PoleValidationModel validation, {
    bool verified = false,
    bool differentPole = false,
    String? scannedBarcode,
  }) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PoleValidationFormRoute(
          api: widget.api,
          validation: validation,
          verified: verified,
          differentPole: differentPole,
          scannedBarcode: scannedBarcode,
        ),
      ),
    );
    if (changed == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _scan() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerRoute(title: 'Scan the pole'),
      ),
    );
    if (scanned == null || scanned.isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      final res = await widget.api
          .resolvePoleScan(barcode: scanned, tappedValidationId: _v.id);
      if (!mounted) return;
      setState(() => _busy = false);
      switch (res.outcome) {
        case ScanMatch.matched:
          await _openForm(_v, verified: true);
        case ScanMatch.other:
          final other = widget.assignments
              .where((a) => a.id == res.validationId)
              .cast<PoleValidationModel?>()
              .firstWhere((_) => true, orElse: () => null);
          if (other == null) {
            _snack(
                'You scanned a pole assigned to you, but it isn’t loaded here. Pull to refresh and try again.');
          } else {
            await _openForm(other, verified: true, differentPole: true);
          }
        case ScanMatch.unknown:
          await _openForm(_v, scannedBarcode: scanned);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Scan lookup failed: ${e.message}');
    }
  }

  Future<void> _reportUnfindable() async {
    final note = await _askNote();
    if (note == null || !mounted) return; // cancelled
    setState(() => _busy = true);
    try {
      await widget.api.markPoleUnfindable(_v.id, overallNotes: note);
      if (!mounted) return;
      _snack('Reported as unfindable.');
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final detail =
          e.response?.data?['error']?['detail'] ?? e.message;
      _snack('Could not report: $detail');
    }
  }

  Future<String?> _askNote() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Can’t find this pole?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'What did you find (optional)?',
            hintText: 'e.g. searched the whole corner, no pole here',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Report unfindable'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final pole = _v.pole;
    final decided = _v.status == ValidationStatus.accepted ||
        _v.status == ValidationStatus.rejected ||
        _v.status == ValidationStatus.submitted ||
        _v.status == ValidationStatus.unfindable;

    return Scaffold(
      appBar: AppBar(
        title: Text(pole?.label ?? pole?.barcode ?? 'Pole'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: StatusBadge(
                label: validationStatusLabel(_v.status),
                color: statusColorFor(_v.status.name),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (pole != null) ...[
            Text(pole.barcode, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('${pole.latitude.toStringAsFixed(5)}, '
                '${pole.longitude.toStringAsFixed(5)}'),
            const SizedBox(height: 8),
            MiniLocationMap(
              latitude: pole.latitude,
              longitude: pole.longitude,
              label: pole.label ?? pole.barcode,
            ),
            const SizedBox(height: 24),
          ],
          FilledButton.icon(
            onPressed: (_busy || decided) ? null : _scan,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan to verify'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _openForm(_v),
            icon: const Icon(Icons.rate_review_outlined),
            label: Text(decided ? 'View form' : 'Review without scanning'),
          ),
          const SizedBox(height: 12),
          if (!decided)
            TextButton.icon(
              onPressed: _busy ? null : _reportUnfindable,
              icon: const Icon(Icons.wrong_location_outlined),
              label: const Text('Can’t find it'),
            ),
          if (_busy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}
