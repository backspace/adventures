import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/models/specification_validation.dart';
import 'package:waydowntown/routes/request_run_route.dart';
import 'package:waydowntown/widgets/validation_answer_card.dart';

class ValidationDetailRoute extends StatefulWidget {
  final Dio dio;
  final SpecificationValidation validation;

  const ValidationDetailRoute({
    super.key,
    required this.dio,
    required this.validation,
  });

  @override
  State<ValidationDetailRoute> createState() => _ValidationDetailRouteState();
}

class _ValidationDetailRouteState extends State<ValidationDetailRoute> {
  late SpecificationValidation _validation;
  final _notesController = TextEditingController();
  String? _selectedPlayMode;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _validation = widget.validation;
    _notesController.text = _validation.overallNotes ?? '';
    _selectedPlayMode = _validation.playMode;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
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
          _notesController.text = _validation.overallNotes ?? '';
          _selectedPlayMode = _validation.playMode;
        });
      }
    } catch (e) {
      talker.error('Error refreshing validation: $e');
    }
  }

  Future<void> _updateValidation(Map<String, dynamic> attrs) async {
    setState(() => _isSaving = true);

    try {
      await widget.dio.patch(
        '/waydowntown/specification-validations/${_validation.id}',
        data: {
          'data': {
            'type': 'specification-validations',
            'id': _validation.id,
            'attributes': attrs,
          }
        },
      );
      await _refreshValidation();
    } catch (e) {
      talker.error('Error updating validation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _startValidation() async {
    if (_selectedPlayMode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a play mode first')),
      );
      return;
    }

    await _updateValidation({
      'status': 'in_progress',
      'play_mode': _selectedPlayMode,
    });
  }

  Future<void> _playSpecification() async {
    if (_validation.specification == null) return;

    final spec = _validation.specification!;
    final answerMaps = spec.answers
            ?.map((a) => {
                  'id': a.id,
                  'label': a.label,
                  'answer': a.answer,
                })
            .toList() ??
        [];

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RequestRunRoute(
          dio: widget.dio,
          specificationId: spec.id,
          validationId: _validation.id,
          validationAnswers: answerMaps,
        ),
      ),
    );

    if (result != null && result is String) {
      await _updateValidation({'run_id': result});
    }

    await _refreshValidation();
  }

  Future<void> _submitValidation() async {
    await _updateValidation({
      'status': 'submitted',
      'overall_notes': _notesController.text,
    });
  }

  bool get _canEdit =>
      _validation.status == 'assigned' ||
      _validation.status == 'in_progress';

  @override
  Widget build(BuildContext context) {
    final spec = _validation.specification;

    return Scaffold(
      appBar: AppBar(
        title: Text(spec?.concept ?? 'Validation'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status card
            Card(
              child: ListTile(
                title: const Text('Status'),
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
            if (spec != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Concept: ${spec.concept}',
                          style: Theme.of(context).textTheme.titleMedium),
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
            ],

            // Play mode selection (only when assigned)
            if (_validation.status == 'assigned') ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Play Mode',
                          style: Theme.of(context).textTheme.titleMedium),
                      RadioListTile<String>(
                        title: const Text('Play without answers'),
                        subtitle: const Text(
                            'Play without seeing the expected answers'),
                        value: 'without_answers',
                        groupValue: _selectedPlayMode,
                        onChanged: (v) =>
                            setState(() => _selectedPlayMode = v),
                      ),
                      RadioListTile<String>(
                        title: const Text('Play with answers'),
                        subtitle: const Text(
                            'See expected answers while playing'),
                        value: 'with_answers',
                        groupValue: _selectedPlayMode,
                        onChanged: (v) =>
                            setState(() => _selectedPlayMode = v),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _startValidation,
                          child: const Text('Start Validation'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Play button (when in progress)
            if (_validation.status == 'in_progress') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: _playSpecification,
                  label: const Text('Play Specification'),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Answer cards
            if (spec != null &&
                spec.answers != null &&
                spec.answers!.isNotEmpty) ...[
              Text('Answers',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...spec.answers!.map((answer) => ValidationAnswerCard(
                    dio: widget.dio,
                    answer: answer,
                    validationId: _validation.id,
                    existingComments: _validation.comments
                        .where((c) => c.answerId == answer.id)
                        .toList(),
                    showExpectedAnswers:
                        _validation.playMode == 'with_answers',
                    onCommentSaved: _refreshValidation,
                    readOnly: !_canEdit,
                  )),
              const SizedBox(height: 16),
            ],

            // Overall notes
            if (_canEdit) ...[
              Text('Overall Notes',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Add overall notes about this specification...',
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () => _updateValidation(
                          {'overall_notes': _notesController.text}),
                  child: const Text('Save Notes'),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Submit button
            if (_validation.status == 'in_progress')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submitValidation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Submit Validation'),
                ),
              ),

            // Read-only overall notes for submitted/accepted/rejected
            if (!_canEdit && _validation.overallNotes != null) ...[
              Text('Overall Notes',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_validation.overallNotes!),
                ),
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
