import 'package:flutter/material.dart';
import 'package:landgrab/widgets/accent_colors.dart';

/// The prominent amber warning shown before a puzzlet — a safety /
/// practical alert the author set. Shared by the player's puzzlet screen
/// and the validator preview so it reads identically in both.
class WarningBanner extends StatelessWidget {
  final String text;
  const WarningBanner({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    // Brightness-aware amber, so it reads on both light and dark chrome.
    final c = AccentColors.of(context, Colors.amber);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.fill,
        border: Border.all(color: c.border, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: c.ink, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: c.ink,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
