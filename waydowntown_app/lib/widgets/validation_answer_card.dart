import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/models/answer.dart';
import 'package:waydowntown/models/validation_comment.dart';

class ValidationAnswerCard extends StatefulWidget {
  final Dio dio;
  final Answer answer;
  final String validationId;
  final List<ValidationComment> existingComments;
  final bool showExpectedAnswers;
  final VoidCallback onCommentSaved;
  final bool readOnly;

  const ValidationAnswerCard({
    super.key,
    required this.dio,
    required this.answer,
    required this.validationId,
    required this.existingComments,
    required this.showExpectedAnswers,
    required this.onCommentSaved,
    this.readOnly = false,
  });

  @override
  State<ValidationAnswerCard> createState() => _ValidationAnswerCardState();
}

class _ValidationAnswerCardState extends State<ValidationAnswerCard> {
  bool _expanded = false;
  final _commentController = TextEditingController();
  final _suggestedValueController = TextEditingController();
  String? _selectedField;
  bool _isSaving = false;

  @override
  void dispose() {
    _commentController.dispose();
    _suggestedValueController.dispose();
    super.dispose();
  }

  String? _currentValueForField(String? field) {
    switch (field) {
      case 'label':
        return widget.answer.label;
      case 'answer':
        return widget.showExpectedAnswers ? widget.answer.answer : null;
      case 'hint':
        return widget.answer.hint;
      default:
        return null;
    }
  }

  void _onFieldChanged(String? field) {
    setState(() => _selectedField = field);
    final currentValue = _currentValueForField(field);
    _suggestedValueController.text = currentValue ?? '';
  }

  Future<void> _saveComment() async {
    if (_commentController.text.isEmpty &&
        _suggestedValueController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a comment or suggested value')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await widget.dio.post(
        '/waydowntown/validation-comments',
        data: {
          'data': {
            'type': 'validation-comments',
            'attributes': {
              'comment': _commentController.text.isNotEmpty
                  ? _commentController.text
                  : null,
              'suggested_value': _suggestedValueController.text.isNotEmpty
                  ? _suggestedValueController.text
                  : null,
              'field': _selectedField,
            },
            'relationships': {
              'specification-validation': {
                'data': {
                  'type': 'specification-validations',
                  'id': widget.validationId,
                }
              },
              'answer': {
                'data': {
                  'type': 'answers',
                  'id': widget.answer.id,
                }
              },
            },
          }
        },
      );
      _commentController.clear();
      _suggestedValueController.clear();
      setState(() => _selectedField = null);
      widget.onCommentSaved();
    } catch (e) {
      talker.error('Error saving comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await widget.dio.delete('/waydowntown/validation-comments/$commentId');
      widget.onCommentSaved();
    } catch (e) {
      talker.error('Error deleting comment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final answer = widget.answer;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            title: Text(answer.label ?? 'Answer'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showExpectedAnswers && answer.answer != null)
                  Text('Expected: ${answer.answer}'),
                if (answer.hint != null)
                  Text('Hint: ${answer.hint}',
                      style: const TextStyle(fontStyle: FontStyle.italic)),
                if (answer.hasHint && answer.hint == null)
                  const Text('Has hint (not revealed)',
                      style: TextStyle(
                          fontStyle: FontStyle.italic, color: Colors.grey)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.existingComments.isNotEmpty)
                  Badge(
                    label: Text('${widget.existingComments.length}'),
                    child: const Icon(Icons.comment),
                  ),
                IconButton(
                  icon: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const Divider(),
            if (widget.existingComments.isNotEmpty)
              ...widget.existingComments.map((comment) => _buildCommentTile(comment)),
            if (!widget.readOnly)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedField,
                      decoration:
                          const InputDecoration(labelText: 'Field'),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('General')),
                        if (answer.answer != null || widget.showExpectedAnswers)
                          const DropdownMenuItem(
                              value: 'answer', child: Text('Answer')),
                        if (answer.label != null)
                          const DropdownMenuItem(
                              value: 'label', child: Text('Label')),
                        if (answer.hint != null || answer.hasHint)
                          const DropdownMenuItem(
                              value: 'hint', child: Text('Hint')),
                      ],
                      onChanged: _onFieldChanged,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        labelText: 'Comment',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _suggestedValueController,
                      decoration: const InputDecoration(
                        labelText: 'Suggested replacement',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveComment,
                      child: const Text('Add Comment'),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentTile(ValidationComment comment) {
    return ListTile(
      dense: true,
      title: Text(comment.comment ?? ''),
      subtitle: comment.suggestedValue != null
          ? Text(
              'Suggested: ${comment.suggestedValue}',
              style: const TextStyle(fontStyle: FontStyle.italic),
            )
          : null,
      leading: comment.field != null
          ? Chip(
              label:
                  Text(comment.field!, style: const TextStyle(fontSize: 10)),
            )
          : null,
      trailing: widget.readOnly
          ? _commentStatusIcon(comment.status)
          : IconButton(
              icon: const Icon(Icons.delete, size: 18),
              onPressed: () => _deleteComment(comment.id),
            ),
    );
  }

  Widget? _commentStatusIcon(String status) {
    switch (status) {
      case 'accepted':
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      case 'rejected':
        return const Icon(Icons.cancel, color: Colors.red, size: 20);
      default:
        return null;
    }
  }
}
