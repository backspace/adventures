import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/models/validation_comment.dart';

class ValidationFieldCommentCard extends StatefulWidget {
  final Dio dio;
  final String validationId;
  final String fieldName;
  final String fieldLabel;
  final String fieldValue;
  final List<ValidationComment> existingComments;
  final VoidCallback onCommentSaved;
  final bool readOnly;

  const ValidationFieldCommentCard({
    super.key,
    required this.dio,
    required this.validationId,
    required this.fieldName,
    required this.fieldLabel,
    required this.fieldValue,
    required this.existingComments,
    required this.onCommentSaved,
    this.readOnly = false,
  });

  @override
  State<ValidationFieldCommentCard> createState() =>
      _ValidationFieldCommentCardState();
}

class _ValidationFieldCommentCardState
    extends State<ValidationFieldCommentCard> {
  bool _expanded = false;
  final _commentController = TextEditingController();
  final _suggestedValueController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _commentController.dispose();
    _suggestedValueController.dispose();
    super.dispose();
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
              'field': widget.fieldName,
            },
            'relationships': {
              'specification-validation': {
                'data': {
                  'type': 'specification-validations',
                  'id': widget.validationId,
                }
              },
            },
          }
        },
      );
      _commentController.clear();
      _suggestedValueController.clear();
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            title: Text(widget.fieldLabel),
            subtitle: Text(widget.fieldValue),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.existingComments.isNotEmpty)
                  Badge(
                    label: Text('${widget.existingComments.length}'),
                    child: const Icon(Icons.comment),
                  ),
                IconButton(
                  icon:
                      Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const Divider(),
            if (widget.existingComments.isNotEmpty)
              ...widget.existingComments.map((comment) => ListTile(
                    dense: true,
                    title: Text(comment.comment ?? ''),
                    subtitle: comment.suggestedValue != null
                        ? Text(
                            'Suggested: ${comment.suggestedValue}',
                            style:
                                const TextStyle(fontStyle: FontStyle.italic),
                          )
                        : null,
                    trailing: widget.readOnly
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.delete, size: 18),
                            onPressed: () => _deleteComment(comment.id),
                          ),
                  )),
            if (!widget.readOnly)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      maxLines: 2,
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
}
