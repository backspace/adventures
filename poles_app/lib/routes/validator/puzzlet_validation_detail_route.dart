import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/validation.dart';
import 'package:poles/widgets/comment_composer.dart';
import 'package:poles/widgets/status_badge.dart';

const _puzzletFields = ['instructions', 'answer', 'difficulty'];

class PuzzletValidationDetailRoute extends StatefulWidget {
  final PolesApi api;
  final PuzzletValidationModel validation;

  const PuzzletValidationDetailRoute({
    super.key,
    required this.api,
    required this.validation,
  });

  @override
  State<PuzzletValidationDetailRoute> createState() =>
      _PuzzletValidationDetailRouteState();
}

class _PuzzletValidationDetailRouteState extends State<PuzzletValidationDetailRoute> {
  late PuzzletValidationModel _v;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _v = widget.validation;
  }

  Future<void> _transition(String to) async {
    setState(() => _busy = true);
    try {
      final updated = await widget.api.transitionPuzzletValidation(_v.id, to);
      if (!mounted) return;
      setState(() {
        _v = updated;
        _busy = false;
      });
    } on DioException catch (e) {
      _showError(e);
    }
  }

  Future<void> _addComment() async {
    final draft = await showCommentComposer(context, fields: _puzzletFields);
    if (draft == null) return;

    setState(() => _busy = true);
    try {
      await widget.api.createPuzzletComment(
        _v.id,
        field: draft.field,
        comment: draft.comment,
        suggestedValue: draft.suggestedValue,
      );
      final mine = await widget.api.listMyValidations();
      final refreshed = mine.puzzletValidations.firstWhere(
        (p) => p.id == _v.id,
        orElse: () => _v,
      );
      if (!mounted) return;
      setState(() {
        _v = refreshed;
        _busy = false;
      });
    } on DioException catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    setState(() => _busy = true);
    try {
      await widget.api.deletePuzzletComment(commentId);
      final mine = await widget.api.listMyValidations();
      final refreshed = mine.puzzletValidations.firstWhere(
        (p) => p.id == _v.id,
        orElse: () => _v,
      );
      if (!mounted) return;
      setState(() {
        _v = refreshed;
        _busy = false;
      });
    } on DioException catch (e) {
      _showError(e);
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
    final puzzlet = _v.puzzlet;
    final canStart = _v.status == ValidationStatus.assigned;
    final canSubmit = _v.status == ValidationStatus.inProgress;
    final canEditComments = _v.status == ValidationStatus.inProgress;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Validation'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: StatusBadge(
                label: validationStatusLabel(_v.status),
                color: statusColorFor(_v.status.name),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (puzzlet != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(puzzlet.instructions),
                    const SizedBox(height: 8),
                    Text('Answer: ${puzzlet.answer}'),
                    Text('Difficulty: ${puzzlet.difficulty}'),
                    if (puzzlet.latitude != null && puzzlet.longitude != null)
                      Text(
                        'Authored at: ${puzzlet.latitude!.toStringAsFixed(5)}, ${puzzlet.longitude!.toStringAsFixed(5)}',
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('Comments', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_v.comments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No comments yet.'),
            ),
          ..._v.comments.map((c) => Card(
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
                      if (c.suggestedValue != null) Text('Suggest: ${c.suggestedValue}'),
                      if (c.comment != null) Text(c.comment!),
                    ],
                  ),
                  trailing: canEditComments
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteComment(c.id),
                        )
                      : null,
                ),
              )),
          if (canEditComments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _addComment,
                icon: const Icon(Icons.add),
                label: const Text('Add comment'),
              ),
            ),
          const SizedBox(height: 24),
          if (canStart)
            FilledButton.icon(
              onPressed: _busy ? null : () => _transition('in_progress'),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start review'),
            ),
          if (canSubmit)
            FilledButton.icon(
              onPressed: _busy ? null : () => _transition('submitted'),
              icon: const Icon(Icons.send),
              label: const Text('Submit for supervisor'),
            ),
        ],
      ),
    );
  }
}
