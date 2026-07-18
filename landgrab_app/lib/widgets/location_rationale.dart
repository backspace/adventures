import 'package:flutter/material.dart';
import 'package:landgrab/l10n/player_strings.dart';

/// The in-app "pre-prompt" shown just before the OS location-permission
/// dialog, explaining why Landgrab wants location so the system ask isn't a
/// cold prompt. Returns true if the user chose to continue (proceed to the
/// OS dialog), false if they declined.
class LocationRationale {
  LocationRationale._();

  static Future<bool> show(BuildContext context) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(LocationStrings.rationaleTitle),
        content: const Text(LocationStrings.rationaleBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(LocationStrings.rationaleNotNow),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(LocationStrings.rationaleContinue),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }
}
