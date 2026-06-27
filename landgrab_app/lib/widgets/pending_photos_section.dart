import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:landgrab/services/photo_picker.dart';

/// Photo picker that holds resized bytes locally. Used during record
/// creation, before a parent ID exists. The parent reads `bytes` after save
/// and uploads them once it has the new pole/puzzlet ID.
class PendingPhotosSection extends StatefulWidget {
  final List<Uint8List> bytes;
  final ValueChanged<List<Uint8List>> onChanged;

  const PendingPhotosSection({
    super.key,
    required this.bytes,
    required this.onChanged,
  });

  @override
  State<PendingPhotosSection> createState() => _PendingPhotosSectionState();
}

class _PendingPhotosSectionState extends State<PendingPhotosSection> {
  Future<void> _add() async {
    final picked = await PhotoPicker.pickAndResize(context);
    if (picked == null) return;
    widget.onChanged([...widget.bytes, picked]);
  }

  void _removeAt(int index) {
    final next = [...widget.bytes];
    next.removeAt(index);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.bytes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Photos (${list.length})',
                style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: _add,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (list.isEmpty)
          Text('No photos yet.',
              style: Theme.of(context).textTheme.bodySmall)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < list.length; i++)
                GestureDetector(
                  onLongPress: () => _confirmRemove(i),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      list[i],
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _confirmRemove(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) _removeAt(index);
  }
}
