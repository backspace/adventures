import 'package:flutter/material.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/accessibility.dart';
import 'package:poles/models/draft.dart';
import 'package:poles/models/region.dart';
import 'package:poles/widgets/accessibility_tags_field.dart';
import 'package:poles/widgets/region_picker_field.dart';

enum _Mode { createNew, moveExisting }

/// Returned to the caller after a successful promotion so it can show a
/// snackbar and reload state.
class PromoteResult {
  final Region region;
  final int assignedCount;
  final List<String> failedPuzzletIds;

  PromoteResult({
    required this.region,
    required this.assignedCount,
    required this.failedPuzzletIds,
  });
}

/// "Group these puzzlets into a region" flow with two modes:
///
/// * [_Mode.createNew] — create a new region and assign the puzzlets to it.
///   Pre-fills the new region's tags from the intersection of the selected
///   puzzlets' tags, and notes from a shared non-empty value if every
///   selected puzzlet has the same notes.
/// * [_Mode.moveExisting] — pick an existing region; the selected puzzlets
///   get reassigned to it.
///
/// In both cases, tags carried by the destination region are stripped from
/// each puzzlet so authors don't see them rendered twice (own + inherited).
/// Per-puzzlet notes are left alone.
class PromoteToRegionDialog extends StatefulWidget {
  final PolesApi api;
  final List<DraftPuzzlet> puzzlets;

  const PromoteToRegionDialog({
    super.key,
    required this.api,
    required this.puzzlets,
  });

  @override
  State<PromoteToRegionDialog> createState() => _PromoteToRegionDialogState();
}

class _PromoteToRegionDialogState extends State<PromoteToRegionDialog> {
  _Mode _mode = _Mode.createNew;

  // Create-new state.
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _entryController = TextEditingController();
  Region? _parent;
  late List<String> _tags;

  // Move-existing state.
  Region? _destination;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tags = _intersectionOfTags();
    final shared = _sharedNotes();
    if (shared != null) _notesController.text = shared;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  List<String> _intersectionOfTags() {
    if (widget.puzzlets.isEmpty) return [];
    final sets = widget.puzzlets.map((p) => p.accessibilityTags.toSet()).toList();
    return sets.reduce((a, b) => a.intersection(b)).toList();
  }

  String? _sharedNotes() {
    final values = widget.puzzlets
        .map((p) => p.accessibilityNotes?.trim() ?? '')
        .toSet();
    if (values.length != 1) return null;
    final only = values.single;
    return only.isEmpty ? null : only;
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final Region region;
      final Set<String> regionTags;

      if (_mode == _Mode.createNew) {
        final name = _nameController.text.trim();
        if (name.isEmpty) {
          setState(() {
            _error = 'Name is required';
            _busy = false;
          });
          return;
        }
        region = await widget.api.createRegion(
          name: name,
          parentRegionId: _parent?.id,
          accessibilityTags: _tags.isEmpty ? null : _tags,
          accessibilityNotes:
              _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          entryInstructions:
              _entryController.text.trim().isEmpty ? null : _entryController.text.trim(),
        );
        regionTags = _tags.toSet();
      } else {
        final dest = _destination;
        if (dest == null) {
          setState(() {
            _error = 'Pick a region to move puzzlets into.';
            _busy = false;
          });
          return;
        }
        region = dest;
        regionTags = dest.accessibilityTags.toSet();
      }

      final failed = <String>[];
      var assigned = 0;
      for (final p in widget.puzzlets) {
        final remainingTags =
            p.accessibilityTags.where((t) => !regionTags.contains(t)).toList();
        try {
          await widget.api.updateDraftPuzzlet(
            p.id,
            regionId: region.id,
            accessibilityTags: remainingTags,
          );
          assigned++;
        } catch (_) {
          failed.add(p.id);
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(PromoteResult(
        region: region,
        assignedCount: assigned,
        failedPuzzletIds: failed,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _mode == _Mode.createNew
            ? 'Could not create region: $e'
            : 'Could not move puzzlets: $e';
        _busy = false;
      });
    }
  }

  String _submitLabel(int n) {
    if (_mode == _Mode.createNew) return 'Group $n';
    return 'Move $n';
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.puzzlets.length;
    return AlertDialog(
      title: Text('Group $n puzzlet${n == 1 ? '' : 's'} into a region'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<_Mode>(
                segments: const [
                  ButtonSegment(
                    value: _Mode.createNew,
                    label: Text('New region'),
                    icon: Icon(Icons.add),
                  ),
                  ButtonSegment(
                    value: _Mode.moveExisting,
                    label: Text('Existing region'),
                    icon: Icon(Icons.drive_file_move_outlined),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (set) => setState(() => _mode = set.first),
              ),
              const SizedBox(height: 16),
              if (_mode == _Mode.createNew)
                ..._buildCreateFields(context, n)
              else
                ..._buildMoveFields(context),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_submitLabel(n)),
        ),
      ],
    );
  }

  List<Widget> _buildCreateFields(BuildContext context, int n) {
    return [
      TextField(
        controller: _nameController,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Region name',
          hintText: 'e.g. 4th floor of 777 Main St',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      RegionPickerField(
        api: widget.api,
        selected: _parent,
        onChanged: (r) => setState(() => _parent = r),
      ),
      const SizedBox(height: 12),
      AccessibilityTagsField(
        selected: _tags,
        primary: kRegionPrimaryTags,
        onChanged: (next) => setState(() => _tags = next),
      ),
      if (_intersectionOfTags().isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Pre-selected tags are those all $n puzzlets share. '
            'They\'ll be removed from each puzzlet once the region carries them.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      const SizedBox(height: 12),
      TextField(
        controller: _notesController,
        minLines: 1,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: 'Accessibility notes (optional)',
          helperText: _sharedNotes() != null
              ? 'Pre-filled because all selected puzzlets share these notes.'
              : null,
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _entryController,
        minLines: 1,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Entry instructions (optional)',
          border: OutlineInputBorder(),
        ),
      ),
    ];
  }

  List<Widget> _buildMoveFields(BuildContext context) {
    return [
      RegionPickerField(
        api: widget.api,
        selected: _destination,
        onChanged: (r) => setState(() => _destination = r),
      ),
      const SizedBox(height: 8),
      Text(
        _destination == null
            ? 'Pick the region to move these puzzlets into.'
            : 'Tags already carried by ${_destination!.name} will be removed from each puzzlet.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];
  }
}
