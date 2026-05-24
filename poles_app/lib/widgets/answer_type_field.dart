import 'package:flutter/material.dart';
import 'package:poles/models/draft.dart';

/// Segmented picker for the puzzlet's `answerType`. Compact enough to fit
/// above the Answer text field on every form.
class AnswerTypeField extends StatelessWidget {
  final AnswerType value;
  final ValueChanged<AnswerType> onChanged;

  const AnswerTypeField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Answer type', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<AnswerType>(
          segments: const [
            ButtonSegment(
              value: AnswerType.looseText,
              label: Text('Loose'),
              icon: Icon(Icons.text_fields),
            ),
            ButtonSegment(
              value: AnswerType.strictText,
              label: Text('Strict'),
              icon: Icon(Icons.text_format),
            ),
            ButtonSegment(
              value: AnswerType.barcode,
              label: Text('Barcode'),
              icon: Icon(Icons.qr_code_scanner),
            ),
            ButtonSegment(
              value: AnswerType.nfc,
              label: Text('NFC'),
              icon: Icon(Icons.contactless),
            ),
          ],
          selected: {value},
          onSelectionChanged: (set) => onChanged(set.first),
          showSelectedIcon: false,
        ),
        const SizedBox(height: 4),
        Text(
          _hintFor(value),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String _hintFor(AnswerType t) => switch (t) {
        AnswerType.looseText =>
          'Case-insensitive and whitespace-trimmed.',
        AnswerType.strictText =>
          'Must match exactly, character for character.',
        AnswerType.barcode =>
          'Player will scan a barcode. Type the expected scan value, or use the Scan button on the answer field.',
        AnswerType.nfc =>
          'Player will tap an NFC tag. Use the NFC button on the answer field to capture the tag\'s ID now.',
      };
}
