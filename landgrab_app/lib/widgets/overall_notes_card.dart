import 'package:flutter/material.dart';

/// The validator's free-text *overall* note on a validation — the summary they
/// leave alongside (or instead of) the per-field comments. It rides through the
/// API as `overall_notes`/`overallNotes` but had no home in the supervisor UI,
/// so a note left here never surfaced. Renders nothing when the note is empty,
/// so callers can drop it in unconditionally.
class OverallNotesCard extends StatelessWidget {
  const OverallNotesCard(this.notes, {super.key});

  final String? notes;

  @override
  Widget build(BuildContext context) {
    final text = notes?.trim();
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.sticky_note_2_outlined,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text('Overall notes',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
            ]),
            const SizedBox(height: 8),
            Text(text),
          ],
        ),
      ),
    );
  }
}
