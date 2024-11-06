import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/models/region.dart';
import 'package:waydowntown/models/specification.dart';
import 'package:waydowntown/widgets/edit_region_form.dart';
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
  late TextEditingController _notesController;
  String? _selectedConcept;
  String? _selectedRegionId;
  List<Region> _regions = [];
  Map<String, String> _fieldErrors = {};
  bool _sortByDistance = false;
  dynamic _concepts;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _startDescriptionController =
        TextEditingController(text: widget.specification.startDescription);
    _taskDescriptionController =
        TextEditingController(text: widget.specification.taskDescription);
    _durationController = TextEditingController(
        text: widget.specification.duration?.toString() ?? '');
    _notesController = TextEditingController(text: widget.specification.notes);
    _selectedConcept = widget.specification.concept;
    _selectedRegionId = widget.specification.region?.id;
    _loadRegions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_concepts == null) {
      _loadConcepts();
    }
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
    if (_sortByDistance) {
      _regions.sort((a, b) => (a.distance ?? double.infinity)
          .compareTo(b.distance ?? double.infinity));
    } else {
      Region.sortAlphabetically(_regions);
    }
  }

  Future<void> _loadConcepts() async {
    final yamlString =
        await DefaultAssetBundle.of(context).loadString('assets/concepts.yaml');
    final yamlMap = loadYaml(yamlString);
    if (mounted) {
      setState(() {
        _concepts = yamlMap;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
              _buildConceptDropdown(_concepts),
              _buildRegionSection(),
              _buildTextField('Start Description', _startDescriptionController,
                  'start_description'),
              _buildTextField('Task Description', _taskDescriptionController,
                  'task_description'),
              _buildTextField('Notes', _notesController, 'notes'),
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
              icon: const Icon(Icons.sort_by_alpha),
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
              icon: const Icon(Icons.near_me),
              isActive: _sortByDistance,
              onPressed: _loadNearestRegions,
            ),
            const SizedBox(width: 8),
            _buildSortButton(
              context: context,
              icon: const Icon(Icons.add),
              isActive: false,
              onPressed: _createNewRegion,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRegionDropdown() {
    return DropdownButtonFormField<String>(
      key: const Key('region-dropdown'),
      value: _selectedRegionId,
      decoration: InputDecoration(
        labelText: 'Region',
        errorText: _fieldErrors['region_id'],
      ),
      items: _buildNestedRegionEntries(_regions),
      onChanged: (String? newValue) {
        setState(() {
          _selectedRegionId = newValue;
        });
      },
      isExpanded: true,
    );
  }

  List<DropdownMenuItem<String>> _buildNestedRegionEntries(List<Region> regions,
      {String indent = ''}) {
    List<DropdownMenuItem<String>> entries = [];

    for (var region in regions) {
      entries.add(DropdownMenuItem<String>(
        value: region.id,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$indent${region.name}'),
            if (_sortByDistance && region.distance != null)
              Text(_formatDistance(region.distance!)),
          ],
        ),
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
              'notes': _notesController.text,
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
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create New Region'),
          content: EditRegionForm(
            region: null,
            dio: widget.dio,
            onSave: (newRegion) {
              setState(() {
                _regions.add(newRegion);
                _sortRegions();
                _selectedRegionId = newRegion.id;
              });
              Navigator.of(context).pop();
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _startDescriptionController.dispose();
    _taskDescriptionController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

Widget _buildSortButton({
  required BuildContext context,
  required Icon icon,
  required bool isActive,
  required VoidCallback onPressed,
}) {
  return IconButton(
    onPressed: onPressed,
    icon: icon,
    style: IconButton.styleFrom(
      backgroundColor: isActive ? Theme.of(context).primaryColor : null,
      foregroundColor: isActive ? Colors.white : null,
    ),
  );
}
