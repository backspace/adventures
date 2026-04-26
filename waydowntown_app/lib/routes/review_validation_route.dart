import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/models/answer.dart';
import 'package:waydowntown/models/specification_validation.dart';
import 'package:waydowntown/models/validation_comment.dart';

class ReviewValidationRoute extends StatefulWidget {
  final Dio dio;
  final SpecificationValidation validation;

  const ReviewValidationRoute({
    super.key,
    required this.dio,
    required this.validation,
  });

  @override
  State<ReviewValidationRoute> createState() => _ReviewValidationRouteState();
}

class _ReviewValidationRouteState extends State<ReviewValidationRoute> {
  late SpecificationValidation _validation;

  @override
  void initState() {
    super.initState();
    _validation = widget.validation;
  }

  Future<void> _refreshValidation() async {
    try {
      final response = await widget.dio
          .get('/waydowntown/specification-validations/${_validation.id}');
      if (response.statusCode == 200) {
        final included =
            (response.data['included'] as List<dynamic>?) ?? [];
        setState(() {
          _validation = SpecificationValidation.fromJson(
              response.data['data'], included);
        });
      }
    } catch (e) {
      talker.error('Error refreshing validation: $e');
    }
  }

  Future<void> _updateCommentStatus(String commentId, String status) async {
    try {
      await widget.dio.patch(
        '/waydowntown/validation-comments/$commentId',
        data: {
          'data': {
            'type': 'validation-comments',
            'id': commentId,
            'attributes': {'status': status},
          }
        },
      );
      await _refreshValidation();
    } catch (e) {
      talker.error('Error updating comment status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = _validation.specification;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Validation'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status
            Card(
              child: ListTile(
                title: const Text('Status'),
                subtitle: Text(
                    'Validator: ${_validation.validatorName ?? 'Unknown'}'),
                trailing: Chip(
                  label: Text(
                    _validation.status.replaceAll('_', ' '),
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: _statusColor(_validation.status),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Specification info
            if (spec != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Specification',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('Concept: ${spec.concept}'),
                      if (spec.startDescription != null)
                        Text('Start: ${spec.startDescription}'),
                      if (spec.taskDescription != null)
                        Text('Task: ${spec.taskDescription}'),
                      if (spec.region != null)
                        Text('Region: ${spec.region!.name}'),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),

            // Play mode
            if (_validation.playMode != null)
              Card(
                child: ListTile(
                  title: const Text('Play Mode'),
                  trailing:
                      Text(_validation.playMode!.replaceAll('_', ' ')),
                ),
              ),
            const SizedBox(height: 8),

            // Overall notes
            if (_validation.overallNotes != null) ...[
              Text("Validator\u2019s Notes",
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_validation.overallNotes!),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Annotations grouped for review
            if (_validation.comments.isNotEmpty) ...[
              Text('Annotations',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ..._validation.comments.map((comment) {
                Answer? answer;
                if (comment.answerId != null) {
                  answer = spec?.answers?.cast<Answer?>().firstWhere(
                        (a) => a?.id == comment.answerId,
                        orElse: () => null,
                      );
                }

                return _buildAnnotationCard(context, comment, answer);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnnotationCard(
      BuildContext context, ValidationComment comment, Answer? answer) {
    final isSpecField = comment.answerId == null && comment.field != null;
    String targetLabel;
    if (isSpecField) {
      targetLabel = comment.field!.replaceAll('_', ' ');
      // Capitalize
      targetLabel = targetLabel[0].toUpperCase() + targetLabel.substring(1);
    } else if (answer != null) {
      targetLabel = answer.label ?? 'Answer';
      if (comment.field != null) {
        targetLabel += ' (${comment.field})';
      }
    } else {
      targetLabel = 'General';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: _cardColor(comment.status),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Chip(
                    label: Text(targetLabel, style: const TextStyle(fontSize: 12)),
                  ),
                ),
                _statusBadge(comment.status),
              ],
            ),
            if (comment.comment != null) ...[
              const SizedBox(height: 4),
              Text(comment.comment!),
            ],
            if (comment.suggestedValue != null) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Suggested: ',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      comment.suggestedValue!,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ],
            if (comment.status == 'pending') ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        _updateCommentStatus(comment.id, 'accepted'),
                    icon:
                        const Icon(Icons.check, color: Colors.green, size: 18),
                    label: const Text('Accept',
                        style: TextStyle(color: Colors.green)),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () =>
                        _updateCommentStatus(comment.id, 'rejected'),
                    icon:
                        const Icon(Icons.close, color: Colors.red, size: 18),
                    label: const Text('Reject',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    switch (status) {
      case 'accepted':
        return const Chip(
          label: Text('Accepted', style: TextStyle(fontSize: 10, color: Colors.white)),
          backgroundColor: Colors.green,
        );
      case 'rejected':
        return const Chip(
          label: Text('Rejected', style: TextStyle(fontSize: 10, color: Colors.white)),
          backgroundColor: Colors.red,
        );
      default:
        return const Chip(
          label: Text('Pending', style: TextStyle(fontSize: 10)),
        );
    }
  }

  Color? _cardColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green[50];
      case 'rejected':
        return Colors.red[50];
      default:
        return null;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'assigned':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'submitted':
        return Colors.purple;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
