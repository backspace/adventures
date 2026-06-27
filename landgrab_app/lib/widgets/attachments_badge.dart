import 'package:flutter/material.dart';

/// Camera icon + photo count, only renders when `count > 0`.
class AttachmentsBadge extends StatelessWidget {
  final int count;
  const AttachmentsBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final color = Theme.of(context).colorScheme.outline;
    return Tooltip(
      message: count == 1 ? '1 photo attached' : '$count photos attached',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_camera_outlined, size: 16, color: color),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }
}
