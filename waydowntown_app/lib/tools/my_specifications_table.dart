import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/models/specification.dart';
import 'package:waydowntown/routes/request_run_route.dart';
import 'package:waydowntown/widgets/edit_specification_widget.dart';

class MySpecificationsTable extends StatefulWidget {
  final Dio dio;

  const MySpecificationsTable({super.key, required this.dio});

  @override
  _MySpecificationsTableState createState() => _MySpecificationsTableState();
}

enum GroupBy { region, concept }

class _MySpecificationsTableState extends State<MySpecificationsTable> {
  List<Specification> specifications = [];
  bool isLoading = true;
  bool isRequestError = false;
  GroupBy _groupBy = GroupBy.region;

  @override
  void initState() {
    super.initState();
    fetchMySpecifications();
  }

  Future<void> fetchMySpecifications() async {
    const endpoint = '/waydowntown/specifications/mine';
    if (mounted) {
      setState(() {
        isLoading = true;
        isRequestError = false;
      });
    }
    try {
      final response = await widget.dio.get(
        endpoint,
      );

      if (!mounted) {
        return;
      }

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        final List<dynamic> included = response.data['included'];
        setState(() {
          specifications = data
              .map((json) => Specification.fromJson(json, included))
              .toList();
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load specifications');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          isRequestError = true;
          isLoading = false;
        });
      }
      talker.error('Error fetching specifications from $endpoint: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Specifications'),
        actions: [
          ToggleButtons(
            key: const Key('group-by-toggle'),
            isSelected: [
              _groupBy == GroupBy.region,
              _groupBy == GroupBy.concept,
            ],
            onPressed: (index) {
              setState(() {
                _groupBy = index == 0 ? GroupBy.region : GroupBy.concept;
              });
            },
            children: const [
              Padding(
                key: Key('group-by-region'),
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Region'),
              ),
              Padding(
                key: Key('group-by-concept'),
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Concept'),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Builder(
        builder: (BuildContext context) {
          if (isRequestError) {
            return const Center(child: Text('Error fetching specifications'));
          } else if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          } else {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: Theme(
                  data: Theme.of(context).copyWith(),
                  child: DataTable(
                    columns: [
                      DataColumn(
                          label: Text(_groupBy == GroupBy.region
                              ? 'Concept'
                              : 'Region')),
                      const DataColumn(label: Text('Answers')),
                      const DataColumn(label: Text('Start')),
                      const DataColumn(label: Text('Task')),
                      const DataColumn(label: Text('')),
                    ],
                    rows: _buildTableRows(),
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  List<DataRow> _buildTableRows() {
    Map<String, List<Specification>> groupedSpecs = {};
    for (var spec in specifications) {
      String groupKey = _groupBy == GroupBy.region
          ? (spec.region?.name ?? 'Unknown')
          : spec.concept;
      if (!groupedSpecs.containsKey(groupKey)) {
        groupedSpecs[groupKey] = [];
      }
      groupedSpecs[groupKey]!.add(spec);
    }

    List<DataRow> rows = [];
    final sortedKeys = groupedSpecs.keys.toList()..sort();
    for (final groupKey in sortedKeys) {
      final specs = groupedSpecs[groupKey]!;
      if (_groupBy == GroupBy.concept) {
        specs.sort((a, b) => (a.region?.name ?? 'Unknown')
            .compareTo(b.region?.name ?? 'Unknown'));
      } else {
        specs.sort((a, b) => a.concept.compareTo(b.concept));
      }
    }
    for (final groupKey in sortedKeys) {
      final specs = groupedSpecs[groupKey]!;
      rows.add(DataRow(
        cells: [
          DataCell(
            Container(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Text(
                groupKey,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const DataCell(Text('')),
          const DataCell(Text('')),
          const DataCell(Text('')),
          const DataCell(Text('')),
        ],
      ));
      rows.addAll(specs.map((spec) => DataRow(
            cells: [
              DataCell(Text(_groupBy == GroupBy.region
                  ? spec.concept
                  : (spec.region?.name ?? 'Unknown'))),
              DataCell(Text(spec.answers?.length.toString() ?? '0')),
              DataCell(_truncatedText(spec.startDescription)),
              DataCell(_truncatedText(spec.taskDescription)),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => RequestRunRoute(
                          dio: widget.dio,
                          specificationId: spec.id,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow),
                  ),
                  IconButton(
                    onPressed: () async {
                      final didUpdate =
                          await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (context) => EditSpecificationWidget(
                            dio: widget.dio,
                            specification: spec,
                          ),
                        ),
                      );

                      if (!mounted) {
                        return;
                      }

                      if (didUpdate == true) {
                        await fetchMySpecifications();
                      }
                    },
                    icon: const Icon(Icons.edit),
                  ),
                ],
              )),
            ],
          )));
    }

    return rows;
  }

  Widget _truncatedText(String? text) {
    if (text == null || text.isEmpty) {
      return const Text('');
    }

    String displayText =
        text.length > 30 ? '${text.substring(0, 30)}...' : text;

    return GestureDetector(
      onTap: () => _showFullText(text),
      child: Text(displayText),
    );
  }

  void _showFullText(String text) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
