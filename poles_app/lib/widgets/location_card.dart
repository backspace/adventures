import 'package:flutter/material.dart';
import 'package:poles/services/location_service.dart';

class LocationCard extends StatelessWidget {
  final LocationFix? fix;
  final String? error;
  final bool busy;
  final VoidCallback onRetry;

  const LocationCard({
    super.key,
    required this.fix,
    required this.error,
    required this.busy,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (busy) {
      return _frame(theme,
          child: const Row(children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Getting GPS fix…'),
          ]));
    }

    if (error != null) {
      return _frame(theme,
          color: theme.colorScheme.errorContainer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(error!, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
              const SizedBox(height: 8),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ));
    }

    final f = fix;
    if (f == null) {
      return _frame(theme,
          child: Row(children: [
            const Expanded(child: Text('No location fix yet.')),
            FilledButton(onPressed: onRetry, child: const Text('Get GPS')),
          ]));
    }

    final usable = f.isUsable;
    final accuracy = f.accuracyM.toStringAsFixed(1);
    return _frame(theme,
        color: usable ? null : theme.colorScheme.errorContainer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${f.latitude.toStringAsFixed(5)}, ${f.longitude.toStringAsFixed(5)}'),
            const SizedBox(height: 4),
            Text(
              usable
                  ? 'Accuracy: $accuracy m  ✓'
                  : 'Accuracy: $accuracy m — too imprecise. Move to a clearer spot.',
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Re-acquire')),
          ],
        ));
  }

  Widget _frame(ThemeData theme, {Color? color, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}
