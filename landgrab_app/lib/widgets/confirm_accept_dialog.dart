import 'package:flutter/material.dart';

/// Warns before accepting a submitted validation while some of its comments /
/// suggestions are still undecided (pending). Accepting leaves those
/// suggestions unapplied, so it's easy to wave a validation through and
/// silently drop the corrections the validator asked for. Returns true only if
/// the supervisor chooses to proceed anyway.
Future<bool> confirmAcceptWithPendingComments(
  BuildContext context,
  int pending,
) async {
  final one = pending == 1;
  final proceed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Accept without deciding comments?'),
      content: Text(
        'This validation still has $pending undecided '
        '${one ? 'comment' : 'comments'}. Accepting now leaves '
        '${one ? 'it' : 'them'} unapplied — the suggested changes won’t be '
        'made. Accept anyway?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Go back'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Accept anyway'),
        ),
      ],
    ),
  );
  return proceed ?? false;
}
