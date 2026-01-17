import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:phoenix_socket/phoenix_socket.dart';
import 'package:waydowntown/mixins/run_state_mixin.dart';
import 'package:waydowntown/models/run.dart';
import 'package:waydowntown/models/submission.dart';
import 'package:waydowntown/run_header.dart';
import 'package:waydowntown/services/user_service.dart';

abstract class StringDetector {
  Stream<String> get detectedStrings;
  void startDetecting();
  void stopDetecting();
  void dispose();
}

enum SubmissionState { unsubmitted, submitting, error, correct, incorrect }

class HintItem {
  final String hint;
  bool isMatched = false;
  DateTime receivedAt = DateTime.now();

  HintItem(this.hint);
}

class DetectedItem {
  final String value;
  SubmissionState state;
  String? errorMessage;
  DateTime submittedAt = DateTime.now();
  String? matchedHint;

  DetectedItem(
    this.value, {
    this.state = SubmissionState.unsubmitted,
    this.errorMessage,
    this.matchedHint,
  });
}

class CollectorGame extends StatefulWidget {
  final Dio dio;
  final Run run;
  final StringDetector detector;
  final PhoenixChannel channel;
  final bool autoSubmit;
  final Widget Function(BuildContext, StringDetector) inputBuilder;

  const CollectorGame({
    super.key,
    required this.dio,
    required this.run,
    required this.channel,
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
  List<HintItem> hints = [];
  bool isLoadingHint = false;
  Map<String, String> itemErrors = {};
  bool showIncorrectSubmissions = true;
  String? currentUserId;

  @override
  Dio get dio => widget.dio;

  @override
  Run get initialRun => widget.run;

  @override
  void initState() {
    super.initState();
    initializeChannel(widget.channel);
    WidgetsBinding.instance.addObserver(this);
    widget.detector.detectedStrings.listen(_onItemDetected);
    widget.detector.startDetecting();
    UserService.getUserId().then((id) {
      if (mounted) {
        setState(() {
          currentUserId = id;
        });
      }
    });
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

  Future<void> _requestHint() async {
    if (isLoadingHint) return;

    setState(() {
      isLoadingHint = true;
    });

    try {
      final answer = await requestHint(null);

      if (mounted && answer?.hint != null) {
        setState(() {
          _addHint(HintItem(answer?.hint ?? ''));
          isLoadingHint = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingHint = false;
        });
        _showErrorDialog('Error requesting hint', e.toString());
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
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

        if (isCorrect) {
          for (var hint in hints.toList()) {
            if (!hint.isMatched) {
              hint.isMatched = true;
              item.matchedHint = hint.hint;
              _removeHint(hint);
              break;
            }
          }
        }
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
      });
    }
  }

  void _addHint(HintItem hint) {
    if (mounted) {
      setState(() {
        hints.insert(0, hint);
      });
    }
  }

  void _removeHint(HintItem hint) {
    final index = hints.indexOf(hint);
    if (index != -1) {
      setState(() {
        hints.removeAt(index);
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

  Widget _buildItem(BuildContext context, DetectedItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(item.value),
          leading: _getIconForState(item.state, item.value),
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
              : null,
        ),
        if (item.state == SubmissionState.correct && item.matchedHint != null)
          Padding(
            padding:
                const EdgeInsets.only(left: 72.0, right: 16.0, bottom: 8.0),
            child: Text(
              item.matchedHint!,
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.blue,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHintTile(HintItem hint) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: Colors.blue.shade50,
      child: ListTile(
        leading: const Icon(
          Icons.lightbulb,
          color: Colors.blue,
        ),
        title: Text(
          hint.hint,
          style: const TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.blue,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmissionTile(Submission submission) {
    final state = submission.correct
        ? SubmissionState.correct
        : SubmissionState.incorrect;
    final isCurrentUser =
        currentUserId != null && submission.creatorId == currentUserId;

    return ListTile(
      title: Text(submission.submission),
      leading: _getIconForState(state, submission.submission),
      subtitle: currentUserId == null
          ? null
          : Text(isCurrentUser ? 'You' : 'Teammate'),
    );
  }

  List<Submission> _visibleTeamSubmissions() {
    return currentRun.submissions
        .where((submission) => showIncorrectSubmissions || submission.correct)
        .toList();
  }

  List<_TimelineItem> _buildTimelineItems(BuildContext context) {
    final items = <_TimelineItem>[];
    final teamSubmissions = _visibleTeamSubmissions();
    final visibleDetectedValues = detectedItems
        .where(
            (item) => showIncorrectSubmissions || item.state != SubmissionState.incorrect)
        .where((item) =>
            item.state == SubmissionState.correct ||
            item.state == SubmissionState.incorrect)
        .map((item) => item.value)
        .toSet();

    for (final hint in hints) {
      items.add(_TimelineItem(
        timestamp: hint.receivedAt,
        widget: _buildHintTile(hint),
      ));
    }

    for (final item in detectedItems) {
      if (!showIncorrectSubmissions && item.state == SubmissionState.incorrect) {
        continue;
      }

      items.add(_TimelineItem(
        timestamp: item.submittedAt,
        widget: _buildItem(context, item),
      ));
    }

    for (final submission in teamSubmissions) {
      if (visibleDetectedValues.contains(submission.submission)) {
        continue;
      }
      items.add(_TimelineItem(
        timestamp: submission.insertedAt,
        widget: _buildSubmissionTile(submission),
      ));
    }

    final insertionOrder = <_TimelineItem, int>{
      for (var i = 0; i < items.length; i++) items[i]: i,
    };

    items.sort((a, b) {
      final timeCompare = b.timestamp.compareTo(a.timestamp);
      if (timeCompare != 0) {
        return timeCompare;
      }
      return insertionOrder[b]!.compareTo(insertionOrder[a]!);
    });
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final timelineItems = _buildTimelineItems(context);

    final unrevealedHintsExist = widget.run.specification.answers
        ?.any((answer) => answer.hasHint && answer.hint == null);
    final showHintButton = !isGameComplete && unrevealedHintsExist == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.runtimeType.toString()),
        actions: [
          IconButton(
            icon: Icon(showIncorrectSubmissions
                ? Icons.visibility
                : Icons.visibility_off),
            tooltip: showIncorrectSubmissions
                ? 'Hide incorrect submissions'
                : 'Show incorrect submissions',
            onPressed: () {
              setState(() {
                showIncorrectSubmissions = !showIncorrectSubmissions;
              });
            },
          ),
          if (showHintButton)
            IconButton(
              icon: isLoadingHint
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lightbulb_outline),
              onPressed: _requestHint,
            ),
        ],
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
            child: timelineItems.isEmpty
                ? const Center(child: Text('No submissions yet.'))
                : ListView.builder(
                    itemCount: timelineItems.length,
                    itemBuilder: (context, index) {
                      return timelineItems[index].widget;
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

class _TimelineItem {
  final DateTime timestamp;
  final Widget widget;

  const _TimelineItem({required this.timestamp, required this.widget});
}
