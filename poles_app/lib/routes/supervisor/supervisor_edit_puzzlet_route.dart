import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/accessibility.dart';
import 'package:poles/models/draft.dart';
import 'package:poles/routes/barcode_scanner_route.dart';
import 'package:poles/services/discard_changes.dart';
import 'package:poles/widgets/accessibility_tags_field.dart';
import 'package:poles/widgets/answer_type_field.dart';

class SupervisorEditPuzzletRoute extends StatefulWidget {
  final PolesApi api;
  final DraftPuzzlet puzzlet;

  const SupervisorEditPuzzletRoute({
    super.key,
    required this.api,
    required this.puzzlet,
  });

  @override
  State<SupervisorEditPuzzletRoute> createState() =>
      _SupervisorEditPuzzletRouteState();
}

class _SupervisorEditPuzzletRouteState
    extends State<SupervisorEditPuzzletRoute> {
  late final TextEditingController _instructions;
  late final TextEditingController _answer;
  late int _difficulty;
  late AnswerType _answerType;
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
    _instructions = TextEditingController(text: widget.puzzlet.instructions)
      ..addListener(_markDirty);
    _answer = TextEditingController(text: widget.puzzlet.answer)
      ..addListener(_markDirty);
    _accessibilityNotes =
        TextEditingController(text: widget.puzzlet.accessibilityNotes ?? '')
          ..addListener(_markDirty);
    _accessibilityTags = [...widget.puzzlet.accessibilityTags];
    _difficulty = widget.puzzlet.difficulty;
    _answerType = widget.puzzlet.answerType;
  }

  @override
  void dispose() {
    _instructions.dispose();
    _answer.dispose();
    _accessibilityNotes.dispose();
    super.dispose();
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
      _answer.text = scanned;
      _answerType = AnswerType.barcode;
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (_instructions.text.trim().isEmpty || _answer.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Instructions and answer are required.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final updated = await widget.api.supervisorEditPuzzlet(
        widget.puzzlet.id,
        instructions: _instructions.text.trim(),
        answer: _answer.text.trim(),
        answerType: _answerType,
        difficulty: _difficulty,
        accessibilityTags: _accessibilityTags,
        accessibilityNotes: _accessibilityNotes.text.trim(),
      );
      if (!mounted) return;
      _dirty = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Puzzlet updated.')),
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
        appBar: AppBar(title: const Text('Edit puzzlet')),
        body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _instructions,
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
              controller: _answer,
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
              controller: _accessibilityNotes,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Accessibility notes (optional)',
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
