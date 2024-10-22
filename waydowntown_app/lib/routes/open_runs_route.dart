import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/widgets/open_runs_table.dart';
import 'package:waydowntown/models/run.dart';

class OpenGamesRoute extends StatelessWidget {
  final Dio dio;

  const OpenGamesRoute({Key? key, required this.dio}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Games'),
      ),
      body: FutureBuilder<List<Run>>(
        future: _fetchOpenGames(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No open games available.'));
          } else {
            return OpenRunsTable(runs: snapshot.data!);
          }
        },
      ),
    );
  }

  Future<List<Run>> _fetchOpenGames() async {
    try {
      final response = await dio.get('/waydowntown/runs?filter[started]=false');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        return data
            .map((runJson) => Run.fromJson(
                {"data": runJson, "included": response.data['included']}))
            .toList();
      } else {
        throw Exception('Failed to load open games');
      }
    } catch (e) {
      throw Exception('Failed to load open games: $e');
    }
  }
}
