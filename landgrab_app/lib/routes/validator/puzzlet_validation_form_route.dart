import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:landgrab/widgets/scroll_insets.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/draft.dart' show answerTypeFromString;
import 'package:landgrab/models/validation.dart';
import 'package:landgrab/widgets/landgrab_app_bar.dart';
import 'package:landgrab/widgets/puzzlet_form_fields.dart';

/// The validator's puzzlet review form, in "suggest" mode — the same
/// content fields the author edits (via the shared [PuzzletFormFields]),
/// pre-filled. Editing a field and submitting sends it to the supervisor
/// as a suggestion; submitting unchanged endorses the puzzlet. Never
/// mutates the puzzlet directly.
class PuzzletValidationFormRoute extends StatefulWidget {
  final LandgrabApi api;
  final PuzzletValidationModel validation;

  const PuzzletValidationFormRoute({
    super.key,
    required this.api,
    required this.validation,
  });

  @override
  State<PuzzletValidationFormRoute> createState() =>
      _PuzzletValidationFormRouteState();
}

class _PuzzletValidationFormRouteState
    extends State<PuzzletValidationFormRoute> {
  final _fields = GlobalKey<PuzzletFormFieldsState>();
  late final TextEditingController _supervisorNote;
  bool _busy = false;

  ValidationPuzzletSummary get _p => widget.validation.puzzlet!;

  // Editable until the supervisor decides — a validator can revise or
  // withdraw a submission right up to accept/reject.
  bool get _editable =>
      widget.validation.status != ValidationStatus.accepted &&
      widget.validation.status != ValidationStatus.rejected;

  /// Field → suggested value from any already-submitted suggestions, so
  /// re-opening shows the pending edits rather than a blank slate.
  late final Map<String, String> _pending = {
    for (final c in widget.validation.comments)
      if (c.suggestedValue != null) c.field: c.suggestedValue!,
  };

  int get _initialDifficulty =>
      int.tryParse(_pending['difficulty'] ?? '') ?? _p.difficulty;

  List<String> get _initialTags {
    final raw = _pending['accessibility_tags'];
    if (raw == null) return _p.accessibilityTags;
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return _p.accessibilityTags;
    }
  }

  @override
  void initState() {
    super.initState();
    _supervisorNote =
        TextEditingController(text: widget.validation.overallNotes ?? '');
  }

  @override
  void dispose() {
    _supervisorNote.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _buildSuggestions() {
    final out = <Map<String, dynamic>>[];
    final data = _fields.currentState!.data;

    void text(String field, String current, String? original) {
      final c = current.trim();
      if (c != (original ?? '').trim()) {
        out.add({'field': field, 'suggested_value': c});
      }
    }

    // Instructions and answer shouldn't be blanked via a suggestion.
    if (data.instructions.isNotEmpty && data.instructions != _p.instructions.trim()) {
      out.add({'field': 'instructions', 'suggested_value': data.instructions});
    }
    if (data.answer.isNotEmpty && data.answer != _p.answer.trim()) {
      out.add({'field': 'answer', 'suggested_value': data.answer});
    }
    if (data.difficulty != _p.difficulty) {
      out.add({'field': 'difficulty', 'suggested_value': '${data.difficulty}'});
    }
    text('warning', data.warning, _p.warning);
    text('accessibility_notes', data.accessibilityNotes, _p.accessibilityNotes);

    final tagsChanged = data.accessibilityTags.toSet().difference(
                _p.accessibilityTags.toSet()).isNotEmpty ||
        _p.accessibilityTags.toSet().difference(
                data.accessibilityTags.toSet()).isNotEmpty;
    if (tagsChanged) {
      out.add({
        'field': 'accessibility_tags',
        'suggested_value': jsonEncode(data.accessibilityTags),
      });
    }
    return out;
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final suggestions = _buildSuggestions();
    try {
      await widget.api.submitPuzzletValidation(
        widget.validation.id,
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
      appBar: LandgrabAppBar(title: 'Suggest edits'),
      body: ListView(
        padding: scrollInsets(context),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (_editable ? Colors.blue : Colors.blueGrey)
                  .withValues(alpha: 0.10),
              border: Border.all(
                  color: (_editable ? Colors.blue : Colors.blueGrey)
                      .withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_editable ? Icons.rate_review : Icons.lock_outline,
                    size: 20, color: _editable ? Colors.blue : Colors.blueGrey),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_editable
                      ? 'Change anything that’s wrong. Submitting sends your changes to the supervisor as suggestions; submit unchanged to endorse it.'
                      : 'This validation is ${validationStatusLabel(widget.validation.status)} and can no longer be edited.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          IgnorePointer(
            ignoring: !_editable,
            child: Opacity(
              opacity: _editable ? 1 : 0.6,
              child: PuzzletFormFields(
                key: _fields,
                initialInstructions: _pending['instructions'] ?? _p.instructions,
                initialAnswer: _pending['answer'] ?? _p.answer,
                initialAnswerType: answerTypeFromString(_p.answerType),
                initialDifficulty: _initialDifficulty,
                initialWarning: _pending['warning'] ?? _p.warning,
                initialAccessibilityTags: _initialTags,
                initialAccessibilityNotes:
                    _pending['accessibility_notes'] ?? _p.accessibilityNotes,
                answerTypeEditable: false,
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
