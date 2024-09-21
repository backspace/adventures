import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/mixins/run_state_mixin.dart';
import 'package:waydowntown/models/run.dart';
import 'package:waydowntown/run_header.dart';

abstract class StringDetector {
  Stream<String> get detectedStrings;
  void startDetecting();
  void stopDetecting();
  void dispose();
}

enum SubmissionState { unsubmitted, submitting, error, correct, incorrect }

class DetectedItem {
  final String value;
  SubmissionState state;

  DetectedItem(this.value, {this.state = SubmissionState.unsubmitted});
}

class CollectorGame extends StatefulWidget {
  final Dio dio;
  final Run run;
  final StringDetector detector;
  final bool autoSubmit;
  final Widget Function(BuildContext, StringDetector) inputBuilder;

  const CollectorGame({
    super.key,
    required this.dio,
    required this.run,
    required this.detector,
    required this.inputBuilder,
    this.autoSubmit = false,
  });

  @override
  CollectorGameState createState() => CollectorGameState();
}

class CollectorGameState extends State<CollectorGame>
    with WidgetsBindingObserver, RunStateMixin<CollectorGame> {
  List<DetectedItem> detectedItems = [];
  Map<String, String> itemErrors = {};

  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  @override
  Dio get dio => widget.dio;

  @override
  Run get initialRun => widget.run;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.detector.detectedStrings.listen(_onItemDetected);
    widget.detector.startDetecting();
  }

  void _onItemDetected(String value) {
    if (!detectedItems.any((item) => item.value == value)) {
      final newItem = DetectedItem(value);
      _addItem(newItem);
      if (widget.autoSubmit) {
        submitItem(newItem);
      }
    }
  }

  Future<void> submitItem(DetectedItem item) async {
    if (!mounted) return;

    setState(() {
      item.state = SubmissionState.submitting;
    });

    try {
      final bool isCorrect = await submitSubmission(item.value);

      if (!mounted) return;

      setState(() {
        item.state =
            isCorrect ? SubmissionState.correct : SubmissionState.incorrect;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        item.state = SubmissionState.error;
        itemErrors[item.value] = e.toString();
      });
    }
  }

  void _addItem(DetectedItem item) {
    if (mounted) {
      setState(() {
        detectedItems.insert(0, item);
        _listKey.currentState?.insertItem(0);
      });
    }
  }

  Widget _getIconForState(SubmissionState state, String value) {
    switch (state) {
      case SubmissionState.submitting:
        return const Icon(Icons.hourglass_empty,
            color: Colors.blue, size: 24.0);
      case SubmissionState.error:
        return IconButton(
          icon: const Icon(Icons.info, color: Colors.red, size: 24.0),
          onPressed: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Error'),
                  content: Text(itemErrors[value] ?? 'Unknown error'),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('Close'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                );
              },
            );
          },
        );
      case SubmissionState.correct:
        return const Icon(Icons.check_circle, color: Colors.green, size: 24.0);
      case SubmissionState.incorrect:
        return const Icon(Icons.cancel, color: Colors.orange, size: 24.0);
      default:
        return const Icon(Icons.radio_button_unchecked,
            color: Colors.grey, size: 24.0);
    }
  }

  Widget _buildItem(
      BuildContext context, int index, Animation<double> animation) {
    DetectedItem item = detectedItems[index];
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
      )),
      child: ListTile(
          title: Text(item.value),
          leading: _getIconForState(item.state, item.value),
          // FIXME should there be a submit button? Previously just tapping the row was the way
          trailing:
              !widget.autoSubmit && item.state == SubmissionState.unsubmitted
                  ? ElevatedButton(
                      onPressed: () => submitItem(item),
                      child: const Text('Submit'),
                    )
                  : null,
          onTap: item.state == SubmissionState.unsubmitted ||
                  item.state == SubmissionState.error
              ? () => submitItem(item)
              : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.runtimeType.toString()),
      ),
      body: Column(
        children: [
          RunHeader(run: currentRun),
          if (isGameComplete)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Congratulations! You have completed the game.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            )
          else
            widget.inputBuilder(context, widget.detector),
          Expanded(
            child: AnimatedList(
              key: _listKey,
              initialItemCount: detectedItems.length,
              itemBuilder: (context, index, animation) {
                return _buildItem(context, index, animation);
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        widget.detector.startDetecting();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        widget.detector.stopDetecting();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.detector.dispose();
    super.dispose();
  }
}
