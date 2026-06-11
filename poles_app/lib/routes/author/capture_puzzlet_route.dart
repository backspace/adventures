import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/accessibility.dart';
import 'package:poles/models/region.dart';
import 'package:poles/routes/author/edit_puzzlet_route.dart';
import 'package:poles/routes/author/promote_to_region_dialog.dart';
import 'package:poles/models/draft.dart';
import 'package:poles/routes/barcode_scanner_route.dart';
import 'package:poles/routes/nfc_scanner_route.dart';
import 'package:poles/services/discard_changes.dart';
import 'package:poles/services/geo.dart';
import 'package:poles/services/location_service.dart';
import 'package:poles/widgets/accessibility_tags_field.dart';
import 'package:poles/widgets/answer_type_field.dart';
import 'package:poles/widgets/location_card.dart';
import 'package:poles/widgets/action_snackbar.dart';
import 'package:poles/widgets/pending_photos_section.dart';
import 'package:poles/widgets/region_picker_field.dart';

/// Distance in meters within which other region-less puzzlets are
/// considered "nearby" enough to suggest grouping with the one being
/// captured. Tuned for the rough scale of one building's footprint.
const double _kNearbyRadiusM = 30;

class CapturePuzzletRoute extends StatefulWidget {
  final PolesApi api;
  const CapturePuzzletRoute({super.key, required this.api});

  @override
  State<CapturePuzzletRoute> createState() => _CapturePuzzletRouteState();
}

class _CapturePuzzletRouteState extends State<CapturePuzzletRoute> {
  final _instructionsController = TextEditingController();
  final _answerController = TextEditingController();
  final _accessibilityNotesController = TextEditingController();
  final _warningController = TextEditingController();
  int _difficulty = 3;
  bool _submitting = false;
  List<Uint8List> _pendingPhotos = const [];
  List<String> _accessibilityTags = const [];
  AnswerType _answerType = AnswerType.looseText;
  Region? _region;
  bool _saved = false;

  bool get _isDirty =>
      !_saved &&
      (_instructionsController.text.isNotEmpty ||
          _answerController.text.isNotEmpty ||
          _pendingPhotos.isNotEmpty ||
          _accessibilityTags.isNotEmpty ||
          _accessibilityNotesController.text.isNotEmpty ||
          _warningController.text.isNotEmpty ||
          _difficulty != 3 ||
          _answerType != AnswerType.looseText ||
          _region != null);

  LocationFix? _fix;
  String? _locationError;
  bool _gettingFix = false;

