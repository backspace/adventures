import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/accessibility.dart';
import 'package:landgrab/models/validation.dart';
import 'package:landgrab/routes/author/adjust_position_route.dart';
import 'package:landgrab/services/location_service.dart';
import 'package:landgrab/widgets/accessibility_tags_field.dart';
import 'package:landgrab/widgets/location_card.dart';
import 'package:landgrab/widgets/mini_location_map.dart';

/// The validator's pole review form: the author's fields, pre-filled, in
/// "suggest" mode. Editing a field and submitting sends that change to
/// the supervisor as a suggestion; submitting unchanged endorses the
/// pole as-is. It never mutates the pole directly.
///
/// Reached from the interstitial. Flags tune the header:
///  * [verified] — the validator scanned this pole and it matched.
///  * [differentPole] — they scanned a *different* assigned pole than the
///    one they tapped; warn them.
///  * [scannedBarcode] — an unknown scan; pre-fill it as a barcode
///    correction so the diff proposes it.
class PoleValidationFormRoute extends StatefulWidget {
  final LandgrabApi api;
  final PoleValidationModel validation;
  final bool verified;
  final bool differentPole;
  final String? scannedBarcode;

  const PoleValidationFormRoute({
    super.key,
    required this.api,
    required this.validation,
    this.verified = false,
    this.differentPole = false,
    this.scannedBarcode,
  });

  @override
  State<PoleValidationFormRoute> createState() =>
      _PoleValidationFormRouteState();
}

class _PoleValidationFormRouteState extends State<PoleValidationFormRoute> {
  late final TextEditingController _barcode;
  late final TextEditingController _label;
  late final TextEditingController _notes;
  late final TextEditingController _accessNotes;
  late final TextEditingController _supervisorNote;
  late List<String> _tags;

  // Position editing (mirrors the author edit form): a reacquired fix
  // and/or a manually-dragged position override the stored point.
  LocationFix? _newFix;
  LatLng? _adjustedPosition;
  final _distance = const Distance();

  bool _busy = false;

  ValidationPoleSummary get _pole => widget.validation.pole!;

  bool get _editable =>
      widget.validation.status == ValidationStatus.assigned ||
      widget.validation.status == ValidationStatus.inProgress;

  @override
  void initState() {
    super.initState();
    _barcode =
        TextEditingController(text: widget.scannedBarcode ?? _pole.barcode);
    _label = TextEditingController(text: _pole.label ?? '');
    _notes = TextEditingController(text: _pole.notes ?? '');
    _accessNotes = TextEditingController(text: _pole.accessibilityNotes ?? '');
    _supervisorNote =
        TextEditingController(text: widget.validation.overallNotes ?? '');
    _tags = [..._pole.accessibilityTags];
  }

  @override
  void dispose() {
    _barcode.dispose();
    _label.dispose();
    _notes.dispose();
    _accessNotes.dispose();
    _supervisorNote.dispose();
    super.dispose();
  }

  // ── Position helpers (baseline = stored pole point unless reacquired) ─

  LocationFix _baselineFix() =>
      _newFix ??
      LocationFix(
        latitude: _pole.latitude,
        longitude: _pole.longitude,
        accuracyM: _pole.accuracyM ?? 0,
        timestamp: DateTime.now(),
      );

  bool get _positionChanged => _newFix != null || _adjustedPosition != null;

  LatLng get _effectivePosition {
    if (_adjustedPosition != null) return _adjustedPosition!;
    final f = _newFix;
    if (f != null) return LatLng(f.latitude, f.longitude);
    return LatLng(_pole.latitude, _pole.longitude);
  }

  double _recomputedOffsetM() {
    final base = _baselineFix();
    return _distance.as(LengthUnit.Meter,
        LatLng(base.latitude, base.longitude), _effectivePosition);
  }

  double? get _displayOffsetM =>
      _positionChanged ? _recomputedOffsetM() : _pole.manualOffsetM;

