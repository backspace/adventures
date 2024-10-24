import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/models/run.dart';
import 'package:waydowntown/routes/run_launch_route.dart';

class OpenRunsTable extends StatelessWidget {
  final List<Run> runs;
  final Dio dio;

  const OpenRunsTable({Key? key, required this.runs, required this.dio})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Concept')),
          DataColumn(label: Text('Region')),
          DataColumn(label: Text('Action')),
        ],
        rows: runs.map((run) {
          return DataRow(
            cells: [
              DataCell(Text(run.specification.concept)),
              DataCell(Text(run.specification.region?.name ?? 'N/A')),
              DataCell(
                ElevatedButton(
                  child: const Text('Join'),
                  onPressed: () async {
                    try {
                      final response =
                          await dio.post('/waydowntown/participations', data: {
                        'data': {
                          'type': 'participation',
                          'relationships': {
                            'run': {
                              'data': {'type': 'run', 'id': run.id}
                            }
                          }
                        }
                      });
                      if (response.statusCode == 201) {
                        final updatedRunResponse =
                            await dio.get('/waydowntown/runs/${run.id}');
                        if (updatedRunResponse.statusCode == 200) {
                          final updatedRun = Run.fromJson({
                            "data": updatedRunResponse.data['data'],
                            "included": updatedRunResponse.data['included']
                          });

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  RunLaunchRoute(run: updatedRun, dio: dio),
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error joining run: $e')),
                      );
                    }
                  },
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
