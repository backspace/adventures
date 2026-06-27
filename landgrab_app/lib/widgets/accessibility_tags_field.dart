import 'package:flutter/material.dart';
import 'package:landgrab/models/accessibility.dart';

/// Chip-based picker for accessibility tags. Shows the "primary" tags for
/// the parent kind by default; tap "Show all" to reveal the rest.
class AccessibilityTagsField extends StatefulWidget {
  final List<String> selected;
  final Set<String> primary;
  final ValueChanged<List<String>> onChanged;

  const AccessibilityTagsField({
    super.key,
    required this.selected,
    required this.primary,
    required this.onChanged,
  });

  @override
  State<AccessibilityTagsField> createState() => _AccessibilityTagsFieldState();
}

class _AccessibilityTagsFieldState extends State<AccessibilityTagsField> {
  bool _showAll = false;

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
    final selectedSet = widget.selected.toSet();
    // Any selected tag that's *not* in primary forces the full list to show,
    // so users can see and toggle off tags they previously picked.
    final hasNonPrimarySelection =
        selectedSet.any((t) => !widget.primary.contains(t));
    final showAll = _showAll || hasNonPrimarySelection;

    final visibleTags = showAll
        ? kAccessibilityTags
        : kAccessibilityTags.where(widget.primary.contains).toList();

    final hiddenCount = kAccessibilityTags.length - visibleTags.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Accessibility tags',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final tag in visibleTags)
              FilterChip(
                label: Text(accessibilityTagLabel(tag)),
                selected: selectedSet.contains(tag),
                onSelected: (on) {
                  final next = {...selectedSet};
                  if (on) {
                    next.add(tag);
                  } else {
                    next.remove(tag);
                  }
                  widget.onChanged(next.toList());
                },
                deleteIcon: const Icon(Icons.info_outline, size: 18),
                onDeleted: () => _showExplanation(context, tag),
                deleteButtonTooltipMessage: 'What does this mean?',
              ),
            if (!showAll && hiddenCount > 0)
              ActionChip(
                avatar: const Icon(Icons.more_horiz, size: 18),
                label: Text('$hiddenCount more'),
                onPressed: () => setState(() => _showAll = true),
              ),
          ],
        ),
      ],
    );
  }
}
