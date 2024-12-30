import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:phoenix_socket/phoenix_socket.dart';
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

  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

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
        _listKey.currentState
            ?.insertItem(0, duration: const Duration(milliseconds: 300));
      });
    }
  }

  void _addHint(HintItem hint) {
    if (mounted) {
      setState(() {
        hints.insert(0, hint);
        _listKey.currentState
            ?.insertItem(0, duration: const Duration(milliseconds: 300));
      });
    }
  }

  void _removeHint(HintItem hint) {
    final index = hints.indexOf(hint);
    if (index != -1) {
      final removedHint = hints[index];
      _listKey.currentState?.removeItem(
        index,
        (context, animation) => _buildHintTile(removedHint, animation),
        duration: const Duration(milliseconds: 300),
      );
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

  Widget _buildItem(
      BuildContext context, DetectedItem item, Animation<double> animation) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
      )),
      child: Column(
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
      ),
    );
  }

  Widget _buildHintTile(HintItem hint, [Animation<double>? animation]) {
    Widget tile = Card(
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

    if (animation != null) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        )),
        child: tile,
      );
    }

    return tile;
  }

  Widget _buildListItem(
      BuildContext context, int index, Animation<double> animation) {
    final allItems = [
      ...hints.map((hint) => MapEntry(hint.receivedAt,
          (Animation<double> anim) => _buildHintTile(hint, anim))),
      ...detectedItems.map((item) => MapEntry(item.submittedAt,
          (Animation<double> anim) => _buildItem(context, item, anim))),
    ]..sort((a, b) => b.key.compareTo(a.key));

    return allItems[index].value(animation);
  }

  @override
  Widget build(BuildContext context) {
    final int totalItems = detectedItems.length + hints.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.runtimeType.toString()),
        actions: [
          if (!isGameComplete)
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
            child: AnimatedList(
              key: _listKey,
              initialItemCount: totalItems,
              itemBuilder: (context, index, animation) {
                return _buildListItem(context, index, animation);
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
