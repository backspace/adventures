import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/models/specification.dart';

class MySpecificationsTable extends StatefulWidget {
  final Dio dio;

  const MySpecificationsTable({Key? key, required this.dio}) : super(key: key);

  @override
  _MySpecificationsTableState createState() => _MySpecificationsTableState();
}

class _MySpecificationsTableState extends State<MySpecificationsTable> {
  List<Specification> specifications = [];
  bool isLoading = true;
  bool isRequestError = false;

  @override
  void initState() {
    super.initState();
    fetchMySpecifications();
  }

  Future<void> fetchMySpecifications() async {
    const endpoint = '/waydowntown/specifications/mine';
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('access_token');

      if (authToken == null) {
        throw Exception('Auth token not found');
      }

      final response = await widget.dio.get(
        endpoint,
        options: Options(
          headers: {'Authorization': authToken},
        ),
      );

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
    if (isRequestError) {
      return const Center(child: Text('Error fetching specifications'));
    } else if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Specifications'),
        ),
        body: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: Theme(
              data: Theme.of(context).copyWith(),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Concept')),
                  DataColumn(label: Text('Start Description')),
                ],
                rows: _buildTableRows(),
              ),
            ),
          ),
        ),
      );
    }
  }

  List<DataRow> _buildTableRows() {
    Map<String, List<Specification>> groupedSpecs = {};
    for (var spec in specifications) {
      String regionName = spec.region?.name ?? 'Unknown';
      if (!groupedSpecs.containsKey(regionName)) {
        groupedSpecs[regionName] = [];
      }
      groupedSpecs[regionName]!.add(spec);
    }

    List<DataRow> rows = [];
    groupedSpecs.forEach((regionName, specs) {
      rows.add(DataRow(
        cells: [
          DataCell(
            Container(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Text(
                regionName,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          DataCell(Text('')),
        ],
      ));
      rows.addAll(specs.map((spec) => DataRow(
            cells: [
              DataCell(Text(spec.concept)),
              DataCell(_truncatedText(spec.start)),
            ],
          )));
    });

    return rows;
  }

  Widget _truncatedText(String? text) {
    if (text == null || text.isEmpty) {
      return const Text('N/A');
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
