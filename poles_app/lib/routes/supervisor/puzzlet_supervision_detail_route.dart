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

  Future<void> _pickAndAssign() async {
    final previous = _activeValidation;
    final picked = await pickValidator(
      context,
      api: widget.api,
      excludeUserId: _puzzlet.creatorId,
      currentValidatorId: previous?.validatorId,
    );
    if (picked == null || !mounted) return;
    if (previous != null && previous.validatorId == picked.id) {
      // No-op — picked the same person who's already assigned.
      return;
    }

    setState(() => _busy = true);
    try {
      final validation = previous == null
          ? await widget.api.assignPuzzletValidation(_puzzlet.id, picked.id)
          : await widget.api
              .reassignPuzzletValidation(previous.id, picked.id);
      if (!mounted) return;
      setState(() {
        _activeValidation = validation;
        if (previous == null) {
          _validations = [validation, ..._validations];
        } else {
          _validations = _validations
              .map((v) => v.id == validation.id ? validation : v)
              .toList();
        }
        _busy = false;
      });
      _showAssignSnackBar(picked, previous, validation);
    } on DioException catch (e) {
      _showError(e);
    }
  }

  /// Snackbar with an Undo action that either deletes the fresh
  /// assignment or reassigns back to whoever was on it before.
  void _showAssignSnackBar(
    ValidatorUser picked,
    PuzzletValidationModel? previous,
    PuzzletValidationModel current,
  ) {
    final message = previous == null
        ? 'Assigned to ${picked.name ?? picked.email}.'
        : 'Reassigned to ${picked.name ?? picked.email}.';

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => _undoAssign(previous, current),
      ),
    ));
  }

  /// Tears down a fresh assignment outright (not just undo from a toast).
  /// Backend refuses if the validation already has comments.
  Future<void> _unassign() async {
    final v = _activeValidation;
    if (v == null) return;
    setState(() => _busy = true);
    try {
      await widget.api.unassignPuzzletValidation(v.id);
      if (!mounted) return;
      setState(() {
        _activeValidation = null;
        _validations = _validations.where((vv) => vv.id != v.id).toList();
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Validator unassigned.')),
      );
    } on DioException catch (e) {
      _showError(e);
    }
  }

  Future<void> _undoAssign(
    PuzzletValidationModel? previous,
    PuzzletValidationModel current,
  ) async {
    setState(() => _busy = true);
    try {
      if (previous == null) {
        await widget.api.unassignPuzzletValidation(current.id);
        if (!mounted) return;
        setState(() {
          _activeValidation = null;
          _validations =
              _validations.where((v) => v.id != current.id).toList();
          _busy = false;
        });
      } else {
        final reverted = await widget.api
            .reassignPuzzletValidation(current.id, previous.validatorId);
        if (!mounted) return;
        setState(() {
          _activeValidation = reverted;
          _validations = _validations
              .map((v) => v.id == reverted.id ? reverted : v)
              .toList();
          _busy = false;
        });
      }
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
            validator: v.validator,
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
    final canReassign = v != null &&
        (v.status == ValidationStatus.assigned ||
            v.status == ValidationStatus.inProgress);
    // Backend only allows tearing down an assignment that's still fresh
    // (status: assigned, no comments yet). Hiding the button outside that
    // window keeps the affordance honest.
    final canUnassign = v != null &&
        v.status == ValidationStatus.assigned &&
        v.comments.isEmpty;
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
                label: draftStatusLabel(_puzzlet.status),
                color: statusColorFor(draftStatusLabel(_puzzlet.status)),
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
              onPressed: _busy ? null : _pickAndAssign,
              icon: const Icon(Icons.assignment_ind),
              label: const Text('Assign to validator'),
            ),
          if (canReassign)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _pickAndAssign,
                      icon: const Icon(Icons.swap_horiz),
                      label: Text(v.validator != null
                          ? 'Change validator (${v.validator!.name ?? v.validator!.email})'
                          : 'Change validator'),
                    ),
                  ),
                  if (canUnassign) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _unassign,
                      icon: const Icon(Icons.person_remove_outlined),
                      label: const Text('Unassign'),
                    ),
                  ],
                ],
              ),
            ),
          if (v != null) ...[
            Text('Active validation',
                style: Theme.of(context).textTheme.titleMedium),
            Card(
              child: ListTile(
                title: Text(validationStatusLabel(v.status)),
                subtitle: Text(
                  [
                    if (v.validator != null)
                      'Assigned to ${v.validator!.name ?? v.validator!.email}',
                    '${v.comments.length} comment${v.comments.length == 1 ? '' : 's'}',
                  ].join(' · '),
                ),
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
