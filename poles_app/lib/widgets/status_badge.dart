import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

Color statusColorFor(String status) => switch (status) {
      'draft' => Colors.orange.shade700,
      'in_review' => Colors.blue.shade700,
      'validated' => Colors.green.shade700,
      'retired' => Colors.grey.shade700,
      'assigned' => Colors.blueGrey.shade700,
      'in progress' || 'in_progress' => Colors.amber.shade800,
      'submitted' => Colors.purple.shade700,
      'accepted' => Colors.green.shade700,
      'rejected' => Colors.red.shade700,
      'pending' => Colors.orange.shade700,
      _ => Colors.grey.shade700,
    };
