import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/models/answer.dart';
import 'package:waydowntown/models/region.dart';
import 'package:waydowntown/models/specification.dart';
import 'package:waydowntown/widgets/edit_region_form.dart';
import 'package:waydowntown/widgets/sensor_answer_registry.dart';
import 'package:waydowntown/widgets/sensor_answer_scanner.dart';
import 'package:yaml/yaml.dart';

class _AnswerEditState {
  final String? id;
  final int? order;
  final bool isNew;
  final TextEditingController answerController;
  final TextEditingController labelController;
  final TextEditingController hintController;
  final String _originalAnswer;
  final String _originalLabel;
  final String _originalHint;

  _AnswerEditState({
    this.id,
    this.order,
    this.isNew = true,
    required this.answerController,
    required this.labelController,
    required this.hintController,
    String originalAnswer = '',
    String originalLabel = '',
    String originalHint = '',
  })  : _originalAnswer = originalAnswer,
        _originalLabel = originalLabel,
        _originalHint = originalHint;

  factory _AnswerEditState.fromAnswer(Answer answer) {
    final answerText = answer.answer ?? '';
    final label = answer.label ?? '';
    final hint = answer.hint ?? '';
    return _AnswerEditState(
      id: answer.id,
      order: answer.order,
      isNew: false,
      answerController: TextEditingController(text: answerText),
      labelController: TextEditingController(text: label),
      hintController: TextEditingController(text: hint),
      originalAnswer: answerText,
      originalLabel: label,
      originalHint: hint,
    );
  }

  factory _AnswerEditState.empty() {
    return _AnswerEditState(
      answerController: TextEditingController(),
      labelController: TextEditingController(),
      hintController: TextEditingController(),
    );
  }

  bool get isDirty =>
      answerController.text != _originalAnswer ||
      labelController.text != _originalLabel ||
      hintController.text != _originalHint;

  void dispose() {
    answerController.dispose();
    labelController.dispose();
    hintController.dispose();
  }
}

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
  List<_AnswerEditState> _answers = [];
  final List<String> _deletedAnswerIds = [];

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
    _answers = (widget.specification.answers ?? [])
        .map((a) => _AnswerEditState.fromAnswer(a))
        .toList();
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
              _buildAnswersSection(),
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
              key: const Key('region-sort-alpha'),
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
              key: const Key('region-sort-nearest'),
              icon: const Icon(Icons.near_me),
              isActive: _sortByDistance,
              onPressed: _loadNearestRegions,
            ),
            const SizedBox(width: 8),
            _buildSortButton(
              context: context,
              key: const Key('region-sort-add'),
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

  Widget _buildAnswersSection() {
    final sensorConfig =
        SensorAnswerRegistry.configForConcept(_selectedConcept);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Answers',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Row(
              children: [
                if (sensorConfig != null)
                  IconButton(
                    key: const Key('scan-answers'),
                    onPressed: () => _openScanner(sensorConfig),
                    icon: Icon(sensorConfig.icon),
                  ),
                IconButton(
                  key: const Key('add-answer'),
                  onPressed: _addAnswer,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
        ..._answers.asMap().entries.map((entry) {
          final index = entry.key;
          final answer = entry.value;
          return _buildAnswerCard(answer, index);
        }),
      ],
    );
  }

  Widget _buildAnswerCard(_AnswerEditState answer, int index) {
    return Card(
      key: Key('answer-card-$index'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: Key('answer-text-$index'),
                    controller: answer.answerController,
                    decoration: const InputDecoration(
                      labelText: 'Answer',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  key: Key('delete-answer-$index'),
                  onPressed: () => _deleteAnswer(index),
                  icon: const Icon(Icons.delete),
                ),
              ],
            ),
            TextField(
              key: Key('answer-label-$index'),
              controller: answer.labelController,
              decoration: const InputDecoration(
                labelText: 'Label',
                isDense: true,
              ),
            ),
            TextField(
              key: Key('answer-hint-$index'),
              controller: answer.hintController,
              decoration: const InputDecoration(
                labelText: 'Hint',
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addAnswer() {
    setState(() {
      _answers.add(_AnswerEditState.empty());
    });
  }

  Future<void> _openScanner(SensorConfig config) async {
    final results = await Navigator.of(context).push<List<ScannedAnswer>>(
      MaterialPageRoute(
        builder: (context) => SensorAnswerScanner(
          detector: config.detectorFactory(),
          inputBuilder: config.inputBuilder,
          title: config.title,
        ),
      ),
    );

    if (results != null && results.isNotEmpty) {
      setState(() {
        for (final scanned in results) {
          final answer = _AnswerEditState.empty();
          answer.answerController.text = scanned.answer;
          if (scanned.hint != null) {
            answer.hintController.text = scanned.hint!;
          }
          _answers.add(answer);
        }
      });
    }
  }

  Future<void> _deleteAnswer(int index) async {
    final answer = _answers[index];
    if (!answer.isNew && answer.id != null) {
      try {
        await widget.dio.delete('/waydowntown/answers/${answer.id}');
      } catch (e) {
        talker.error('Error deleting answer: $e');
        return;
      }
      _deletedAnswerIds.add(answer.id!);
    }
    answer.dispose();
    setState(() {
      _answers.removeAt(index);
    });
  }

  Future<void> _saveAnswers() async {
    for (var i = 0; i < _answers.length; i++) {
      final answer = _answers[i];
      final answerText = answer.answerController.text;
      final label = answer.labelController.text;
      final hint = answer.hintController.text;

      if (answer.isNew) {
        await widget.dio.post(
          '/waydowntown/answers',
          data: {
            'data': {
              'type': 'answers',
              'attributes': {
                'answer': answerText,
                'label': label.isEmpty ? null : label,
                'hint': hint.isEmpty ? null : hint,
              },
              'relationships': {
                'specification': {
                  'data': {
                    'type': 'specifications',
                    'id': widget.specification.id,
                  },
                },
              },
            },
          },
        );
      } else if (answer.id != null && answer.isDirty) {
        await widget.dio.patch(
          '/waydowntown/answers/${answer.id}',
          data: {
            'data': {
              'type': 'answers',
              'id': answer.id,
              'attributes': {
                'answer': answerText,
                'label': label.isEmpty ? null : label,
                'hint': hint.isEmpty ? null : hint,
                'order': answer.order,
              },
            },
          },
        );
      }
    }
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

      if (response.statusCode == 200) {
        await _saveAnswers();
        if (mounted) {
          Navigator.of(context).pop(true);
        }
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
    for (final answer in _answers) {
      answer.dispose();
    }
    super.dispose();
  }
}

Widget _buildSortButton({
  required BuildContext context,
  Key? key,
  required Icon icon,
  required bool isActive,
  required VoidCallback onPressed,
}) {
  return IconButton(
    key: key,
    onPressed: onPressed,
    icon: icon,
    style: IconButton.styleFrom(
      backgroundColor: isActive ? Theme.of(context).primaryColor : null,
      foregroundColor: isActive ? Colors.white : null,
    ),
  );
}
