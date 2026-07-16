import 'package:flutter/material.dart';

/// Always-visible created / last-edited timestamps for a record.
/// Role-holder UI (author/validator/supervisor editors), so plain
/// English. Renders nothing when there's no created time.
///
/// "Last edited" is shown only when it meaningfully differs from
/// "Created" — a record that hasn't been touched since creation has
/// `updated_at == inserted_at`, and repeating the same time reads as
/// noise.
///
/// Times arrive as UTC (see draft.dart's `_parseServerTime`); shown in
/// the device's local zone.
class RecordTimestamps extends StatelessWidget {
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const RecordTimestamps({super.key, this.createdAt, this.updatedAt});

  @override
  Widget build(BuildContext context) {
    if (createdAt == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final edited = updatedAt;
    // Treat sub-second gaps as "not edited" — Ecto stamps inserted_at
    // and updated_at in the same transaction and they can differ by a
    // few microseconds on creation.
    final showEdited = edited != null &&
        edited.difference(createdAt!).abs() > const Duration(seconds: 1);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule, size: 15, color: style?.color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Created ${_format(createdAt!.toLocal())}', style: style),
                if (showEdited)
                  Text('Last edited ${_format(edited.toLocal())}',
                      style: style),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _format(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}
