import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/accessibility.dart';
import 'package:landgrab/models/draft.dart';
import 'package:landgrab/routes/author/adjust_position_route.dart';
import 'package:landgrab/services/discard_changes.dart';
import 'package:landgrab/services/location_service.dart';
import 'package:landgrab/widgets/accessibility_tags_field.dart';
import 'package:landgrab/widgets/action_snackbar.dart';
import 'package:landgrab/widgets/attachments_section.dart';
import 'package:landgrab/widgets/location_card.dart';
import 'package:landgrab/widgets/record_timestamps.dart';

class EditPoleRoute extends StatefulWidget {
  final LandgrabApi api;
  final DraftPole pole;

  const EditPoleRoute({super.key, required this.api, required this.pole});

  @override
  State<EditPoleRoute> createState() => _EditPoleRouteState();
}

class _EditPoleRouteState extends State<EditPoleRoute> {
  late final TextEditingController _labelController;
  late final TextEditingController _notesController;
  late final TextEditingController _accessibilityNotesController;
  late List<String> _accessibilityTags;

  LocationFix? _newFix;
  // Manually-dragged marker position (overrides GPS) for this session.
  LatLng? _adjustedPosition;
  final _distance = const Distance();
  String? _locationError;
  bool _gettingFix = false;
  bool _busy = false;
  bool _dirty = false;

  /// The GPS point the offset is measured from: a fresh reacquire if
  /// there is one, otherwise the pole's stored position (we didn't keep
  /// the original raw reading, so an un-reacquired edit measures the
  /// drag from where the pole currently sits).
  LocationFix _baselineFix() =>
      _newFix ??
      LocationFix(
        latitude: widget.pole.latitude,
        longitude: widget.pole.longitude,
        accuracyM: widget.pole.accuracyM ?? 0,
        timestamp: DateTime.now(),
      );

  bool get _positionChanged => _newFix != null || _adjustedPosition != null;

  LatLng get _effectivePosition {
    if (_adjustedPosition != null) return _adjustedPosition!;
    final f = _newFix;
    if (f != null) return LatLng(f.latitude, f.longitude);
    return LatLng(widget.pole.latitude, widget.pole.longitude);
  }

  double _recomputedOffsetM() {
    final base = _baselineFix();
    return _distance.as(
        LengthUnit.Meter, LatLng(base.latitude, base.longitude), _effectivePosition);
  }

  /// Offset to show on the card: the freshly-computed value once the
  /// position has been touched, otherwise whatever was stored.
  double? get _displayOffsetM =>
      _positionChanged ? _recomputedOffsetM() : widget.pole.manualOffsetM;

  Future<void> _adjustOnMap() async {
    final base = _baselineFix();
    final result = await Navigator.of(context).push<AdjustPositionResult>(
      MaterialPageRoute(
        builder: (_) => AdjustPositionRoute(
          initialPosition: _effectivePosition,
          gpsFix: base,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _dirty = true;
      // Adopt a reacquire done inside the editor; keep the drag only if real.
      if (result.fix.timestamp != base.timestamp) _newFix = result.fix;
      final refFix = _newFix ?? base;
      final m = _distance.as(LengthUnit.Meter,
          LatLng(refFix.latitude, refFix.longitude), result.position);
      _adjustedPosition = m >= 1 ? result.position : null;
    });
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.pole.label ?? '')
      ..addListener(_markDirty);
    _notesController = TextEditingController(text: widget.pole.notes ?? '')
      ..addListener(_markDirty);
    _accessibilityNotesController =
        TextEditingController(text: widget.pole.accessibilityNotes ?? '')
          ..addListener(_markDirty);
    _accessibilityTags = [...widget.pole.accessibilityTags];
  }

  Future<void> _reacquireLocation() async {
    setState(() {
      _gettingFix = true;
      _locationError = null;
    });
    try {
      final fix = await LocationService.getCurrent();
      if (!mounted) return;
      setState(() {
        _newFix = fix;
        // Fresh reading = fresh baseline; drop any manual drag.
        _adjustedPosition = null;
        _gettingFix = false;
        _dirty = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = e.toString();
        _gettingFix = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final changed = _positionChanged;
      final updated = await widget.api.updateDraftPole(
        widget.pole.id,
        label: _labelController.text.trim(),
        notes: _notesController.text.trim(),
        latitude: changed ? _effectivePosition.latitude : null,
        longitude: changed ? _effectivePosition.longitude : null,
        accuracyM: changed ? _baselineFix().accuracyM : null,
        manualOffsetM: changed ? _recomputedOffsetM() : null,
        accessibilityTags: _accessibilityTags,
        accessibilityNotes: _accessibilityNotesController.text.trim(),
      );
      if (!mounted) return;
      _dirty = false;
      final api = widget.api;
      final navigator = Navigator.of(context, rootNavigator: true);
      final messenger = ScaffoldMessenger.of(context);
      showActionSnackBar(messenger, SnackBar(
        content: const Text('Draft updated.'),
        action: SnackBarAction(
          label: 'Edit',
          onPressed: () {
            navigator.push(
              MaterialPageRoute(builder: (_) => EditPoleRoute(api: api, pole: updated)),
            );
          },
        ),
      ));
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      _showError(e);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete draft?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await widget.api.deleteDraftPole(widget.pole.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Draft deleted.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  void _showError(DioException e) {
    if (!mounted) return;
    final detail = e.response?.data?['error']?['detail'] ??
        e.response?.data?['errors']?.toString() ??
        e.message;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Save failed: $detail')));
  }

  @override
  void dispose() {
    _labelController.dispose();
    _notesController.dispose();
    _accessibilityNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final original = widget.pole;
    final fixForCard = _newFix ??
        LocationFix(
          latitude: original.latitude,
          longitude: original.longitude,
          accuracyM: original.accuracyM ?? 0,
          timestamp: DateTime.now(),
        );

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await confirmDiscardChanges(context);
        if (discard && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit pole'),
        actions: [
          IconButton(
            tooltip: 'Delete draft',
            onPressed: _busy ? null : _delete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Barcode: ${original.barcode}',
                style: Theme.of(context).textTheme.titleMedium),
            RecordTimestamps(
              createdAt: original.insertedAt,
              updatedAt: original.updatedAt,
            ),
            const SizedBox(height: 16),
            LocationCard(
              fix: fixForCard,
              error: _locationError,
              busy: _gettingFix,
              onRetry: _reacquireLocation,
              adjustedPosition: _adjustedPosition,
              manualOffsetM: _displayOffsetM,
              onAdjust: _adjustOnMap,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Label (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes for validators (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            AccessibilityTagsField(
              selected: _accessibilityTags,
              primary: kPolePrimaryTags,
              onChanged: (next) {
                setState(() {
                  _accessibilityTags = next;
                  _dirty = true;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _accessibilityNotesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Accessibility notes (optional)',
                hintText: 'Anything tags don\'t cover',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            AttachmentsSection(
              api: widget.api,
              kind: AttachmentParentKind.pole,
              parentId: widget.pole.id,
              initialIds: widget.pole.attachmentIds,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text('Save changes'),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
