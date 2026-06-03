import 'package:flutter/material.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/accessibility.dart';
import 'package:poles/models/draft.dart';
import 'package:poles/models/region.dart';
import 'package:poles/widgets/accessibility_tags_field.dart';
import 'package:poles/widgets/region_picker_field.dart';

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

/// Multi-step "create a region and assign these puzzlets to it" flow.
/// Pre-fills the new region's accessibility tags with the intersection of
/// the selected puzzlets' tags, and pre-fills notes if every selected
/// puzzlet has the same non-empty notes. Both are editable.
///
/// Does NOT strip fields from the puzzlets themselves — the author can
/// clean up duplicates later. The exception: tags the author keeps on the
/// new region are removed from each puzzlet, since otherwise authors see
/// the same tag rendered twice (own + inherited) on every puzzlet edit.
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
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _entryController = TextEditingController();
  Region? _parent;
  late List<String> _tags;
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
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final region = await widget.api.createRegion(
        name: name,
        parentRegionId: _parent?.id,
        accessibilityTags: _tags.isEmpty ? null : _tags,
        accessibilityNotes:
            _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        entryInstructions:
            _entryController.text.trim().isEmpty ? null : _entryController.text.trim(),
      );

      final regionTagSet = _tags.toSet();
      final failed = <String>[];
      var assigned = 0;
      for (final p in widget.puzzlets) {
        // Strip any tags now carried by the region; leave puzzlet notes
        // alone so per-puzzlet specifics survive.
        final remainingTags = p.accessibilityTags
            .where((t) => !regionTagSet.contains(t))
            .toList();
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
        _error = 'Could not create region: $e';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.puzzlets.length;
    return AlertDialog(
      title: Text('Promote $n puzzlet${n == 1 ? '' : 's'} to a region'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              : Text('Promote $n'),
        ),
      ],
    );
  }
}
