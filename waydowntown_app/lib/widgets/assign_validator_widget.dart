import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/app.dart';

class AssignValidatorWidget extends StatefulWidget {
  final Dio dio;

  const AssignValidatorWidget({super.key, required this.dio});

  @override
  State<AssignValidatorWidget> createState() => _AssignValidatorWidgetState();
}

class _AssignValidatorWidgetState extends State<AssignValidatorWidget> {
  List<Map<String, dynamic>> _specifications = [];
  List<Map<String, dynamic>> _validators = [];
  String? _selectedSpecificationId;
  String? _selectedValidatorId;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final specResponse =
          await widget.dio.get('/waydowntown/specifications');
      final validatorsResponse =
          await widget.dio.get('/waydowntown/validators');

      final specs = (specResponse.data['data'] as List<dynamic>)
          .map((s) => {
                'id': s['id'],
                'concept': s['attributes']['concept'],
                'start_description': s['attributes']['start_description'],
              })
          .toList();

      final validators = (validatorsResponse.data['data'] as List<dynamic>)
          .map((u) => {
                'id': u['id'],
                'name': u['attributes']?['name'] ??
                    u['attributes']?['email'] ??
                    u['id'],
              })
          .toList();

      setState(() {
        _specifications = specs;
        _validators = validators;
        _isLoading = false;
      });
    } catch (e) {
      talker.error('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _assignValidator() async {
    if (_selectedSpecificationId == null || _selectedValidatorId == null) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await widget.dio.post(
        '/waydowntown/specification-validations',
        data: {
          'data': {
            'type': 'specification-validations',
            'attributes': {},
            'relationships': {
              'specification': {
                'data': {
                  'type': 'specifications',
                  'id': _selectedSpecificationId,
                }
              },
              'validator': {
                'data': {
                  'type': 'users',
                  'id': _selectedValidatorId,
                }
              },
            },
          }
        },
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      talker.error('Error assigning validator: $e');
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
    return AlertDialog(
      title: const Text('Assign Validator'),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedSpecificationId,
                    decoration: const InputDecoration(
                        labelText: 'Specification'),
                    items: _specifications
                        .map((s) => DropdownMenuItem<String>(
                              value: s['id'],
                              child: Text(
                                '${s['concept']}${s['start_description'] != null ? ' - ${s['start_description']}' : ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedSpecificationId = v),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedValidatorId,
                    decoration:
                        const InputDecoration(labelText: 'Validator'),
                    items: _validators
                        .map((v) => DropdownMenuItem<String>(
                              value: v['id'],
                              child: Text(v['name']),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedValidatorId = v),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ||
                  _selectedSpecificationId == null ||
                  _selectedValidatorId == null
              ? null
              : _assignValidator,
          child: const Text('Assign'),
        ),
      ],
    );
  }
}
