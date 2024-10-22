import 'package:flutter/material.dart';
import 'package:waydowntown/models/run.dart';

class OpenRunsTable extends StatelessWidget {
  final List<Run> runs;

  const OpenRunsTable({Key? key, required this.runs}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Concept')),
            DataColumn(label: Text('Region')),
            DataColumn(label: Text('')),
          ],
          rows: runs.map((run) {
            return DataRow(
              cells: [
                DataCell(Text(run.specification.concept)),
                DataCell(Text(run.specification.region?.name ?? 'N/A')),
                DataCell(
                  ElevatedButton(
                    child: const Text('Join'),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text('Unimplemented, would join ${run.id}')),
                      );
                    },
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
