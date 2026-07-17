import 'package:flutter/material.dart';
import 'package:landgrab/models/region.dart';

/// The canonical display of a puzzlet's region context: the breadcrumb
/// path plus each level's "getting in" (entry instructions) and
/// accessibility notes, gathered up the hierarchy (root → self).
///
/// Shared by every surface that shows a puzzlet's region — the player's
/// puzzlet screen, the validator preview, the validator interstitial —
/// so the entry instructions (which are critical) always appear, and
/// the views can't drift apart.
class RegionContextCard extends StatelessWidget {
  final String breadcrumb;
  final List<InheritedStanza> stanzas;

  static const _entryLabel = 'Getting there';
  static const _accessibilityLabel = 'Accessibility';

  const RegionContextCard({
    super.key,
    required this.breadcrumb,
    required this.stanzas,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place_outlined, size: 18, color: theme.hintColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(breadcrumb, style: theme.textTheme.titleSmall),
              ),
            ],
          ),
          for (final s in stanzas) ...[
            const SizedBox(height: 10),
            // Only worth naming the level when the path has more than
            // one; otherwise the breadcrumb above already says it.
            if (stanzas.length > 1)
              Text(s.source, style: theme.textTheme.labelMedium),
            if (s.entryInstructions != null &&
                s.entryInstructions!.trim().isNotEmpty)
              _detail(theme, _entryLabel, s.entryInstructions!),
            if (s.notes != null && s.notes!.trim().isNotEmpty)
              _detail(theme, _accessibilityLabel, s.notes!),
          ],
        ],
      ),
    );
  }

  Widget _detail(ThemeData theme, String label, String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.hintColor)),
            Text(text, style: theme.textTheme.bodyMedium),
          ],
        ),
      );
}