  Future<void> _reacquire() async {
    setState(() => _busy = true);
    try {
      final fix = await LocationService.getCurrent();
      if (!mounted) return;
      setState(() {
        _newFix = fix;
        _adjustedPosition = null;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _adjustOnMap() async {
    final base = _baselineFix();
    final result = await Navigator.of(context).push<AdjustPositionResult>(
      MaterialPageRoute(
        builder: (_) =>
            AdjustPositionRoute(initialPosition: _effectivePosition, gpsFix: base),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result.fix.timestamp != base.timestamp) _newFix = result.fix;
      final ref = _newFix ?? base;
      final m = _distance.as(LengthUnit.Meter,
          LatLng(ref.latitude, ref.longitude), result.position);
      _adjustedPosition = m >= 1 ? result.position : null;
    });
  }

  // ── Submit ────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _buildSuggestions() {
    final out = <Map<String, dynamic>>[];

    void text(String field, String current, String? original) {
      final c = current.trim();
      if (c != (original ?? '').trim()) {
        out.add({'field': field, 'suggested_value': c});
      }
    }

    // A validator shouldn't clear the barcode to empty; only suggest a
    // non-empty change.
    final barcode = _barcode.text.trim();
    if (barcode.isNotEmpty && barcode != _pole.barcode) {
      out.add({'field': 'barcode', 'suggested_value': barcode});
    }
    text('label', _label.text, _pole.label);
    text('notes', _notes.text, _pole.notes);
    text('accessibility_notes', _accessNotes.text, _pole.accessibilityNotes);

    final tagsChanged =
        _tags.toSet().difference(_pole.accessibilityTags.toSet()).isNotEmpty ||
            _pole.accessibilityTags.toSet().difference(_tags.toSet()).isNotEmpty;
    if (tagsChanged) {
      out.add({'field': 'accessibility_tags', 'suggested_value': jsonEncode(_tags)});
    }

    if (_positionChanged) {
      final p = _effectivePosition;
      out.add({
        'field': 'location',
        'suggested_value': jsonEncode({
          'latitude': p.latitude,
          'longitude': p.longitude,
          'accuracy_m': _baselineFix().accuracyM,
          'manual_offset_m': _recomputedOffsetM(),
        }),
      });
    }

    return out;
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final suggestions = _buildSuggestions();
    try {
      await widget.api.submitPoleValidation(
        widget.validation.id,
        physicallyVerified: widget.verified,
        overallNotes: _supervisorNote.text.trim(),
        suggestions: suggestions,
      );
      if (!mounted) return;
      final msg = suggestions.isEmpty
          ? 'Endorsed — no changes suggested.'
          : 'Submitted ${suggestions.length} suggestion(s) to the supervisor.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = e.response?.data?['error']?['detail'] ??
          e.response?.data?['errors']?.toString() ??
          e.message;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Submit failed: $detail')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Submit failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fixForCard = _newFix ??
        LocationFix(
          latitude: _pole.latitude,
          longitude: _pole.longitude,
          accuracyM: _pole.accuracyM ?? 0,
          timestamp: DateTime.now(),
        );

    return Scaffold(
      appBar: AppBar(title: Text(_pole.label ?? _pole.barcode)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.differentPole)
            _Banner(
              color: Colors.orange,
              icon: Icons.swap_horiz,
              text:
                  "Heads up: this isn't the pole you tapped. You scanned a different one assigned to you.",
            ),
          if (widget.scannedBarcode != null)
            _Banner(
              color: Colors.orange,
              icon: Icons.qr_code_scanner,
              text:
                  "The barcode you scanned isn't on file for this pole — it's filled in below as a suggested correction.",
            ),
          if (!_editable)
            _Banner(
              color: Colors.blueGrey,
              icon: Icons.lock_outline,
              text:
                  'This validation is ${validationStatusLabel(widget.validation.status)} and can no longer be edited.',
            )
          else
            _Banner(
              color: widget.verified ? Colors.green : Colors.blue,
              icon: widget.verified ? Icons.verified : Icons.rate_review,
              text: widget.verified
                  ? 'Scanned and verified. Change anything that’s wrong; submit unchanged to endorse it.'
                  : 'Change anything that’s wrong. Submitting sends your changes to the supervisor as suggestions; submit unchanged to endorse it.',
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _barcode,
            enabled: _editable,
            decoration: const InputDecoration(
              labelText: 'Barcode',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _label,
            enabled: _editable,
            decoration: const InputDecoration(
              labelText: 'Label (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text('Location', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (_editable)
            LocationCard(
              fix: fixForCard,
              error: null,
              busy: _busy,
              onRetry: _reacquire,
              adjustedPosition: _adjustedPosition,
              manualOffsetM: _displayOffsetM,
              onAdjust: _adjustOnMap,
            )
          else
            MiniLocationMap(
              latitude: _pole.latitude,
              longitude: _pole.longitude,
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _notes,
            enabled: _editable,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          AccessibilityTagsField(
            selected: _tags,
            primary: kPolePrimaryTags,
            onChanged: _editable
                ? (next) => setState(() => _tags = next)
                : (_) {},
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accessNotes,
            enabled: _editable,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Accessibility notes (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _supervisorNote,
            enabled: _editable,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Note to supervisor (optional)',
              hintText: 'Anything hard to capture as a field change',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          if (_editable)
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              label: const Text('Submit review'),
            ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const _Banner({required this.color, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
