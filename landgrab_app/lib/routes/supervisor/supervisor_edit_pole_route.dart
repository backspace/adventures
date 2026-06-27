import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/accessibility.dart';
import 'package:landgrab/models/draft.dart';
import 'package:landgrab/services/discard_changes.dart';
import 'package:landgrab/widgets/accessibility_tags_field.dart';

class SupervisorEditPoleRoute extends StatefulWidget {
  final LandgrabApi api;
  final DraftPole pole;

  const SupervisorEditPoleRoute({
    super.key,
    required this.api,
    required this.pole,
  });

  @override
  State<SupervisorEditPoleRoute> createState() => _SupervisorEditPoleRouteState();
}

class _SupervisorEditPoleRouteState extends State<SupervisorEditPoleRoute> {
  late final TextEditingController _barcode;
  late final TextEditingController _label;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _notes;
  late final TextEditingController _accessibilityNotes;
  late List<String> _accessibilityTags;
  bool _busy = false;
  bool _dirty = false;

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void initState() {
    super.initState();
    _barcode = TextEditingController(text: widget.pole.barcode)
      ..addListener(_markDirty);
    _label = TextEditingController(text: widget.pole.label ?? '')
      ..addListener(_markDirty);
    _latitude = TextEditingController(text: widget.pole.latitude.toString())
      ..addListener(_markDirty);
    _longitude = TextEditingController(text: widget.pole.longitude.toString())
      ..addListener(_markDirty);
    _notes = TextEditingController(text: widget.pole.notes ?? '')
      ..addListener(_markDirty);
    _accessibilityNotes =
        TextEditingController(text: widget.pole.accessibilityNotes ?? '')
          ..addListener(_markDirty);
    _accessibilityTags = [...widget.pole.accessibilityTags];
  }

  @override
  void dispose() {
    _barcode.dispose();
    _label.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _notes.dispose();
    _accessibilityNotes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final lat = double.tryParse(_latitude.text.trim());
    final lng = double.tryParse(_longitude.text.trim());

    if (_barcode.text.trim().isEmpty || lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barcode and valid coordinates are required.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final updated = await widget.api.supervisorEditPole(
        widget.pole.id,
        barcode: _barcode.text.trim(),
        label: _label.text.trim(),
        notes: _notes.text.trim(),
        latitude: lat,
        longitude: lng,
        accessibilityTags: _accessibilityTags,
        accessibilityNotes: _accessibilityNotes.text.trim(),
      );
      if (!mounted) return;
      _dirty = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pole updated.')),
      );
      Navigator.of(context).pop(updated);
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = e.response?.data?['error']?['detail'] ??
          e.response?.data?['errors']?.toString() ??
          e.message;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save failed: $detail')));
    }
  }

  @override
  Widget build(BuildContext context) {
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
        appBar: AppBar(title: const Text('Edit pole')),
        body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _barcode,
              decoration: const InputDecoration(
                labelText: 'Barcode',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _label,
              decoration: const InputDecoration(
                labelText: 'Label',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latitude,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true, decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _longitude,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true, decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
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
              controller: _accessibilityNotes,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Accessibility notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
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
