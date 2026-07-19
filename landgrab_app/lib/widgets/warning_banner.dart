import 'package:flutter/material.dart';

/// The prominent amber warning shown before a puzzlet — a safety /
/// practical alert the author set. Shared by the player's puzzlet screen
/// and the validator preview so it reads identically in both.
class WarningBanner extends StatelessWidget {
  final String text;
  const WarningBanner({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        border: Border.all(color: Colors.amber.shade700, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.amber.shade900, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                // Fixed dark text: the amber background is fixed, so this
                // can't derive from the (dark) theme or it renders
                // light-on-light. onSurface was written for a light theme.
                color: Colors.black87,
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
