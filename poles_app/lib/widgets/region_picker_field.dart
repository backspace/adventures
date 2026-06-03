import 'dart:async';

import 'package:flutter/material.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/region.dart';

/// Form-field-style picker for a puzzlet's region. Shows the currently
/// selected region's breadcrumb (or "No region") and opens a search sheet
/// on tap. The sheet supports search-as-you-type, picking an existing
/// region, creating a new sub-region of any visible region, and clearing
/// the current selection.
class RegionPickerField extends StatelessWidget {
  final PolesApi api;
  final Region? selected;
  final ValueChanged<Region?> onChanged;

  const RegionPickerField({
    super.key,
    required this.api,
    required this.selected,
    required this.onChanged,
  });

  Future<void> _open(BuildContext context) async {
    final result = await showModalBottomSheet<_PickerResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RegionPickerSheet(api: api, current: selected),
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
        decoration: const InputDecoration(
          labelText: 'Region (optional)',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.arrow_drop_down),
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
  final PolesApi api;
  final Region? current;

  const _RegionPickerSheet({required this.api, required this.current});

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
      builder: (_) => _NewRegionDialog(api: widget.api, parent: parent),
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
          trailing: IconButton(
            tooltip: 'Add sub-region of ${r.name}',
            icon: const Icon(Icons.add),
            onPressed: () => _createNew(parent: r),
          ),
          onTap: () => Navigator.of(context).pop(_PickerResult.pick(r)),
        );
      },
    );
  }
}

class _NewRegionDialog extends StatefulWidget {
  final PolesApi api;
  final Region? parent;

  const _NewRegionDialog({required this.api, this.parent});

  @override
  State<_NewRegionDialog> createState() => _NewRegionDialogState();
}

class _NewRegionDialogState extends State<_NewRegionDialog> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _entryController = TextEditingController();
  bool _busy = false;
  String? _error;

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
    try {
      final created = await widget.api.createRegion(
        name: name,
        parentRegionId: widget.parent?.id,
        accessibilityNotes:
            _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        entryInstructions:
            _entryController.text.trim().isEmpty ? null : _entryController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Create failed: $e';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.parent == null
          ? 'New region'
          : 'New sub-region of ${widget.parent!.name}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. 4th floor',
                border: OutlineInputBorder(),
              ),
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
              : const Text('Create'),
        ),
      ],
    );
  }
}
