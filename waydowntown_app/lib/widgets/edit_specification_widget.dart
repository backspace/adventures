import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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
  bool _sortByDistance = false;

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
          _sortRegions();
        });
      }
    } catch (e) {
      talker.error('Error loading regions: $e');
    }
  }

  Future<void> _loadNearestRegions() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      final response = await widget.dio.get(
          '/waydowntown/regions?filter[position]=${position.latitude},${position.longitude}');
      if (response.statusCode == 200) {
        setState(() {
          _regions = Region.parseRegions(response.data);
          _sortByDistance = true;
          _sortRegions();
        });
      }
    } catch (e) {
      talker.error('Error loading nearest regions: $e');
    }
  }

  void _sortRegions() {
    _sortRegionList(_regions);
  }

  void _sortRegionList(List<Region> regions) {
    if (_sortByDistance) {
      regions.sort((a, b) => (a.distance ?? double.infinity)
          .compareTo(b.distance ?? double.infinity));
    } else {
      regions
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    for (var region in regions) {
      if (region.children.isNotEmpty) {
        _sortRegionList(region.children);
      }
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
                    _buildRegionSection(),
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

  Widget _buildRegionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildRegionDropdown(),
            ),
            const SizedBox(width: 8),
            _buildSortButton(
              context: context,
              label: 'A-Z',
              isActive: !_sortByDistance,
              onPressed: () {
                setState(() {
                  _sortByDistance = false;
                  _sortRegions();
                });
              },
            ),
            const SizedBox(width: 8),
            _buildSortButton(
              context: context,
              label: 'Nearest',
              isActive: _sortByDistance,
              onPressed: _loadNearestRegions,
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _createNewRegion,
              child: const Text('New'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRegionDropdown() {
    return DropdownMenu<String>(
      initialSelection: _selectedRegionId,
      onSelected: (String? newValue) {
        setState(() {
          _selectedRegionId = newValue;
        });
      },
      errorText: _fieldErrors['region_id'],
      label: const Text('Region'),
      dropdownMenuEntries: _buildNestedRegionEntries(_regions),
      width: MediaQuery.of(context).size.width - 150,
    );
  }

  List<DropdownMenuEntry<String>> _buildNestedRegionEntries(
      List<Region> regions,
      {String indent = ''}) {
    List<DropdownMenuEntry<String>> entries = [];

    for (var region in regions) {
      entries.add(DropdownMenuEntry<String>(
        value: region.id,
        label: '$indent${region.name}',
        trailingIcon: _sortByDistance && region.distance != null
            ? Text(_formatDistance(region.distance!))
            : null,
      ));

      if (region.children.isNotEmpty) {
        entries.addAll(
            _buildNestedRegionEntries(region.children, indent: '$indent  '));
      }
    }

    return entries;
  }

  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters >= 1000) {
      return '${(distanceInMeters / 1000).round()} km';
    } else {
      return '${distanceInMeters.round()} m';
    }
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

  Future<void> _createNewRegion() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create New Region'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final response = await widget.dio.post(
                    '/waydowntown/regions',
                    data: {
                      'data': {
                        'type': 'regions',
                        'attributes': {
                          'name': nameController.text,
                          'description': descriptionController.text,
                        },
                      },
                    },
                  );

                  if (response.statusCode == 201) {
                    final newRegion =
                        Region.fromJson(response.data['data'], []);
                    setState(() {
                      _regions.add(newRegion);
                      _sortRegions();
                      _selectedRegionId = newRegion.id;
                    });
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  talker.error('Error creating new region: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Failed to create new region')),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _startDescriptionController.dispose();
    _taskDescriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }
}

Widget _buildSortButton({
  required BuildContext context,
  required String label,
  required bool isActive,
  required VoidCallback onPressed,
}) {
  return ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: isActive ? Theme.of(context).primaryColor : null,
      foregroundColor: isActive ? Colors.white : null,
    ),
    child: Text(label),
  );
}
