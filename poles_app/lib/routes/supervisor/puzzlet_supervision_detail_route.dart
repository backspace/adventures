import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/draft.dart';
import 'package:poles/models/validation.dart';
import 'package:poles/routes/supervisor/supervisor_edit_puzzlet_route.dart';
import 'package:poles/routes/supervisor/validator_picker.dart';
import 'package:poles/widgets/status_badge.dart';

class PuzzletSupervisionDetailRoute extends StatefulWidget {
  final PolesApi api;
  final DraftPuzzlet puzzlet;

  const PuzzletSupervisionDetailRoute({
    super.key,
    required this.api,
    required this.puzzlet,
  });

  @override
  State<PuzzletSupervisionDetailRoute> createState() =>
      _PuzzletSupervisionDetailRouteState();
}

class _PuzzletSupervisionDetailRouteState
    extends State<PuzzletSupervisionDetailRoute> {
  late DraftPuzzlet _puzzlet;
  List<PuzzletValidationModel> _validations = const [];
  PuzzletValidationModel? _activeValidation;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _puzzlet = widget.puzzlet;
    _loadValidations();
  }

  Future<void> _loadValidations() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.listPuzzletValidations(_puzzlet.id);
      if (!mounted) return;
      setState(() {
        _validations = list;
        _activeValidation = _pickActive(list);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load validations: $e')),
      );
    }
  }

  PuzzletValidationModel? _pickActive(List<PuzzletValidationModel> list) {
    for (final v in list) {
      if (v.status != ValidationStatus.accepted &&
          v.status != ValidationStatus.rejected) {
        return v;
      }
    }
    return null;
  }

  Future<void> _assign() async {
    final picked = await pickValidator(
      context,
      api: widget.api,
      excludeUserId: _puzzlet.creatorId,
    );
    if (picked == null) return;

    setState(() => _busy = true);
    try {
      final validation =
          await widget.api.assignPuzzletValidation(_puzzlet.id, picked.id);
      if (!mounted) return;
      setState(() {
        _activeValidation = validation;
        _validations = [validation, ..._validations];
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Assigned to ${picked.name ?? picked.email}.')),
      );
    } on DioException catch (e) {
      _showError(e);
    }
  }

  Future<void> _decide(String status) async {
    final v = _activeValidation;
    if (v == null) return;
    setState(() => _busy = true);
    try {
      final updated =
          await widget.api.supervisorTransitionPuzzletValidation(v.id, status);
      if (!mounted) return;
      setState(() {
        _activeValidation = updated;
        _busy = false;
      });
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      _showError(e);
    }
  }

  Future<void> _decideComment(String commentId, String status) async {
    setState(() => _busy = true);
    try {
      final updated = await widget.api.decidePuzzletComment(commentId, status);
      if (!mounted) return;
      final v = _activeValidation;
      if (v != null) {
        final replaced = v.comments
            .map((c) => c.id == updated.id ? updated : c)
            .toList();
        setState(() {
          _activeValidation = PuzzletValidationModel(
            id: v.id,
            status: v.status,
            overallNotes: v.overallNotes,
            puzzletId: v.puzzletId,
            validatorId: v.validatorId,
            assignedById: v.assignedById,
            puzzlet: v.puzzlet,
            comments: replaced,
          );
        });
      }
      setState(() => _busy = false);
    } on DioException catch (e) {
      _showError(e);
    }
  }

  Future<void> _editFields() async {
    final updated = await Navigator.of(context).push<DraftPuzzlet>(
      MaterialPageRoute(
        builder: (_) =>
            SupervisorEditPuzzletRoute(api: widget.api, puzzlet: _puzzlet),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _puzzlet = updated);
    }
  }

  void _showError(DioException e) {
    if (!mounted) return;
    final detail = e.response?.data?['error']?['detail'] ??
        e.response?.data?['errors']?.toString() ??
        e.message;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Action failed: $detail')));
  }

  @override
  Widget build(BuildContext context) {
    final v = _activeValidation;
    final canAssign = v == null && _puzzlet.status == DraftStatus.draft;
    final canDecide = v?.status == ValidationStatus.submitted;

    final pastValidations = _validations
        .where((vv) => vv.id != _activeValidation?.id)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Puzzlet'),
        actions: [
          IconButton(
            tooltip: 'Edit fields',
            onPressed: _busy ? null : _editFields,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(onPressed: _loading ? null : _loadValidations, icon: const Icon(Icons.refresh)),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: StatusBadge(
                label: _puzzlet.status.name,
                color: statusColorFor(_puzzlet.status.name),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_puzzlet.instructions),
                  const SizedBox(height: 8),
                  Text('Answer: ${_puzzlet.answer}'),
                  Text('Difficulty: ${_puzzlet.difficulty}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (canAssign)
            FilledButton.icon(
              onPressed: _busy ? null : _assign,
              icon: const Icon(Icons.assignment_ind),
              label: const Text('Assign to validator'),
            ),
          if (v != null) ...[
            Text('Active validation',
                style: Theme.of(context).textTheme.titleMedium),
            Card(
              child: ListTile(
                title: Text(validationStatusLabel(v.status)),
                subtitle: Text(
                    '${v.comments.length} comment${v.comments.length == 1 ? '' : 's'}'),
              ),
            ),
            for (final c in v.comments)
              Card(
                child: ListTile(
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.field,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      StatusBadge(
                        label: c.status.name,
                        color: statusColorFor(c.status.name),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (c.suggestedValue != null)
                        Text('Suggest: ${c.suggestedValue}'),
                      if (c.comment != null) Text(c.comment!),
                      if (c.status == CommentStatus.pending && canDecide)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _decideComment(c.id, 'rejected'),
                                child: const Text('Reject'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: _busy
                                    ? null
                                    : () => _decideComment(c.id, 'accepted'),
                                child: const Text('Apply'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (canDecide)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _decide('rejected'),
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _decide('accepted'),
                      icon: const Icon(Icons.check),
                      label: const Text('Accept'),
                    ),
                  ),
                ],
              ),
          ],
          if (pastValidations.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('History', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final past in pastValidations)
              Card(
                child: ExpansionTile(
                  title: Row(
                    children: [
                      Expanded(child: Text(validationStatusLabel(past.status))),
                      StatusBadge(
                        label: past.status.name,
                        color: statusColorFor(past.status.name),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${past.comments.length} comment${past.comments.length == 1 ? '' : 's'}',
                  ),
                  children: past.comments
                      .map((c) => ListTile(
                            title: Text(c.field,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (c.suggestedValue != null)
                                  Text('Suggest: ${c.suggestedValue}'),
                                if (c.comment != null) Text(c.comment!),
                              ],
                            ),
                            trailing: StatusBadge(
                              label: c.status.name,
                              color: statusColorFor(c.status.name),
                            ),
                          ))
                      .toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
