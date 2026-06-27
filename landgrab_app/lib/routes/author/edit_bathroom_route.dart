import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/accessibility.dart';
import 'package:landgrab/models/bathroom.dart';
import 'package:landgrab/models/region.dart';
import 'package:landgrab/services/discard_changes.dart';
import 'package:landgrab/services/location_service.dart';
import 'package:landgrab/widgets/accessibility_tags_field.dart';
import 'package:landgrab/widgets/action_snackbar.dart';
import 'package:landgrab/widgets/location_card.dart';
import 'package:landgrab/widgets/region_picker_field.dart';

class EditBathroomRoute extends StatefulWidget {
  final LandgrabApi api;
  final Bathroom bathroom;

  const EditBathroomRoute({super.key, required this.api, required this.bathroom});

  @override
  State<EditBathroomRoute> createState() => _EditBathroomRouteState();
}

class _EditBathroomRouteState extends State<EditBathroomRoute> {
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  late final TextEditingController _accessibilityNotesController;
  late final TextEditingController _entryController;
  late List<String> _accessibilityTags;
  Region? _region;
  bool _regionChanged = false;
  LocationFix? _newFix;
  String? _locationError;
  bool _gettingFix = false;
  bool _busy = false;
  bool _dirty = false;

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void initState() {
    super.initState();
    final b = widget.bathroom;
    _nameController = TextEditingController(text: b.name ?? '')..addListener(_markDirty);
    _notesController = TextEditingController(text: b.notes ?? '')..addListener(_markDirty);
    _accessibilityNotesController =
        TextEditingController(text: b.accessibilityNotes ?? '')..addListener(_markDirty);
    _entryController =
        TextEditingController(text: b.entryInstructions ?? '')..addListener(_markDirty);
    _accessibilityTags = [...b.accessibilityTags];

    if (b.regionId != null) {
      _loadRegion(b.regionId!);
    }
  }

  Future<void> _loadRegion(String id) async {
    try {
      final r = await widget.api.getRegion(id);
      if (!mounted) return;
      setState(() => _region = r);
    } catch (_) {
      // Best-effort.
    }
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
      final updated = await widget.api.updateBathroom(
        widget.bathroom.id,
        name: _nameController.text.trim(),
        latitude: _newFix?.latitude,
        longitude: _newFix?.longitude,
        accuracyM: _newFix?.accuracyM,
        notes: _notesController.text.trim(),
        accessibilityTags: _accessibilityTags,
        accessibilityNotes: _accessibilityNotesController.text.trim(),
        entryInstructions: _entryController.text.trim(),
        regionId: _regionChanged ? _region?.id : null,
        clearRegion: _regionChanged && _region == null,
      );
      if (!mounted) return;
      _dirty = false;
      final api = widget.api;
      final navigator = Navigator.of(context, rootNavigator: true);
      final messenger = ScaffoldMessenger.of(context);
      showActionSnackBar(messenger, SnackBar(
        content: const Text('Bathroom updated.'),
        action: SnackBarAction(
          label: 'Edit',
          onPressed: () {
            navigator.push(MaterialPageRoute(
              builder: (_) => EditBathroomRoute(api: api, bathroom: updated),
            ));
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
        title: const Text('Delete bathroom?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
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
      await widget.api.deleteBathroom(widget.bathroom.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Bathroom deleted.')));
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
    _nameController.dispose();
    _notesController.dispose();
    _accessibilityNotesController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bathroom;
    LocationFix? fixForCard = _newFix ??
        LocationFix(
          latitude: b.latitude,
          longitude: b.longitude,
          accuracyM: b.accuracyM ?? 0,
          timestamp: DateTime.now(),
        );

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await confirmDiscardChanges(context);
        if (discard && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit bathroom'),
          actions: [
            IconButton(
              tooltip: 'Delete',
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
              LocationCard(
                fix: fixForCard,
                error: _locationError,
                busy: _gettingFix,
                onRetry: _reacquireLocation,
              ),
              const SizedBox(height: 16),
              RegionPickerField(
                api: widget.api,
                selected: _region,
                onChanged: (r) => setState(() {
                  _region = r;
                  _regionChanged = true;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              AccessibilityTagsField(
                selected: _accessibilityTags,
                primary: kRegionPrimaryTags,
                onChanged: (next) => setState(() {
                  _accessibilityTags = next;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _accessibilityNotesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Accessibility notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _entryController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Entry instructions (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
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
