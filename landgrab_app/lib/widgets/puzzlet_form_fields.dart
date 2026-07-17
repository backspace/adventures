import 'package:flutter/material.dart';
import 'package:landgrab/models/accessibility.dart';
import 'package:landgrab/models/draft.dart';
import 'package:landgrab/routes/barcode_scanner_route.dart';
import 'package:landgrab/routes/nfc_scanner_route.dart';
import 'package:landgrab/widgets/accessibility_tags_field.dart';
import 'package:landgrab/widgets/answer_type_field.dart';

/// Snapshot of the editable puzzlet content fields, read from
/// [PuzzletFormFieldsState.data] at submit time.
class PuzzletFormData {
  final String instructions;
  final String answer;
  final AnswerType answerType;
  final int difficulty;
  final String warning;
  final List<String> accessibilityTags;
  final String accessibilityNotes;

  PuzzletFormData({
    required this.instructions,
    required this.answer,
    required this.answerType,
    required this.difficulty,
    required this.warning,
    required this.accessibilityTags,
    required this.accessibilityNotes,
  });
}

/// The puzzlet content fields shared by the author edit form and the
/// validator suggest form: instructions, answer (with an optional
/// editable answer-type + scan), difficulty, warning, accessibility tags
/// and notes.
///
/// Author-only surroundings (location, region picker, validator-only
/// toggle, attachments, timestamps) and validator-only chrome (notice
/// banners, supervisor note) live in the respective wrappers. When
/// [answerTypeEditable] is false the answer is a plain field (the
/// validator suggests a corrected string; they don't restructure the
/// puzzle). [accessibilityInheritedSection] is an optional read-only
/// block shown just above the tags (the author's "inherited from
/// region" panel).
class PuzzletFormFields extends StatefulWidget {
  final String initialInstructions;
  final String initialAnswer;
  final AnswerType initialAnswerType;
  final int initialDifficulty;
  final String? initialWarning;
  final List<String> initialAccessibilityTags;
  final String? initialAccessibilityNotes;
  final bool answerTypeEditable;
  final Widget? accessibilityInheritedSection;
  final VoidCallback? onChanged;

  const PuzzletFormFields({
    super.key,
    required this.initialInstructions,
    required this.initialAnswer,
    required this.initialAnswerType,
    required this.initialDifficulty,
    this.initialWarning,
    this.initialAccessibilityTags = const [],
    this.initialAccessibilityNotes,
    this.answerTypeEditable = true,
    this.accessibilityInheritedSection,
    this.onChanged,
  });

  @override
  PuzzletFormFieldsState createState() => PuzzletFormFieldsState();
}

class PuzzletFormFieldsState extends State<PuzzletFormFields> {
  late final TextEditingController _instructions;
  late final TextEditingController _answer;
  late final TextEditingController _warning;
  late final TextEditingController _accessNotes;
  late List<String> _tags;
  late int _difficulty;
  late AnswerType _answerType;

  @override
  void initState() {
    super.initState();
    _instructions = TextEditingController(text: widget.initialInstructions)
      ..addListener(_notify);
    _answer = TextEditingController(text: widget.initialAnswer)
      ..addListener(_notify);
    _warning = TextEditingController(text: widget.initialWarning ?? '')
      ..addListener(_notify);
    _accessNotes =
        TextEditingController(text: widget.initialAccessibilityNotes ?? '')
          ..addListener(_notify);
    _tags = [...widget.initialAccessibilityTags];
    _difficulty = widget.initialDifficulty;
    _answerType = widget.initialAnswerType;
  }

  @override
  void dispose() {
    _instructions.dispose();
    _answer.dispose();
    _warning.dispose();
    _accessNotes.dispose();
    super.dispose();
  }

  void _notify() => widget.onChanged?.call();

  PuzzletFormData get data => PuzzletFormData(
        instructions: _instructions.text.trim(),
        answer: _answer.text.trim(),
        answerType: _answerType,
        difficulty: _difficulty,
        warning: _warning.text.trim(),
        accessibilityTags: List.of(_tags),
        accessibilityNotes: _accessNotes.text.trim(),
      );

  Future<void> _scanAnswer(Widget scanner, AnswerType type) async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => scanner),
    );
    if (scanned == null || scanned.isEmpty || !mounted) return;
    setState(() {
      _answer.text = scanned;
      _answerType = type;
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
        if (widget.answerTypeEditable) ...[
          const SizedBox(height: 12),
          AnswerTypeField(
            value: _answerType,
            onChanged: (t) {
              setState(() => _answerType = t);
              _notify();
            },
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _answer,
          decoration: InputDecoration(
            labelText: 'Answer',
            border: const OutlineInputBorder(),
            suffixIcon: !widget.answerTypeEditable
                ? null
                : switch (_answerType) {
                    AnswerType.barcode => IconButton(
                        tooltip: 'Scan barcode as answer',
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: () => _scanAnswer(
                          const BarcodeScannerRoute(title: 'Scan answer barcode'),
                          AnswerType.barcode,
                        ),
                      ),
                    AnswerType.nfc => IconButton(
                        tooltip: 'Scan NFC tag as answer',
                        icon: const Icon(Icons.contactless),
                        onPressed: () => _scanAnswer(
                          const NfcScannerRoute(title: 'Scan answer NFC tag'),
                          AnswerType.nfc,
                        ),
                      ),
                    _ => null,
                  },
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _warning,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Warning (optional)',
            hintText: 'Shown prominently to players. Use for safety / practical alerts.',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.warning_amber_outlined),
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
          onChanged: (v) {
            setState(() => _difficulty = v.round());
            _notify();
          },
        ),
        if (widget.accessibilityInheritedSection != null) ...[
          const SizedBox(height: 16),
          widget.accessibilityInheritedSection!,
        ],
        const SizedBox(height: 16),
        AccessibilityTagsField(
          selected: _tags,
          primary: kPuzzletPrimaryTags,
          onChanged: (next) {
            setState(() => _tags = next);
            _notify();
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _accessNotes,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Accessibility notes (optional)',
            hintText: 'Anything tags don\'t cover',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
