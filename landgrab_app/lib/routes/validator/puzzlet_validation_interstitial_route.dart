import 'package:flutter/material.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/validation.dart';
import 'package:landgrab/routes/validator/puzzlet_validation_form_route.dart';
import 'package:landgrab/routes/validator/puzzlet_validation_preview_route.dart';
import 'package:landgrab/widgets/status_badge.dart';

/// First stop after tapping a puzzlet. Unlike poles there's nothing to
/// scan — the main check is experiencing the puzzlet as a player would,
/// so **Preview** leads; the suggest-edits **form** is the rarer path
/// for when something's actually wrong.
class PuzzletValidationInterstitialRoute extends StatelessWidget {
  final LandgrabApi api;
  final PuzzletValidationModel validation;

  const PuzzletValidationInterstitialRoute({
    super.key,
    required this.api,
    required this.validation,
  });

  Future<void> _open(BuildContext context, Widget route) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => route),
    );
    if (changed == true && context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = validation.puzzlet;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Puzzlet'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: StatusBadge(
                label: validationStatusLabel(validation.status),
                color: statusColorFor(validation.status.name),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (p != null) ...[
            if (p.region != null) ...[
              Text(p.region!.breadcrumb, style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
            ],
            Text(p.instructions,
                style: theme.textTheme.titleMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('Difficulty ${p.difficulty} / 10',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 24),
          ],
          FilledButton.icon(
            onPressed: () => _open(
              context,
              PuzzletValidationPreviewRoute(api: api, validation: validation),
            ),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Preview as a player'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _open(
              context,
              PuzzletValidationFormRoute(api: api, validation: validation),
            ),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Suggest edits'),
          ),
        ],
      ),
    );
  }
}
