import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/accessibility.dart';
import 'package:poles/models/draft.dart';
import 'package:poles/routes/barcode_scanner_route.dart';
import 'package:poles/services/discard_changes.dart';
import 'package:poles/services/location_service.dart';
import 'package:poles/widgets/accessibility_tags_field.dart';
import 'package:poles/widgets/answer_type_field.dart';
import 'package:poles/widgets/attachments_section.dart';
import 'package:poles/widgets/location_card.dart';

class EditPuzzletRoute extends StatefulWidget {
  final PolesApi api;
  final DraftPuzzlet puzzlet;

  const EditPuzzletRoute({super.key, required this.api, required this.puzzlet});

  @override
  State<EditPuzzletRoute> createState() => _EditPuzzletRouteState();
}

class _EditPuzzletRouteState extends State<EditPuzzletRoute> {
  late final TextEditingController _instructionsController;
  late final TextEditingController _answerController;
  late final TextEditingController _accessibilityNotesController;
  late List<String> _accessibilityTags;
  late int _difficulty;
  late AnswerType _answerType;

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
    _instructionsController =
        TextEditingController(text: widget.puzzlet.instructions)
          ..addListener(_markDirty);
    _answerController = TextEditingController(text: widget.puzzlet.answer)
      ..addListener(_markDirty);
    _accessibilityNotesController =
        TextEditingController(text: widget.puzzlet.accessibilityNotes ?? '')
          ..addListener(_markDirty);
    _accessibilityTags = [...widget.puzzlet.accessibilityTags];
    _difficulty = widget.puzzlet.difficulty;
    _answerType = widget.puzzlet.answerType;
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
      _dirty = true;
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await widget.api.updateDraftPuzzlet(
        widget.puzzlet.id,
        instructions: _instructionsController.text.trim(),
        answer: _answerController.text.trim(),
        answerType: _answerType,
        difficulty: _difficulty,
        latitude: _newFix?.latitude,
        longitude: _newFix?.longitude,
        accuracyM: _newFix?.accuracyM,
        accessibilityTags: _accessibilityTags,
        accessibilityNotes: _accessibilityNotesController.text.trim(),
      );
      if (!mounted) return;
      _dirty = false;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Draft updated.')));
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
      await widget.api.deleteDraftPuzzlet(widget.puzzlet.id);
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
    _instructionsController.dispose();
    _answerController.dispose();
    _accessibilityNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final original = widget.puzzlet;
    LocationFix? fixForCard = _newFix;
    if (fixForCard == null && original.latitude != null && original.longitude != null) {
      fixForCard = LocationFix(
        latitude: original.latitude!,
        longitude: original.longitude!,
        accuracyM: original.accuracyM ?? 0,
        timestamp: DateTime.now(),
      );
    }

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
          title: const Text('Edit puzzlet'),
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
            LocationCard(
              fix: fixForCard,
              error: _locationError,
              busy: _gettingFix,
              onRetry: _reacquireLocation,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _instructionsController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Instructions',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            AnswerTypeField(
              value: _answerType,
              onChanged: (t) => setState(() {
                _answerType = t;
                _dirty = true;
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _answerController,
              decoration: InputDecoration(
                labelText: 'Answer',
                border: const OutlineInputBorder(),
                suffixIcon: _answerType == AnswerType.barcode
                    ? IconButton(
                        tooltip: 'Scan barcode as answer',
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: _scanAnswer,
                      )
                    : null,
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
              onChanged: (v) => setState(() {
                _difficulty = v.round();
                _dirty = true;
              }),
            ),
            const SizedBox(height: 16),
            AccessibilityTagsField(
              selected: _accessibilityTags,
              primary: kPuzzletPrimaryTags,
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
            const SizedBox(height: 16),
            AttachmentsSection(
              api: widget.api,
              kind: AttachmentParentKind.puzzlet,
              parentId: widget.puzzlet.id,
              initialIds: widget.puzzlet.attachmentIds,
            ),
            const SizedBox(height: 16),
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
