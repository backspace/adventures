import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/models/region.dart';

class EditRegionForm extends StatefulWidget {
  final Region? region;
  final Function(Region) onSave;
  final Dio dio;

  const EditRegionForm({
    Key? key,
    this.region,
    required this.onSave,
    required this.dio,
  }) : super(key: key);

  @override
  _EditRegionFormState createState() => _EditRegionFormState();
}

class _EditRegionFormState extends State<EditRegionForm> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.region?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.region?.description ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(labelText: 'Name'),
          ),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(labelText: 'Description'),
          ),
          ElevatedButton(
            onPressed: _saveRegion,
            child: Text('Save Region'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveRegion() async {
    try {
      final updatedRegion = Region(
        id: widget.region?.id ?? '',
        name: _nameController.text,
        description: _descriptionController.text,
      );

      if (widget.region == null) {
        // Create new region
        final response = await widget.dio.post(
          '/waydowntown/regions',
          data: {
            'data': {
              'type': 'regions',
              'attributes': {
                'name': updatedRegion.name,
                'description': updatedRegion.description,
              },
            },
          },
        );

        if (response.statusCode == 201) {
          final createdRegion = Region.fromJson(response.data['data'], []);
          widget.onSave(createdRegion);
        }
      } else {
        // Update existing region
        final response = await widget.dio.patch(
          '/waydowntown/regions/${updatedRegion.id}',
          data: {
            'data': {
              'type': 'regions',
              'id': updatedRegion.id,
              'attributes': {
                'name': updatedRegion.name,
                'description': updatedRegion.description,
              },
            },
          },
        );

        if (response.statusCode == 200) {
          final updatedRegion = Region.fromJson(response.data['data'], []);
          widget.onSave(updatedRegion);
        }
      }
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving region: ${e.message}')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
