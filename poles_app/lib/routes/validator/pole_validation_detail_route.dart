import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/validation.dart';
import 'package:poles/widgets/comment_composer.dart';
import 'package:poles/widgets/status_badge.dart';

const _poleFields = ['barcode', 'label', 'latitude', 'longitude', 'notes'];

class PoleValidationDetailRoute extends StatefulWidget {
  final PolesApi api;
  final PoleValidationModel validation;

  const PoleValidationDetailRoute({
    super.key,
    required this.api,
    required this.validation,
  });

  @override
  State<PoleValidationDetailRoute> createState() =>
      _PoleValidationDetailRouteState();
}

class _PoleValidationDetailRouteState extends State<PoleValidationDetailRoute> {
  late PoleValidationModel _v;
  bool _busy = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _v = widget.validation;
  }

  Future<void> _transition(String to) async {
    setState(() => _busy = true);
    try {
      final updated = await widget.api.transitionPoleValidation(_v.id, to);
      if (!mounted) return;
      setState(() {
        _v = updated;
        _busy = false;
        _dirty = true;
      });
    } on DioException catch (e) {
      _showError(e);
    }
  }

  Future<void> _addComment() async {
    final draft = await showCommentComposer(context, fields: _poleFields);
    if (draft == null) return;

    setState(() => _busy = true);
    try {
      await widget.api.createPoleComment(
        _v.id,
        field: draft.field,
        comment: draft.comment,
        suggestedValue: draft.suggestedValue,
      );
      final mine = await widget.api.listMyValidations();
      final refreshed = mine.poleValidations.firstWhere(
        (p) => p.id == _v.id,
        orElse: () => _v,
      );
      if (!mounted) return;
      setState(() {
        _v = refreshed;
        _busy = false;
        _dirty = true;
      });
    } on DioException catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    setState(() => _busy = true);
    try {
      await widget.api.deletePoleComment(commentId);
      final mine = await widget.api.listMyValidations();
      final refreshed = mine.poleValidations.firstWhere(
        (p) => p.id == _v.id,
        orElse: () => _v,
      );
      if (!mounted) return;
      setState(() {
        _v = refreshed;
        _busy = false;
        _dirty = true;
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
    final pole = _v.pole;
    final canStart = _v.status == ValidationStatus.assigned;
    final canSubmit = _v.status == ValidationStatus.inProgress;
    final canEditComments = _v.status == ValidationStatus.inProgress;

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop<bool>(_dirty);
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(pole?.label ?? pole?.barcode ?? 'Validation'),
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
          if (pole != null) _PoleSummaryCard(pole: pole),
          const SizedBox(height: 16),
          Text('Comments', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_v.comments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No comments yet.'),
            ),
          ..._v.comments.map((c) => _CommentTile(
                comment: c,
                canDelete: canEditComments,
                onDelete: () => _deleteComment(c.id),
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
      ),
    );
  }
}

class _PoleSummaryCard extends StatelessWidget {
  final ValidationPoleSummary pole;
  const _PoleSummaryCard({required this.pole});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Barcode: ${pole.barcode}'),
            if (pole.label != null) Text('Label: ${pole.label}'),
            const SizedBox(height: 4),
            Text(
              '${pole.latitude.toStringAsFixed(5)}, ${pole.longitude.toStringAsFixed(5)}',
            ),
            if (pole.notes != null) ...[
              const SizedBox(height: 8),
              const Text('Author notes:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(pole.notes!),
            ],
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final ValidationComment comment;
  final bool canDelete;
  final VoidCallback onDelete;

  const _CommentTile({
    required this.comment,
    required this.canDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                comment.field,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            StatusBadge(
              label: comment.status.name,
              color: statusColorFor(comment.status.name),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (comment.suggestedValue != null)
              Text('Suggest: ${comment.suggestedValue}'),
            if (comment.comment != null) Text(comment.comment!),
          ],
        ),
        trailing: canDelete
            ? IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              )
            : null,
      ),
    );
  }
}
