import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/models/region.dart';
import 'package:waydowntown/services/user_service.dart';
import 'package:waydowntown/widgets/edit_region_form.dart';

class RegionsTable extends StatelessWidget {
  final Dio dio;
  final List<Region> regions;
  final Function() onRefresh;

  const RegionsTable({
    super.key,
    required this.regions,
    required this.onRefresh,
    required this.dio,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Regions'),
      ),
      body: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Description')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _buildNestedRows(regions, context),
        ),
      ),
    );
  }

  List<DataRow> _buildNestedRows(List<Region> regions, BuildContext context,
      {String indent = ''}) {
    List<DataRow> rows = [];
    Region.sortAlphabetically(regions);

    for (var region in regions) {
      rows.add(DataRow(cells: [
        DataCell(Text('$indent${region.name}')),
        DataCell(Text(region.description ?? '')),
        DataCell(
          Row(
            children: [
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Edit Region'),
                        content: EditRegionForm(
                          region: region,
                          dio: dio,
                          onSave: (updatedRegion) {
                            Navigator.of(context).pop();
                            onRefresh();
                          },
                        ),
                      );
                    },
                  );
                },
                child: const Text('Edit'),
              ),
              const SizedBox(width: 8),
              FutureBuilder<bool>(
                future: _isUserAdmin(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data == true) {
                    return ElevatedButton(
                      onPressed: () => _showDeleteConfirmation(context, region),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Delete'),
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                },
              ),
            ],
          ),
        ),
      ]));

      if (region.children.isNotEmpty) {
        rows.addAll(
            _buildNestedRows(region.children, context, indent: '$indent  '));
      }
    }

    return rows;
  }

  Future<bool> _isUserAdmin() async {
    final isAdmin = await UserService.getUserIsAdmin();
    return isAdmin;
  }

  void _showDeleteConfirmation(BuildContext context, Region region) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete ${region.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteRegion(region);
                onRefresh();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteRegion(Region region) async {
    try {
      await dio.delete('/waydowntown/regions/${region.id}');
    } catch (e) {
      print('Error deleting region: $e');
    }
  }
}
