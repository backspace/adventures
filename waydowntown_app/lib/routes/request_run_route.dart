import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:sentry/sentry.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/models/run.dart';
import 'package:waydowntown/routes/run_launch_route.dart';

class RequestRunRoute extends StatefulWidget {
  final Dio dio;
  final String? concept;
  final String? specificationId;
  final String? position;

  const RequestRunRoute({
    super.key,
    required this.dio,
    this.concept,
    this.specificationId,
    this.position,
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

  @override
  void initState() {
    super.initState();
    fetchRun();
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

      final response = await widget.dio.post(
        endpoint,
        data: {
          'data': {
            'type': 'runs',
            'attributes': {},
          },
        },
        queryParameters: queryParameters,
      );

      if (response.statusCode == 201) {
        setState(() {
          run = Run.fromJson(response.data);
        });
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
      logger.e('Error fetching run from $endpoint: $error');
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
      return RunLaunchRoute(run: run!, dio: widget.dio);
    }
  }
}
