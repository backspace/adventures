import 'dart:async';

import 'package:flutter/material.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/accessibility.dart';
import 'package:landgrab/models/region.dart';
import 'package:landgrab/widgets/accessibility_tags_field.dart';

/// Form-field-style picker for a puzzlet's region. Shows the currently
/// selected region's breadcrumb (or "No region") and opens a search sheet
/// on tap. The sheet supports search-as-you-type, picking an existing
/// region, creating a new sub-region of any visible region, and clearing
/// the current selection.
class RegionPickerField extends StatelessWidget {
  final LandgrabApi api;
  final Region? selected;
  final ValueChanged<Region?> onChanged;
  final String label;

  const RegionPickerField({
    super.key,
    required this.api,
    required this.selected,
    required this.onChanged,
    this.label = 'Region (optional)',
  });

  Future<void> _open(BuildContext context) async {
    final result = await showModalBottomSheet<_PickerResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RegionPickerSheet(
        api: api,
        current: selected,
        // Editing the currently-selected region in place refreshes the
        // breadcrumb shown on the parent form without changing assignment.
        onCurrentEdited: (refreshed) => onChanged(refreshed),
      ),
    );
    if (result == null) return;
    onChanged(result.cleared ? null : result.region);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          selected?.breadcrumb ?? 'No region',
          style: selected == null
              ? theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)
              : theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _PickerResult {
  final Region? region;
  final bool cleared;

  _PickerResult.pick(this.region) : cleared = false;
  _PickerResult.clear()
      : region = null,
        cleared = true;
}

class _RegionPickerSheet extends StatefulWidget {
  final LandgrabApi api;
  final Region? current;
  final ValueChanged<Region>? onCurrentEdited;

  const _RegionPickerSheet({
    required this.api,
    required this.current,
    this.onCurrentEdited,
  });

  @override
  State<_RegionPickerSheet> createState() => _RegionPickerSheetState();
}

class _RegionPickerSheetState extends State<_RegionPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<Region> _results = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.api.searchRegions(query: q);
      if (!mounted) return;
      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not search regions: $e';
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(q));
  }

  Future<void> _createNew({Region? parent}) async {
    final created = await showDialog<Region>(
      context: context,
      builder: (_) => _RegionEditorDialog(api: widget.api, parent: parent),
    );
    if (created == null) return;
    if (!mounted) return;
    // Reload the picked region with its ancestor chain populated.
    try {
      final full = await widget.api.getRegion(created.id);
      if (!mounted) return;
      Navigator.of(context).pop(_PickerResult.pick(full));
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop(_PickerResult.pick(created));
    }
  }

  Future<void> _editExisting(Region region) async {
    final updated = await showDialog<Region>(
      context: context,
      builder: (_) => _RegionEditorDialog(api: widget.api, editing: region),
    );
    if (updated == null || !mounted) return;
    // Refresh the list so the row reflects the new values. We deliberately
    // don't pop the picker even if the edited region is the one currently
    // selected — editing is not picking.
    await _search(_searchController.text);
    // If the edited region happens to be the one currently assigned to the
    // puzzlet, push the refreshed copy up so the parent form's breadcrumb
    // doesn't go stale.
    if (widget.current?.id == updated.id && widget.onCurrentEdited != null) {
      try {
        final full = await widget.api.getRegion(updated.id);
        widget.onCurrentEdited!(full);
      } catch (_) {
        widget.onCurrentEdited!(updated);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: padding.bottom),
      child: SafeArea(
        top: false,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Search regions…',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                    if (widget.current != null) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context)
                            .pop(_PickerResult.clear()),
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear'),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () => _createNew(),
                  icon: const Icon(Icons.add),
                  label: const Text('New top-level region'),
                ),
              ),
              const Divider(),
              Expanded(child: _buildBody(scrollController)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ScrollController scrollController) {
    if (_error != null) return Center(child: Text(_error!));
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_results.isEmpty) {
      return const Center(child: Text('No regions match. Try creating one.'));
    }
    return ListView.separated(
      controller: scrollController,
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final r = _results[i];
        return ListTile(
          title: Text(r.name),
          subtitle: r.ancestors.isEmpty
              ? null
              : Text(r.ancestors.map((a) => a.name).join(' > '),
                  style: Theme.of(context).textTheme.bodySmall),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit ${r.name}',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editExisting(r),
              ),
              IconButton(
                tooltip: 'Add sub-region of ${r.name}',
                icon: const Icon(Icons.add),
                onPressed: () => _createNew(parent: r),
              ),
            ],
          ),
          onTap: () => Navigator.of(context).pop(_PickerResult.pick(r)),
        );
      },
    );
  }
}

