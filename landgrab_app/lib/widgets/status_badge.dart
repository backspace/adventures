import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  /// Tighter padding + smaller text — for list rows that sit the badge on
  /// the second line to save horizontal room on small screens.
  final bool dense;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 8,
        vertical: dense ? 1 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: dense ? 11 : 12)),
    );
  }
}

Color statusColorFor(String status) => switch (status) {
      'draft' => Colors.orange.shade700,
      'in review' || 'in_review' => Colors.blue.shade700,
      'validated' => Colors.green.shade700,
      'retired' => Colors.grey.shade700,
      // Not-yet-reviewed: a distinct teal so it doesn't read as grey and
      // get confused with the grey "unfindable".
      'assigned' => Colors.teal.shade600,
      'in progress' || 'in_progress' => Colors.amber.shade800,
      'submitted' => Colors.purple.shade700,
      'accepted' => Colors.green.shade700,
      'rejected' => Colors.red.shade700,
      // A validator couldn't locate the pole — its own grey.
      'unfindable' => Colors.grey.shade500,
      'pending' => Colors.orange.shade700,
      _ => Colors.grey.shade700,
    };
