import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/models/region.dart';
import 'package:waydowntown/widgets/edit_region_form.dart';

class RegionsTable extends StatelessWidget {
  final Dio dio;
  final List<Region> regions;
  final Function() onRefresh;

  const RegionsTable({
    Key? key,
    required this.regions,
    required this.onRefresh,
    required this.dio,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Regions'),
      ),
      body: SingleChildScrollView(
        child: DataTable(
          columns: [
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
          ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Edit Region'),
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
            child: Text('Edit'),
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
}
