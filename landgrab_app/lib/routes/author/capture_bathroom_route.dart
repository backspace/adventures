import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/accessibility.dart';
import 'package:landgrab/models/region.dart';
import 'package:landgrab/routes/author/edit_bathroom_route.dart';
import 'package:landgrab/services/discard_changes.dart';
import 'package:landgrab/services/location_service.dart';
import 'package:landgrab/widgets/accessibility_tags_field.dart';
import 'package:landgrab/widgets/action_snackbar.dart';
import 'package:landgrab/widgets/location_card.dart';
import 'package:landgrab/widgets/region_picker_field.dart';

/// Lightweight capture flow for a publicly-visible bathroom location.
/// Bathrooms skip the validation lifecycle — submit makes them live.
class CaptureBathroomRoute extends StatefulWidget {
  final LandgrabApi api;
  const CaptureBathroomRoute({super.key, required this.api});

  @override
  State<CaptureBathroomRoute> createState() => _CaptureBathroomRouteState();
}

class _CaptureBathroomRouteState extends State<CaptureBathroomRoute> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _accessibilityNotesController = TextEditingController();
  final _entryController = TextEditingController();

  LocationFix? _fix;
  String? _locationError;
  bool _gettingFix = false;
  bool _submitting = false;
  List<String> _accessibilityTags = const [];
  Region? _region;
  bool _saved = false;

  bool get _isDirty =>
      !_saved &&
      (_nameController.text.isNotEmpty ||
          _notesController.text.isNotEmpty ||
          _accessibilityNotesController.text.isNotEmpty ||
          _entryController.text.isNotEmpty ||
          _accessibilityTags.isNotEmpty ||
          _region != null);

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onTextChanged);
    _notesController.addListener(_onTextChanged);
    _accessibilityNotesController.addListener(_onTextChanged);
    _entryController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _captureLocation());
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _captureLocation() async {
    setState(() {
      _gettingFix = true;
      _locationError = null;
    });
    try {
      final fix = await LocationService.getCurrent();
      if (!mounted) return;
      setState(() {
        _fix = fix;
        _gettingFix = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = e.toString();
        _gettingFix = false;
      });
    }
  }

  Future<void> _submit() async {
    final fix = _fix;
    if (fix == null) return;

    setState(() => _submitting = true);
    try {
      final created = await widget.api.createBathroom(
        name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
        latitude: fix.latitude,
        longitude: fix.longitude,
        accuracyM: fix.accuracyM,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        accessibilityTags: _accessibilityTags.isEmpty ? null : _accessibilityTags,
        accessibilityNotes: _accessibilityNotesController.text.trim().isEmpty
            ? null
            : _accessibilityNotesController.text.trim(),
        entryInstructions: _entryController.text.trim().isEmpty
            ? null
            : _entryController.text.trim(),
        regionId: _region?.id,
      );
      if (!mounted) return;
      _saved = true;
      final api = widget.api;
      final navigator = Navigator.of(context, rootNavigator: true);
      final messenger = ScaffoldMessenger.of(context);
      showActionSnackBar(messenger, SnackBar(
        content: const Text('Bathroom added.'),
        action: SnackBarAction(
          label: 'Edit',
          onPressed: () {
            navigator.push(MaterialPageRoute(
              builder: (_) => EditBathroomRoute(api: api, bathroom: created),
            ));
          },
        ),
      ));
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final detail = e.response?.data?['error']?['detail'] ??
          e.response?.data?['errors']?.toString() ??
          e.message;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Submit failed: $detail')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Submit failed: $e')));
    }
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
    final canSubmit =
        _fix?.isAccurate == true && !_submitting;
    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await confirmDiscardChanges(context);
        if (discard && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Add bathroom')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocationCard(
                fix: _fix,
                error: _locationError,
                busy: _gettingFix,
                onRetry: _captureLocation,
              ),
              const SizedBox(height: 16),
              RegionPickerField(
                api: widget.api,
                selected: _region,
                onChanged: (r) => setState(() => _region = r),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name (optional)',
                  hintText: 'e.g. Main floor washrooms',
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
                  hintText: 'Anything players should know',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              AccessibilityTagsField(
                selected: _accessibilityTags,
                primary: kRegionPrimaryTags,
                onChanged: (next) => setState(() => _accessibilityTags = next),
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
                  hintText: 'e.g. Door code 1234',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: canSubmit ? _submit : null,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Add bathroom'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
