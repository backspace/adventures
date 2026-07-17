import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/validation.dart';
import 'package:landgrab/widgets/pole_form_fields.dart';

/// The validator's pole review form: the same fields the author edits
/// (via the shared [PoleFormFields]), pre-filled, in "suggest" mode.
/// Editing a field and submitting sends that change to the supervisor as
/// a suggestion; submitting unchanged endorses the pole. Never mutates
/// the pole directly.
///
/// Flags tune the header:
///  * [verified] — scanned this pole and it matched.
///  * [differentPole] — scanned a *different* assigned pole than tapped.
///  * [scannedBarcode] — an unknown scan; pre-fill it as a barcode fix.
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
  final _poleFields = GlobalKey<PoleFormFieldsState>();
  late final TextEditingController _barcode;
  late final TextEditingController _supervisorNote;
  bool _busy = false;

  ValidationPoleSummary get _pole => widget.validation.pole!;

  /// Field → suggested value from any already-submitted suggestions on
  /// this validation, so re-opening shows the pending edits (not a blank
  /// slate that would silently withdraw them on the next submit).
  late final Map<String, String> _pending = {
    for (final c in widget.validation.comments)
      if (c.suggestedValue != null) c.field: c.suggestedValue!,
  };

  List<String> get _initialTags {
    final raw = _pending['accessibility_tags'];
    if (raw == null) return _pole.accessibilityTags;
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return _pole.accessibilityTags;
    }
  }

  LatLng? get _initialAdjustedPosition {
    final raw = _pending['location'];
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final lat = (m['latitude'] as num?)?.toDouble();
      final lng = (m['longitude'] as num?)?.toDouble();
      return (lat == null || lng == null) ? null : LatLng(lat, lng);
    } catch (_) {
      return null;
    }
  }

  // Editable until the supervisor decides — a validator can revise or
  // withdraw a submission right up to accept/reject.
  bool get _editable =>
      widget.validation.status != ValidationStatus.accepted &&
      widget.validation.status != ValidationStatus.rejected;

  @override
  void initState() {
    super.initState();
    _barcode = TextEditingController(
        text: widget.scannedBarcode ?? _pending['barcode'] ?? _pole.barcode);
    _supervisorNote =
        TextEditingController(text: widget.validation.overallNotes ?? '');
  }

  @override
  void dispose() {
    _barcode.dispose();
    _supervisorNote.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _buildSuggestions() {
    final out = <Map<String, dynamic>>[];
    final data = _poleFields.currentState!.data;

    void text(String field, String current, String? original) {
      final c = current.trim();
      if (c != (original ?? '').trim()) {
        out.add({'field': field, 'suggested_value': c});
      }
    }

    // A validator shouldn't clear the barcode; only suggest a non-empty change.
    final barcode = _barcode.text.trim();
    if (barcode.isNotEmpty && barcode != _pole.barcode) {
      out.add({'field': 'barcode', 'suggested_value': barcode});
    }
    text('label', data.label, _pole.label);
    text('notes', data.notes, _pole.notes);
    text('accessibility_notes', data.accessibilityNotes, _pole.accessibilityNotes);

    final tagsChanged = data.accessibilityTags.toSet().difference(
                _pole.accessibilityTags.toSet()).isNotEmpty ||
        _pole.accessibilityTags.toSet().difference(
                data.accessibilityTags.toSet()).isNotEmpty;
    if (tagsChanged) {
      out.add({
        'field': 'accessibility_tags',
        'suggested_value': jsonEncode(data.accessibilityTags),
      });
    }

    if (data.positionChanged) {
      out.add({
        'field': 'location',
        'suggested_value': jsonEncode({
          'latitude': data.position.latitude,
          'longitude': data.position.longitude,
          'accuracy_m': data.accuracyM,
          'manual_offset_m': data.manualOffsetM,
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
    return Scaffold(
      appBar: AppBar(title: Text(_pole.label ?? _pole.barcode)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.differentPole)
            const _Banner(
              color: Colors.orange,
              icon: Icons.swap_horiz,
              text:
                  "Heads up: this isn't the pole you tapped. You scanned a different one assigned to you.",
            ),
          if (widget.scannedBarcode != null)
            const _Banner(
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
          const SizedBox(height: 16),
          // Ignore edits when the validation is read-only.
          IgnorePointer(
            ignoring: !_editable,
            child: Opacity(
              opacity: _editable ? 1 : 0.6,
              child: PoleFormFields(
                key: _poleFields,
                initialLatitude: _pole.latitude,
                initialLongitude: _pole.longitude,
                initialAccuracyM: _pole.accuracyM,
                initialManualOffsetM: _pole.manualOffsetM,
                initialLabel: _pending['label'] ?? _pole.label,
                initialNotes: _pending['notes'] ?? _pole.notes,
                initialAccessibilityTags: _initialTags,
                initialAccessibilityNotes:
                    _pending['accessibility_notes'] ?? _pole.accessibilityNotes,
                initialAdjustedPosition: _initialAdjustedPosition,
              ),
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
