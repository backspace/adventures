import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/app.dart';

class AssignValidatorRoute extends StatefulWidget {
  final Dio dio;
  final String specificationId;
  final String specificationLabel;

  const AssignValidatorRoute({
    super.key,
    required this.dio,
    required this.specificationId,
    required this.specificationLabel,
  });

  @override
  State<AssignValidatorRoute> createState() => _AssignValidatorRouteState();
}

class _AssignValidatorRouteState extends State<AssignValidatorRoute> {
  List<Map<String, dynamic>> _validators = [];
  String? _selectedValidatorId;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadValidators();
  }

  Future<void> _loadValidators() async {
    try {
      final response = await widget.dio.get('/waydowntown/validators');
      final validators = (response.data['data'] as List<dynamic>)
          .map((u) => {
                'id': u['id'],
                'name': u['attributes']?['name'] ??
                    u['attributes']?['email'] ??
                    u['id'],
                'email': u['attributes']?['email'] ?? '',
              })
          .toList();

      setState(() {
        _validators = validators;
        _isLoading = false;
      });
    } catch (e) {
      talker.error('Error loading validators: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _assignValidator() async {
    if (_selectedValidatorId == null) return;

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
                  'id': widget.specificationId,
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
      if (mounted) Navigator.of(context).pop(true);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Assign Validator')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Specification',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(widget.specificationLabel),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Validator',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  ..._validators.map((v) => RadioListTile<String>(
                        title: Text(v['name']),
                        subtitle: Text(v['email']),
                        value: v['id'],
                        groupValue: _selectedValidatorId,
                        onChanged: (val) =>
                            setState(() => _selectedValidatorId = val),
                      )),
                  if (_validators.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No validators available'),
                    ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving || _selectedValidatorId == null
                          ? null
                          : _assignValidator,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Assign'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
