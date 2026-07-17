import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/accessibility.dart';
import 'package:landgrab/models/validation.dart';
import 'package:landgrab/widgets/accessibility_tags_field.dart';

/// The validator's puzzlet review form, in "suggest" mode — the puzzlet
/// analogue of [PoleValidationFormRoute]. Editing a field and submitting
/// sends it to the supervisor as a suggestion; submitting unchanged
/// endorses the puzzlet. Never mutates the puzzlet directly.
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
  late final TextEditingController _instructions;
  late final TextEditingController _answer;
  late final TextEditingController _warning;
  late final TextEditingController _accessNotes;
  late final TextEditingController _supervisorNote;
  late int _difficulty;
  late List<String> _tags;
  bool _busy = false;

  ValidationPuzzletSummary get _p => widget.validation.puzzlet!;

  bool get _editable =>
      widget.validation.status == ValidationStatus.assigned ||
      widget.validation.status == ValidationStatus.inProgress;

  @override
  void initState() {
    super.initState();
    _instructions = TextEditingController(text: _p.instructions);
    _answer = TextEditingController(text: _p.answer);
    _warning = TextEditingController(text: _p.warning ?? '');
    _accessNotes = TextEditingController(text: _p.accessibilityNotes ?? '');
    _supervisorNote =
        TextEditingController(text: widget.validation.overallNotes ?? '');
    _difficulty = _p.difficulty;
    _tags = [..._p.accessibilityTags];
  }

  @override
  void dispose() {
    _instructions.dispose();
    _answer.dispose();
    _warning.dispose();
    _accessNotes.dispose();
    _supervisorNote.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _buildSuggestions() {
    final out = <Map<String, dynamic>>[];

    void text(String field, String current, String? original) {
      final c = current.trim();
      if (c != (original ?? '').trim()) {
        out.add({'field': field, 'suggested_value': c});
      }
    }

    // Instructions and answer shouldn't be blanked to empty via a suggestion.
    final instructions = _instructions.text.trim();
    if (instructions.isNotEmpty && instructions != _p.instructions.trim()) {
      out.add({'field': 'instructions', 'suggested_value': instructions});
    }
    final answer = _answer.text.trim();
    if (answer.isNotEmpty && answer != _p.answer.trim()) {
      out.add({'field': 'answer', 'suggested_value': answer});
    }
    if (_difficulty != _p.difficulty) {
      out.add({'field': 'difficulty', 'suggested_value': '$_difficulty'});
    }
    text('warning', _warning.text, _p.warning);
    text('accessibility_notes', _accessNotes.text, _p.accessibilityNotes);

    final tagsChanged =
        _tags.toSet().difference(_p.accessibilityTags.toSet()).isNotEmpty ||
            _p.accessibilityTags.toSet().difference(_tags.toSet()).isNotEmpty;
    if (tagsChanged) {
      out.add({'field': 'accessibility_tags', 'suggested_value': jsonEncode(_tags)});
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Suggest edits')),
      body: ListView(
        padding: const EdgeInsets.all(20),
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
                    size: 20,
                    color: _editable ? Colors.blue : Colors.blueGrey),
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
          TextField(
            controller: _instructions,
            enabled: _editable,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Instructions',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _answer,
            enabled: _editable,
            decoration: const InputDecoration(
              labelText: 'Answer',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text('Difficulty: $_difficulty / 10', style: theme.textTheme.bodyMedium),
          Slider(
            value: _difficulty.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: '$_difficulty',
            onChanged:
                _editable ? (v) => setState(() => _difficulty = v.round()) : null,
          ),
          const SizedBox(height: 8),
          AccessibilityTagsField(
            selected: _tags,
            primary: kPuzzletPrimaryTags,
            onChanged:
                _editable ? (next) => setState(() => _tags = next) : (_) {},
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accessNotes,
            enabled: _editable,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Accessibility notes (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _warning,
            enabled: _editable,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Warning (optional)',
              hintText: 'Safety or content heads-up shown before the puzzle',
              border: OutlineInputBorder(),
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
