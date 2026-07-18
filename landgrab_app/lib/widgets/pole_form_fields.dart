import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:landgrab/models/accessibility.dart';
import 'package:landgrab/routes/author/adjust_position_route.dart';
import 'package:landgrab/services/location_service.dart';
import 'package:landgrab/widgets/accessibility_tags_field.dart';
import 'package:landgrab/widgets/location_card.dart';

/// Snapshot of the editable pole fields, read from [PoleFormFieldsState.data]
/// at submit time by whichever wrapper owns the form.
class PoleFormData {
  final String label;
  final String notes;
  final List<String> accessibilityTags;
  final String accessibilityNotes;

  /// The position the marker currently sits at (dragged / reacquired, or
  /// the original if untouched).
  final LatLng position;

  /// Accuracy of the GPS fix the position is measured against.
  final double accuracyM;

  /// Whether the position was reacquired or dragged this session.
  final bool positionChanged;

  /// Metres the marker was moved from the GPS fix (0 when unchanged).
  final double manualOffsetM;

  PoleFormData({
    required this.label,
    required this.notes,
    required this.accessibilityTags,
    required this.accessibilityNotes,
    required this.position,
    required this.accuracyM,
    required this.positionChanged,
    required this.manualOffsetM,
  });
}

/// The pole fields shared by the author edit form and the validator
/// suggest form: location (with reacquire + drag-to-adjust + offset
/// tracking), label, notes, accessibility tags, and accessibility notes.
///
/// Barcode, timestamps, attachments (author) and the notice banners /
/// supervisor note (validator) live in the respective wrappers — this
/// owns only what both edit identically, so they can't drift. Read the
/// current values via a `GlobalKey<PoleFormFieldsState>().currentState!.data`.
class PoleFormFields extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final double? initialAccuracyM;
  final double? initialManualOffsetM;
  final String? initialLabel;
  final String? initialNotes;
  final List<String> initialAccessibilityTags;
  final String? initialAccessibilityNotes;

  /// A position override to start with — used when re-opening a
  /// validation whose pending suggestion already moved the marker, so
  /// the suggestion is preserved (and re-emitted) rather than silently
  /// dropped. Treated exactly like an in-session drag.
  final LatLng? initialAdjustedPosition;

  /// Fired on any edit, so a wrapper that tracks dirty state (the author
  /// form's discard-changes guard) can mark itself dirty.
  final VoidCallback? onChanged;

  const PoleFormFields({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    this.initialAccuracyM,
    this.initialManualOffsetM,
    this.initialLabel,
    this.initialNotes,
    this.initialAccessibilityTags = const [],
    this.initialAccessibilityNotes,
    this.initialAdjustedPosition,
    this.onChanged,
  });

  @override
  PoleFormFieldsState createState() => PoleFormFieldsState();
}

class PoleFormFieldsState extends State<PoleFormFields> {
  late final TextEditingController _label;
  late final TextEditingController _notes;
  late final TextEditingController _accessNotes;
  late List<String> _tags;

  LocationFix? _newFix;
  LatLng? _adjustedPosition;
  final _distance = const Distance();
  String? _locationError;
  bool _gettingFix = false;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.initialLabel ?? '')
      ..addListener(_notify);
    _notes = TextEditingController(text: widget.initialNotes ?? '')
      ..addListener(_notify);
    _accessNotes =
        TextEditingController(text: widget.initialAccessibilityNotes ?? '')
          ..addListener(_notify);
    _tags = [...widget.initialAccessibilityTags];
    _adjustedPosition = widget.initialAdjustedPosition;
  }

  @override
  void dispose() {
    _label.dispose();
    _notes.dispose();
    _accessNotes.dispose();
    super.dispose();
  }

  void _notify() => widget.onChanged?.call();

  // The GPS point the offset is measured from: a fresh reacquire if there
  // is one, otherwise the pole's stored position (we didn't keep the raw
  // original reading, so an un-reacquired edit measures the drag from
  // where the pole currently sits).
  LocationFix _baselineFix() =>
      _newFix ??
      LocationFix(
        latitude: widget.initialLatitude,
        longitude: widget.initialLongitude,
        accuracyM: widget.initialAccuracyM ?? 0,
        timestamp: DateTime.now(),
      );

  bool get _positionChanged => _newFix != null || _adjustedPosition != null;

  LatLng get _effectivePosition {
    if (_adjustedPosition != null) return _adjustedPosition!;
    final f = _newFix;
    if (f != null) return LatLng(f.latitude, f.longitude);
    return LatLng(widget.initialLatitude, widget.initialLongitude);
  }

  double _recomputedOffsetM() {
    final base = _baselineFix();
    return _distance.as(LengthUnit.Meter,
        LatLng(base.latitude, base.longitude), _effectivePosition);
  }

  double? get _displayOffsetM =>
      _positionChanged ? _recomputedOffsetM() : widget.initialManualOffsetM;

  /// Current field values — read at submit time.
  PoleFormData get data => PoleFormData(
        label: _label.text.trim(),
        notes: _notes.text.trim(),
        accessibilityTags: List.of(_tags),
        accessibilityNotes: _accessNotes.text.trim(),
        position: _effectivePosition,
        accuracyM: _baselineFix().accuracyM,
        positionChanged: _positionChanged,
        manualOffsetM: _recomputedOffsetM(),
      );

  Future<void> _reacquire() async {
    setState(() {
      _gettingFix = true;
      _locationError = null;
    });
    try {
      final fix = await LocationService.getCurrent(context: context);
      if (!mounted) return;
      setState(() {
        _newFix = fix;
        _adjustedPosition = null; // fresh reading = fresh baseline
        _gettingFix = false;
      });
      _notify();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = e.toString();
        _gettingFix = false;
      });
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
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final fixForCard = _newFix ??
        LocationFix(
          latitude: widget.initialLatitude,
          longitude: widget.initialLongitude,
          accuracyM: widget.initialAccuracyM ?? 0,
          timestamp: DateTime.now(),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LocationCard(
          fix: fixForCard,
          error: _locationError,
          busy: _gettingFix,
          onRetry: _reacquire,
          adjustedPosition: _adjustedPosition,
          manualOffsetM: _displayOffsetM,
          onAdjust: _adjustOnMap,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _label,
          decoration: const InputDecoration(
            labelText: 'Label (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notes for validators (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        AccessibilityTagsField(
          selected: _tags,
          primary: kPolePrimaryTags,
          onChanged: (next) {
            setState(() => _tags = next);
            _notify();
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _accessNotes,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Accessibility notes (optional)',
            hintText: 'Anything tags don\'t cover',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
