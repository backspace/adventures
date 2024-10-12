import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/models/region.dart';
import 'package:waydowntown/models/specification.dart';
import 'package:yaml/yaml.dart';

class EditSpecificationWidget extends StatefulWidget {
  final Dio dio;
  final Specification specification;

  const EditSpecificationWidget({
    super.key,
    required this.dio,
    required this.specification,
  });

  @override
  EditSpecificationWidgetState createState() => EditSpecificationWidgetState();
}

class EditSpecificationWidgetState extends State<EditSpecificationWidget> {
  late TextEditingController _startDescriptionController;
  late TextEditingController _taskDescriptionController;
  late TextEditingController _durationController;
  String? _selectedConcept;
  String? _selectedRegionId;
  List<Region> _regions = [];
  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _startDescriptionController =
        TextEditingController(text: widget.specification.startDescription);
    _taskDescriptionController =
        TextEditingController(text: widget.specification.taskDescription);
    _durationController = TextEditingController(
        text: widget.specification.duration?.toString() ?? '');
    _selectedConcept = widget.specification.concept;
    _selectedRegionId = widget.specification.region?.id;
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    try {
      final response = await widget.dio.get('/waydowntown/regions');
      if (response.statusCode == 200) {
        setState(() {
          _regions = Region.parseRegions(response.data);
        });
      }
    } catch (e) {
      talker.error('Error loading regions: $e');
    }
  }

  Future<dynamic> _loadConcepts(context) async {
    final yamlString =
        await DefaultAssetBundle.of(context).loadString('assets/concepts.yaml');
    final yamlMap = loadYaml(yamlString);
    return yamlMap;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
        future: _loadConcepts(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return Scaffold(
            appBar: AppBar(
              title: const Text('Edit Specification'),
            ),
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildConceptDropdown(snapshot.data),
                    _buildRegionDropdown(),
                    _buildTextField('Start Description',
                        _startDescriptionController, 'start_description'),
                    _buildTextField('Task Description',
                        _taskDescriptionController, 'task_description'),
                    _buildDurationField(),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: _saveSpecification,
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        });
  }

  Widget _buildConceptDropdown(dynamic concepts) {
    Map<String, String> conceptKeyToName = {};

    for (dynamic concept in concepts.keys) {
      conceptKeyToName[concept.toString()] =
          concepts[concept]['name'] ?? concept.toString();
    }

    return DropdownButtonFormField<String>(
      value: _selectedConcept,
      decoration: InputDecoration(
        labelText: 'Concept',
        errorText: _fieldErrors['concept'],
      ),
      items: conceptKeyToName.entries.map((entry) {
        return DropdownMenuItem<String>(
          value: entry.key,
          child: Text(entry.value),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedConcept = newValue;
        });
      },
    );
  }

  Widget _buildRegionDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedRegionId,
      decoration: InputDecoration(
        labelText: 'Region',
        errorText: _fieldErrors['region_id'],
      ),
      items: _buildRegionItems(_regions, 0),
      onChanged: (String? newValue) {
        setState(() {
          _selectedRegionId = newValue;
        });
      },
    );
  }

  List<DropdownMenuItem<String>> _buildRegionItems(
      List<Region> regions, int depth) {
    List<DropdownMenuItem<String>> items = [];
    for (var region in regions) {
      items.add(DropdownMenuItem<String>(
        value: region.id,
        child: Text('${'  ' * depth}${region.name}'),
      ));
      if (region.children.isNotEmpty) {
        items.addAll(_buildRegionItems(region.children, depth + 1));
      }
    }
    return items;
  }

  Widget _buildTextField(
      String label, TextEditingController controller, String fieldName) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        errorText: _fieldErrors[fieldName],
      ),
    );
  }

  Widget _buildDurationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _durationController,
          decoration: InputDecoration(
            labelText: 'Duration (seconds)',
            errorText: _fieldErrors['duration'],
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ElevatedButton(
              onPressed: () => _setDuration(30),
              child: const Text('30s'),
            ),
            ElevatedButton(
              onPressed: () => _setDuration(60),
              child: const Text('1m'),
            ),
            ElevatedButton(
              onPressed: () => _setDuration(120),
              child: const Text('2m'),
            ),
          ],
        ),
      ],
    );
  }

  void _setDuration(int seconds) {
    setState(() {
      _durationController.text = seconds.toString();
    });
  }

  Future<void> _saveSpecification() async {
    try {
      final response = await widget.dio.patch(
        '/waydowntown/specifications/${widget.specification.id}',
        data: {
          'data': {
            'type': 'specifications',
            'id': widget.specification.id,
            'attributes': {
              'concept': _selectedConcept,
              'start_description': _startDescriptionController.text,
              'task_description': _taskDescriptionController.text,
              'duration': int.tryParse(_durationController.text),
              'region_id': _selectedRegionId,
            },
          },
        },
      );

      if (response.statusCode == 200 && mounted) {
        Navigator.of(context).pop(true);
      }
    } on DioException catch (e) {
      talker.error('Error updating specification: $e');
      if (e.response?.statusCode == 422) {
        final errors = e.response?.data['errors'] as List<dynamic>;
        setState(() {
          _fieldErrors = {};

          for (var error in errors) {
            final field = error['source']['pointer'].split('/').last;
            _fieldErrors[field] = error['detail'];
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update specification')),
        );
      }
    }
  }

  @override
  void dispose() {
    _startDescriptionController.dispose();
    _taskDescriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }
}
