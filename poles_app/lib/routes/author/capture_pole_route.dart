import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/accessibility.dart';
import 'package:poles/widgets/action_snackbar.dart';
import 'package:poles/routes/author/edit_pole_route.dart';
import 'package:poles/routes/barcode_scanner_route.dart';
import 'package:poles/services/discard_changes.dart';
import 'package:poles/services/location_service.dart';
import 'package:poles/widgets/accessibility_tags_field.dart';
import 'package:poles/widgets/location_card.dart';
import 'package:poles/widgets/pending_photos_section.dart';

class CapturePoleRoute extends StatefulWidget {
  final PolesApi api;
  const CapturePoleRoute({super.key, required this.api});

  @override
  State<CapturePoleRoute> createState() => _CapturePoleRouteState();
}

class _CapturePoleRouteState extends State<CapturePoleRoute> {
  late final TextEditingController _labelController;
  late final TextEditingController _notesController;

  String? _barcode;
  LocationFix? _fix;
  String? _locationError;
  bool _gettingFix = false;
  bool _submitting = false;
  List<Uint8List> _pendingPhotos = const [];
  List<String> _accessibilityTags = const [];
  final _accessibilityNotesController = TextEditingController();
  bool _saved = false;

  bool get _isDirty =>
      !_saved &&
      (_labelController.text.isNotEmpty ||
          _notesController.text.isNotEmpty ||
          _pendingPhotos.isNotEmpty ||
          _accessibilityTags.isNotEmpty ||
          _accessibilityNotesController.text.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController()..addListener(_onTextChanged);
    _notesController = TextEditingController()..addListener(_onTextChanged);
    _accessibilityNotesController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _launchInitialScan());
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _launchInitialScan() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerRoute(title: 'Scan a pole'),
      ),
    );
    if (!mounted) return;
    if (scanned == null || scanned.isEmpty) {
      // User backed out of the scanner without picking a barcode — close
      // the capture flow too.
      Navigator.of(context).pop();
      return;
    }
    setState(() => _barcode = scanned);
    _captureLocation();
  }

  Future<void> _rescan() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerRoute(title: 'Scan a pole'),
      ),
    );
    if (scanned == null || scanned.isEmpty || !mounted) return;
    setState(() => _barcode = scanned);
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
    final barcode = _barcode;
    if (fix == null || barcode == null) return;

    setState(() => _submitting = true);
    try {
      final created = await widget.api.createDraftPole(
        barcode: barcode,
        latitude: fix.latitude,
        longitude: fix.longitude,
        accuracyM: fix.accuracyM,
        label: _labelController.text.trim().isEmpty ? null : _labelController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        accessibilityTags: _accessibilityTags,
        accessibilityNotes: _accessibilityNotesController.text.trim().isEmpty
            ? null
            : _accessibilityNotesController.text.trim(),
      );

      final uploadedIds = <String>[];
      final photoErrors = <String>[];
      for (final bytes in _pendingPhotos) {
        try {
          final id = await widget.api.uploadPoleAttachment(
            poleId: created.id,
            bytes: bytes,
            filename: 'photo.jpg',
            contentType: 'image/jpeg',
          );
          uploadedIds.add(id);
        } catch (e) {
          photoErrors.add(e.toString());
        }
      }

      if (!mounted) return;
      _saved = true;
      final fresh = created.copyWith(
        attachmentIds: [...created.attachmentIds, ...uploadedIds],
      );
      final message = photoErrors.isEmpty
          ? 'Pole submitted as draft.'
          : 'Pole saved; ${photoErrors.length} photo(s) failed to upload.';
      final api = widget.api;
      final navigator = Navigator.of(context, rootNavigator: true);
      final messenger = ScaffoldMessenger.of(context);
      showActionSnackBar(messenger, SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Edit',
          onPressed: () {
            navigator.push(
              MaterialPageRoute(builder: (_) => EditPoleRoute(api: api, pole: fresh)),
            );
          },
        ),
      ));
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = e.response?.data?['error']?['detail'] ??
          e.response?.data?['errors']?.toString() ??
          e.message;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submit failed: $detail')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
    }
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
    // Accuracy is the hard requirement; freshness is a soft warning so
    // the author can re-acquire if they've moved.
    final canSubmit =
        _barcode != null && (_fix?.isAccurate ?? false) && !_submitting;
    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await confirmDiscardChanges(context);
        if (discard && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Capture a pole')),
        body: _barcode == null
            ? const Center(child: CircularProgressIndicator())
            : _form(canSubmit),
      ),
    );
  }

  Widget _form(bool canSubmit) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('Barcode: $_barcode',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              TextButton(onPressed: _rescan, child: const Text('Re-scan')),
            ],
          ),
          const SizedBox(height: 16),
          LocationCard(
            fix: _fix,
            error: _locationError,
            busy: _gettingFix,
            onRetry: _captureLocation,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Label (optional)',
              hintText: 'e.g. Portage and Main',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes for validators (optional)',
              hintText: 'Anything tricky about finding it',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          AccessibilityTagsField(
            selected: _accessibilityTags,
            primary: kPolePrimaryTags,
            onChanged: (next) => setState(() => _accessibilityTags = next),
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
          const SizedBox(height: 16),
          PendingPhotosSection(
            bytes: _pendingPhotos,
            onChanged: (next) => setState(() => _pendingPhotos = next),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: canSubmit ? _submit : null,
            icon: _submitting
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload),
            label: const Text('Submit draft'),
          ),
        ],
      ),
    );
  }
}
