import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:phoenix_socket/phoenix_socket.dart';
import 'package:sentry/sentry.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/models/run.dart';
import 'package:waydowntown/routes/run_launch_route.dart';
import 'package:waydowntown/services/user_service.dart';
import 'package:yaml/yaml.dart';

class RequestRunRoute extends StatefulWidget {
  final Dio dio;
  final String? concept;
  final String? specificationId;
  final String? position;
  final PhoenixSocket? testSocket;

  const RequestRunRoute({
    super.key,
    required this.dio,
    this.concept,
    this.specificationId,
    this.position,
    this.testSocket,
  });

  @override
  RequestRunRouteState createState() => RequestRunRouteState();
}

class RequestRunRouteState extends State<RequestRunRoute> {
  String answer = 'submission';
  Run? run;
  bool hasAnsweredIncorrectly = false;
  bool isOver = false;
  bool isRequestError = false;
  TextEditingController textFieldController = TextEditingController();
  bool _didFetch = false;
  bool? _isLongRunning;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didFetch) {
      _didFetch = true;
      fetchRun();
    }
  }

  Future<void> fetchRun() async {
    const endpoint = '/waydowntown/runs';
    try {
      final queryParameters = <String, String>{};
      if (widget.concept != null) {
        queryParameters['filter[specification.concept]'] = widget.concept!;
      }
      if (widget.specificationId != null) {
        queryParameters['filter[specification.id]'] = widget.specificationId!;
      }
      if (widget.position != null) {
        queryParameters['filter[specification.position]'] = widget.position!;
      }

      Run? existingRun;
      if (await _isLongRunningConcept()) {
        existingRun = await _fetchExistingRunForConcept();
      }

      if (!mounted) {
        return;
      }

      if (existingRun != null) {
        setState(() {
          run = existingRun;
        });
        return;
      }

      final response = await widget.dio.post(endpoint,
          data: {
            'data': {
              'type': 'runs',
              'attributes': {},
            },
          },
          queryParameters: queryParameters);

      if (response.statusCode == 201) {
        print('RequestRunRoute: POST returned 201, parsing run...');
        try {
          final parsedRun = Run.fromJson(response.data);
          print('RequestRunRoute: Run parsed successfully, id=${parsedRun.id}, concept=${parsedRun.specification.concept}');
          setState(() {
            run = parsedRun;
          });
        } catch (parseError) {
          print('RequestRunRoute: Run.fromJson FAILED: $parseError');
          rethrow;
        }
      } else {
        throw Exception('Failed to load run');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          Sentry.captureException(error);
          isRequestError = true;
        });
      }
      print('RequestRunRoute: ERROR fetching/parsing run: $error');
      talker.error('Error fetching run from $endpoint: $error');
    }
  }

  Future<bool> _isLongRunningConcept() async {
    if (_isLongRunning != null) {
      return _isLongRunning!;
    }

    if (widget.concept == null) {
      _isLongRunning = false;
      return false;
    }

    try {
      final yamlString = await DefaultAssetBundle.of(context)
          .loadString('assets/concepts.yaml');
      final yamlMap = loadYaml(yamlString);
      final conceptInfo = yamlMap[widget.concept];
      _isLongRunning =
          conceptInfo is YamlMap && conceptInfo['long_running'] == true;
      return _isLongRunning!;
    } catch (error) {
      talker.error('Error loading concepts.yaml: $error');
      _isLongRunning = false;
      return false;
    }
  }

  Future<Run?> _fetchExistingRunForConcept() async {
    if (widget.concept == null) {
      return null;
    }

    const endpoint = '/waydowntown/runs';
    try {
      final response = await widget.dio.get(
          '$endpoint?filter[started]=true&filter[specification.concept]=${widget.concept}');

      if (response.statusCode != 200) {
        return null;
      }

      final data = response.data['data'];
      if (data is! List || data.isEmpty) {
        return null;
      }

      final included = response.data['included'] ?? [];
      final runs = data
          .map((runJson) => Run.fromJson(
              {"data": runJson, "included": included}))
          .toList();

      final currentUserId = await UserService.getUserId();
      final candidateRuns = currentUserId == null
          ? runs
          : runs
              .where((run) =>
                  run.participations.any((p) => p.userId == currentUserId))
              .toList();

      final activeRuns =
          candidateRuns.where((run) => !run.isComplete).toList();
      final runsToConsider = activeRuns.isNotEmpty ? activeRuns : candidateRuns;

      runsToConsider.sort((a, b) {
        final aStarted = a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bStarted = b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bStarted.compareTo(aStarted);
      });

      return runsToConsider.isNotEmpty ? runsToConsider.first : null;
    } catch (error) {
      talker.error('Error fetching existing run from $endpoint: $error');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isRequestError) {
      return Scaffold(
          appBar: AppBar(title: const Text('Game')),
          body: const Center(child: Text('Error fetching game')));
    } else if (run == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Game')),
          body: const Center(child: CircularProgressIndicator()));
    } else {
      return RunLaunchRoute(
        run: run!,
        dio: widget.dio,
        testSocket: widget.testSocket,
      );
    }
  }
}
