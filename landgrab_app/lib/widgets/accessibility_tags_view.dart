import 'package:flutter/material.dart';
import 'package:landgrab/models/accessibility.dart';

/// Read-only display of a location's accessibility tags (as chips) plus
/// optional free-text notes, for role-holder screens like the validation
/// interstitials. Renders nothing when there are neither tags nor notes,
/// so callers can drop it in unconditionally.
class AccessibilityTagsView extends StatelessWidget {
  final List<String> tags;
  final String? notes;

  /// Optional heading shown above the chips (e.g. 'Accessibility').
  final String? title;

  /// Whether each chip carries the tap-for-an-explanation (i) affordance. Its
  /// text is author-facing, so player surfaces (the gameplay pole popover)
  /// pass false — the labels alone are already plain enough. Role-holder
  /// screens (validation interstitials) leave it on.
  final bool explainable;

  const AccessibilityTagsView({
    super.key,
    required this.tags,
    this.notes,
    this.title,
    this.explainable = true,
  });

  bool get _hasNotes => notes != null && notes!.trim().isNotEmpty;

  // Mirrors the author form's info affordance: tap the (i) on a chip to
  // read what the tag means (accessibility_tags_field.dart).
  void _showExplanation(BuildContext context, String tag) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(accessibilityTagLabel(tag)),
        content: Text(accessibilityTagExplanation(tag)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedTags = [...tags]..sort();
    if (sortedTags.isEmpty && !_hasNotes) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(title!, style: theme.textTheme.labelLarge),
          ),
        if (sortedTags.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: sortedTags
                .map((t) => Chip(
                      label: Text(accessibilityTagLabel(t)),
                      visualDensity: VisualDensity.compact,
                      deleteIcon: explainable
                          ? const Icon(Icons.info_outline, size: 18)
                          : null,
                      onDeleted:
                          explainable ? () => _showExplanation(context, t) : null,
                      deleteButtonTooltipMessage:
                          explainable ? 'What does this mean?' : null,
                    ))
                .toList(growable: false),
          ),
        if (_hasNotes) ...[
          if (sortedTags.isNotEmpty) const SizedBox(height: 8),
          Text(notes!.trim(), style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}
