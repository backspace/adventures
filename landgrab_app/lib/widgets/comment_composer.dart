import 'package:flutter/material.dart';

class CommentDraft {
  final String field;
  final String? comment;
  final String? suggestedValue;
  CommentDraft({required this.field, this.comment, this.suggestedValue});
}

/// A modal sheet for composing one validation comment.
/// Returns a [CommentDraft] when the user submits, or null when cancelled.
Future<CommentDraft?> showCommentComposer(
  BuildContext context, {
  required List<String> fields,
}) {
  return showModalBottomSheet<CommentDraft>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _CommentComposer(fields: fields),
    ),
  );
}

class _CommentComposer extends StatefulWidget {
  final List<String> fields;
  const _CommentComposer({required this.fields});

  @override
  State<_CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<_CommentComposer> {
  late String _field;
  final _commentController = TextEditingController();
  final _suggestedController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _field = widget.fields.first;
  }

  @override
  void dispose() {
    _commentController.dispose();
    _suggestedController.dispose();
    super.dispose();
  }

  bool get _hasContent =>
      _commentController.text.trim().isNotEmpty ||
      _suggestedController.text.trim().isNotEmpty;

  void _submit() {
    if (!_hasContent) return;
    Navigator.of(context).pop(CommentDraft(
      field: _field,
      comment: _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
      suggestedValue: _suggestedController.text.trim().isEmpty
          ? null
          : _suggestedController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add a comment',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _field,
            decoration: const InputDecoration(
              labelText: 'Field',
              border: OutlineInputBorder(),
            ),
            items: widget.fields
                .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                .toList(),
            onChanged: (v) => setState(() => _field = v ?? _field),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            minLines: 2,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Comment (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _suggestedController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Suggested value (optional)',
              hintText: 'A new value the supervisor can apply',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _hasContent ? _submit : null,
                child: const Text('Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
