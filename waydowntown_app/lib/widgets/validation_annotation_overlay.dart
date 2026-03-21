import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/models/validation_comment.dart';

class ValidationAnnotationOverlay extends StatefulWidget {
  final Widget child;
  final Dio dio;
  final String validationId;
  final List<Map<String, dynamic>> answers;

  const ValidationAnnotationOverlay({
    super.key,
    required this.child,
    required this.dio,
    required this.validationId,
    required this.answers,
  });

  @override
  State<ValidationAnnotationOverlay> createState() =>
      _ValidationAnnotationOverlayState();
}

class _ValidationAnnotationOverlayState
    extends State<ValidationAnnotationOverlay> {
  List<ValidationComment> _comments = [];

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    try {
      final response = await widget.dio
          .get('/waydowntown/specification-validations/${widget.validationId}');
      if (response.statusCode == 200) {
        final included =
            (response.data['included'] as List<dynamic>?) ?? [];
        final relationships =
            response.data['data']['relationships'] as Map<String, dynamic>?;
        final commentDataList =
            (relationships?['validation_comments']?['data'] as List<dynamic>?) ??
                [];

        final comments = <ValidationComment>[];
        for (final commentData in commentDataList) {
          final commentJson = included.firstWhere(
            (item) =>
                item['type'] == 'validation-comments' &&
                item['id'] == commentData['id'],
            orElse: () => null,
          );
          if (commentJson != null) {
            comments.add(ValidationComment.fromJson(commentJson, included));
          }
        }
        if (mounted) {
          setState(() => _comments = comments);
        }
      }
    } catch (e) {
      talker.error('Error fetching comments: $e');
    }
  }

  List<ValidationComment> _commentsForAnswer(String answerId) {
    return _comments.where((c) => c.answerId == answerId).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          right: 16,
          bottom: 80,
          child: FloatingActionButton(
            heroTag: 'validation_notes',
            onPressed: () => _showAnnotationSheet(context),
            child: Badge(
              isLabelVisible: _comments.isNotEmpty,
              label: Text('${_comments.length}'),
              child: const Icon(Icons.edit_note),
            ),
          ),
        ),
      ],
    );
  }

  void _showAnnotationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _AnnotationSheet(
          dio: widget.dio,
          validationId: widget.validationId,
          answers: widget.answers,
          comments: _comments,
          commentsForAnswer: _commentsForAnswer,
          scrollController: scrollController,
          onCommentSaved: _fetchComments,
        ),
      ),
    );
  }
}

class _AnnotationSheet extends StatefulWidget {
  final Dio dio;
  final String validationId;
  final List<Map<String, dynamic>> answers;
  final List<ValidationComment> comments;
  final List<ValidationComment> Function(String) commentsForAnswer;
  final ScrollController scrollController;
  final VoidCallback onCommentSaved;

  const _AnnotationSheet({
    required this.dio,
    required this.validationId,
    required this.answers,
    required this.comments,
    required this.commentsForAnswer,
    required this.scrollController,
    required this.onCommentSaved,
  });

  @override
  State<_AnnotationSheet> createState() => _AnnotationSheetState();
}

class _AnnotationSheetState extends State<_AnnotationSheet> {
  final _commentController = TextEditingController();
  String? _selectedAnswerId;
  bool _isSaving = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _saveComment() async {
    if (_commentController.text.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final relationships = <String, dynamic>{
        'specification-validation': {
          'data': {
            'type': 'specification-validations',
            'id': widget.validationId,
          }
        },
      };

      if (_selectedAnswerId != null) {
        relationships['answer'] = {
          'data': {
            'type': 'answers',
            'id': _selectedAnswerId,
          }
        };
      }

      await widget.dio.post(
        '/waydowntown/validation-comments',
        data: {
          'data': {
            'type': 'validation-comments',
            'attributes': {
              'comment': _commentController.text,
            },
            'relationships': relationships,
          }
        },
      );

      _commentController.clear();
      setState(() => _selectedAnswerId = null);
      widget.onCommentSaved();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note saved'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      talker.error('Error saving annotation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Validation Notes',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        // Quick comment input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.answers.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedAnswerId,
                  decoration: const InputDecoration(
                    labelText: 'About',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('General / overall'),
                    ),
                    ...widget.answers.map((a) => DropdownMenuItem(
                          value: a['id'] as String,
                          child: Text(
                            a['label'] ?? a['answer'] ?? 'Answer',
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedAnswerId = v),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Add a note...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 2,
                      minLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSaving ? null : _saveComment,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 24),
        // Existing comments
        Expanded(
          child: widget.comments.isEmpty
              ? const Center(
                  child: Text(
                    'No notes yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  controller: widget.scrollController,
                  itemCount: widget.comments.length,
                  itemBuilder: (context, index) {
                    final comment = widget.comments[index];
                    final answerInfo = comment.answerId != null
                        ? widget.answers.cast<Map<String, dynamic>?>().firstWhere(
                            (a) => a?['id'] == comment.answerId,
                            orElse: () => null,
                          )
                        : null;

                    return ListTile(
                      dense: true,
                      leading: Icon(
                        comment.answerId != null
                            ? Icons.question_answer
                            : Icons.notes,
                        size: 20,
                        color: Colors.grey,
                      ),
                      title: Text(comment.comment ?? ''),
                      subtitle: Text(
                        answerInfo != null
                            ? 'Re: ${answerInfo['label'] ?? answerInfo['answer'] ?? 'Answer'}'
                            : 'General',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: comment.suggestedValue != null
                          ? Chip(
                              label: Text(
                                comment.suggestedValue!,
                                style: const TextStyle(fontSize: 10),
                              ),
                            )
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