  @override
  void initState() {
    super.initState();
    _captureLocation();
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

  Future<void> _scanAnswer() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            const BarcodeScannerRoute(title: 'Scan answer barcode'),
      ),
    );
    if (scanned == null || scanned.isEmpty) return;
    setState(() {
      _answerController.text = scanned;
      _answerType = AnswerType.barcode;
    });
  }

  Future<void> _scanNfcAnswer() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const NfcScannerRoute(title: 'Scan answer NFC tag'),
      ),
    );
    if (scanned == null || scanned.isEmpty) return;
    setState(() {
      _answerController.text = scanned;
      _answerType = AnswerType.nfc;
    });
  }

  Future<void> _submit() async {
    final instructions = _instructionsController.text.trim();
    final answer = _answerController.text.trim();
    final fix = _fix;
    if (instructions.isEmpty || answer.isEmpty || fix == null || !fix.isUsable) return;

    setState(() => _submitting = true);
    try {
      final created = await widget.api.createDraftPuzzlet(
        instructions: instructions,
        answer: answer,
        answerType: _answerType,
        difficulty: _difficulty,
        latitude: fix.latitude,
        longitude: fix.longitude,
        accuracyM: fix.accuracyM,
        accessibilityTags: _accessibilityTags,
        accessibilityNotes: _accessibilityNotesController.text.trim().isEmpty
            ? null
            : _accessibilityNotesController.text.trim(),
        regionId: _region?.id,
        warning: _warningController.text.trim().isEmpty
            ? null
            : _warningController.text.trim(),
      );

      final uploadedIds = <String>[];
      final photoErrors = <String>[];
      for (final bytes in _pendingPhotos) {
        try {
          final id = await widget.api.uploadPuzzletAttachment(
            puzzletId: created.id,
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

      // Geographic nudge: if this puzzlet has no region, look for other
      // region-less puzzlets the same author has placed nearby and offer
      // to group them. Skipped silently when the new puzzlet already has
      // a region, when nothing nearby qualifies, or when the lookup
      // fails — we don't want to block the capture flow on this.
      if (_region == null) {
        await _maybeOfferNearbyGrouping(fresh);
        if (!mounted) return;
      }

      final message = photoErrors.isEmpty
          ? 'Puzzlet submitted as draft.'
          : 'Puzzlet saved; ${photoErrors.length} photo(s) failed to upload.';
      final api = widget.api;
      final navigator = Navigator.of(context, rootNavigator: true);
      final messenger = ScaffoldMessenger.of(context);
      showActionSnackBar(messenger, SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Edit',
          onPressed: () {
            navigator.push(
              MaterialPageRoute(builder: (_) => EditPuzzletRoute(api: api, puzzlet: fresh)),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Submit failed: $detail')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Submit failed: $e')));
    }
  }

  /// After a puzzlet without a region is created, look for other
  /// region-less puzzlets the author placed nearby. If any qualify, offer
  /// to group them all (including the new one) into a region via the
  /// shared promotion dialog. Best-effort: any failure is swallowed so it
  /// can't break the capture flow.
  Future<void> _maybeOfferNearbyGrouping(DraftPuzzlet fresh) async {
    if (fresh.latitude == null || fresh.longitude == null) return;
    final List<DraftPuzzlet> nearby;
    try {
      final drafts = await widget.api.listMyDrafts();
      nearby = drafts.puzzlets.where((p) {
        if (p.id == fresh.id) return false;
        if (p.regionId != null) return false;
        if (p.latitude == null || p.longitude == null) return false;
        return distanceMeters(
              fresh.latitude!,
              fresh.longitude!,
              p.latitude!,
              p.longitude!,
            ) <=
            _kNearbyRadiusM;
      }).toList(growable: false);
    } catch (_) {
      return;
    }

    if (nearby.isEmpty || !mounted) return;

    final group = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Group nearby puzzlets?'),
        content: Text(
          '${nearby.length} other puzzlet${nearby.length == 1 ? '' : 's'} '
          'you\'ve drafted within ${_kNearbyRadiusM.toStringAsFixed(0)}m '
          '${nearby.length == 1 ? 'has' : 'have'} no region. '
          'Group ${nearby.length == 1 ? 'it' : 'them'} together with this '
          'one into a new or existing region?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Group'),
          ),
        ],
      ),
    );

    if (group != true || !mounted) return;

    await showDialog<PromoteResult>(
      context: context,
      builder: (_) => PromoteToRegionDialog(
        api: widget.api,
        puzzlets: [fresh, ...nearby],
      ),
    );
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    _answerController.dispose();
    _accessibilityNotesController.dispose();
    _warningController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _fix?.isUsable == true &&
        !_submitting &&
        _instructionsController.text.trim().isNotEmpty &&
        _answerController.text.trim().isNotEmpty;

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
        appBar: AppBar(title: const Text('Submit a puzzlet')),
        body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Puzzlets are pooled and assigned to poles later by an admin. '
              'Capturing your location now helps the admin pair this puzzlet with the right pole. '
              'Difficulty is your initial estimate; validators may adjust it.',
              style: Theme.of(context).textTheme.bodySmall,
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
              controller: _instructionsController,
              minLines: 3,
              maxLines: 6,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Instructions',
                hintText: 'What does the player need to find or do?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _warningController,
              maxLines: 2,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Warning (optional)',
                hintText: 'Shown prominently to players. Use for safety / practical alerts.',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.warning_amber_outlined),
              ),
            ),
            const SizedBox(height: 12),
            AnswerTypeField(
              value: _answerType,
              onChanged: (t) => setState(() => _answerType = t),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _answerController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Answer',
                border: const OutlineInputBorder(),
                suffixIcon: switch (_answerType) {
                  AnswerType.barcode => IconButton(
                      tooltip: 'Scan barcode as answer',
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: _scanAnswer,
                    ),
                  AnswerType.nfc => IconButton(
                      tooltip: 'Scan NFC tag as answer',
                      icon: const Icon(Icons.contactless),
                      onPressed: _scanNfcAnswer,
                    ),
                  _ => null,
                },
              ),
            ),
            const SizedBox(height: 16),
            Text('Difficulty: $_difficulty / 10'),
            Slider(
              value: _difficulty.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '$_difficulty',
              onChanged: (v) => setState(() => _difficulty = v.round()),
            ),
            const SizedBox(height: 16),
            RegionPickerField(
              api: widget.api,
              selected: _region,
              onChanged: (r) => setState(() => _region = r),
            ),
            const SizedBox(height: 16),
            AccessibilityTagsField(
              selected: _accessibilityTags,
              primary: kPuzzletPrimaryTags,
              onChanged: (next) {
                setState(() => _accessibilityTags = next);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _accessibilityNotesController,
              maxLines: 2,
              onChanged: (_) => setState(() {}),
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
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: canSubmit ? _submit : null,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload),
              label: const Text('Submit draft'),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
