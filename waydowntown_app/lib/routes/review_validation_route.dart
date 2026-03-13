import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/models/answer.dart';
import 'package:waydowntown/models/specification_validation.dart';

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
  bool _isSaving = false;

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

  Future<void> _updateStatus(String status) async {
    setState(() => _isSaving = true);

    try {
      await widget.dio.patch(
        '/waydowntown/specification-validations/${_validation.id}',
        data: {
          'data': {
            'type': 'specification-validations',
            'id': _validation.id,
            'attributes': {'status': status},
          }
        },
      );
      await _refreshValidation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Validation $status')),
        );
      }
    } catch (e) {
      talker.error('Error updating status: $e');
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
                  trailing: Text(
                      _validation.playMode!.replaceAll('_', ' ')),
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

            // Comments
            if (_validation.comments.isNotEmpty) ...[
              Text('Comments',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ..._validation.comments.map((comment) {
                // Find the matching answer
                Answer? answer;
                if (comment.answerId != null) {
                  answer = spec?.answers?.cast<Answer?>().firstWhere(
                    (a) => a?.id == comment.answerId,
                    orElse: () => null,
                  );
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (answer != null && answer.label != null)
                              Chip(label: Text(answer.label!)),
                            if (comment.field != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Chip(
                                  label: Text(comment.field!),
                                  backgroundColor: Colors.grey[200],
                                ),
                              ),
                          ],
                        ),
                        if (comment.comment != null) ...[
                          const SizedBox(height: 4),
                          Text(comment.comment!),
                        ],
                        if (comment.suggestedValue != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Text('Suggested: ',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Expanded(
                                child: Text(
                                  comment.suggestedValue!,
                                  style: const TextStyle(
                                      fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],

            // Accept / Reject buttons
            if (_validation.status == 'submitted') ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _isSaving ? null : () => _updateStatus('accepted'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Accept'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _isSaving ? null : () => _updateStatus('rejected'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
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
