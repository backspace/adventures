import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/models/specification_validation.dart';
import 'package:waydowntown/routes/validation_detail_route.dart';

class ValidatorAssignmentsRoute extends StatefulWidget {
  final Dio dio;

  const ValidatorAssignmentsRoute({super.key, required this.dio});

  @override
  State<ValidatorAssignmentsRoute> createState() =>
      _ValidatorAssignmentsRouteState();
}

class _ValidatorAssignmentsRouteState extends State<ValidatorAssignmentsRoute> {
  List<SpecificationValidation> _validations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAssignments();
  }

  Future<void> _fetchAssignments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await widget.dio
          .get('/waydowntown/specification-validations/mine');

      if (response.statusCode == 200) {
        final data = response.data['data'] as List<dynamic>;
        final included =
            (response.data['included'] as List<dynamic>?) ?? [];
        setState(() {
          _validations = data
              .map((json) =>
                  SpecificationValidation.fromJson(json, included))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      talker.error('Error fetching assignments: $e');
      setState(() {
        _error = 'Failed to load assignments';
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Validations')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _validations.isEmpty
                  ? const Center(child: Text('No assignments yet'))
                  : RefreshIndicator(
                      onRefresh: _fetchAssignments,
                      child: ListView.builder(
                        itemCount: _validations.length,
                        itemBuilder: (context, index) {
                          final validation = _validations[index];
                          final spec = validation.specification;
                          return ListTile(
                            title: Text(spec?.concept ?? 'Unknown'),
                            subtitle: Text(
                              spec?.startDescription ??
                                  spec?.taskDescription ??
                                  'No description',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Chip(
                              label: Text(
                                validation.status.replaceAll('_', ' '),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                              backgroundColor:
                                  _statusColor(validation.status),
                            ),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ValidationDetailRoute(
                                    dio: widget.dio,
                                    validation: validation,
                                  ),
                                ),
                              );
                              _fetchAssignments();
                            },
                          );
                        },
                      ),
                    ),
    );
  }
}