/// Create *or* edit a region. Exactly one of [parent] / [editing] should be
/// non-null (or both null for a top-level create). When [editing] is set,
/// fields are pre-filled and Save calls `updateRegion`.
class _RegionEditorDialog extends StatefulWidget {
  final LandgrabApi api;
  final Region? parent;
  final Region? editing;

  const _RegionEditorDialog({required this.api, this.parent, this.editing});

  @override
  State<_RegionEditorDialog> createState() => _RegionEditorDialogState();
}

class _RegionEditorDialogState extends State<_RegionEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  late final TextEditingController _entryController;
  late List<String> _tags;
  Region? _parent;
  bool _parentChanged = false;
  bool _busy = false;
  String? _error;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _notesController = TextEditingController(text: e?.accessibilityNotes ?? '');
    _entryController = TextEditingController(text: e?.entryInstructions ?? '');
    _tags = [...?e?.accessibilityTags];

    // Seed the parent picker from the editing region's ancestor chain.
    // `ancestors.last` is the immediate parent (the chain is root → self,
    // self excluded). We only need id+name for the picker's display.
    if (e != null && e.parentRegionId != null && e.ancestors.isNotEmpty) {
      final immediate = e.ancestors.last;
      _parent = Region(
        id: immediate.id,
        name: immediate.name,
        parentRegionId: null,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _entryController.dispose();
    super.dispose();
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
    final notes = _notesController.text.trim();
    final entry = _entryController.text.trim();
    try {
      final result = _isEditing
          ? await widget.api.updateRegion(
              widget.editing!.id,
              name: name,
              accessibilityTags: _tags,
              // On edit, empty strings are sent so the user can clear a
              // previously-filled field.
              accessibilityNotes: notes,
              entryInstructions: entry,
              parentRegionId: _parentChanged ? _parent?.id : null,
              clearParent: _parentChanged && _parent == null,
            )
          : await widget.api.createRegion(
              name: name,
              parentRegionId: widget.parent?.id,
              accessibilityTags: _tags.isEmpty ? null : _tags,
              accessibilityNotes: notes.isEmpty ? null : notes,
              entryInstructions: entry.isEmpty ? null : entry,
            );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '${_isEditing ? 'Update' : 'Create'} failed: $e';
        _busy = false;
      });
    }
  }

  String _title() {
    if (_isEditing) return 'Edit ${widget.editing!.name}';
    if (widget.parent != null) return 'New sub-region of ${widget.parent!.name}';
    return 'New region';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_title()),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                autofocus: !_isEditing,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. 4th floor',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 12),
                // Re-parent affordance. Cycles (picking self or a
                // descendant) get rejected by the backend; the error
                // surfaces in the `_error` text below.
                RegionPickerField(
                  api: widget.api,
                  selected: _parent,
                  label: 'Parent region (optional)',
                  onChanged: (r) => setState(() {
                    _parent = r;
                    _parentChanged = true;
                  }),
                ),
              ],
              const SizedBox(height: 12),
              AccessibilityTagsField(
                selected: _tags,
                primary: kRegionPrimaryTags,
                onChanged: (next) => setState(() => _tags = next),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Accessibility notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _entryController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Entry instructions (optional)',
                  hintText: 'e.g. Keycard required after 6pm',
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
              : Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
