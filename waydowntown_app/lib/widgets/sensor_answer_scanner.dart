import 'dart:async';

import 'package:flutter/material.dart';
import 'package:waydowntown/games/collector_game.dart';

class ScannedAnswer {
  final String answer;
  final String? hint;

  const ScannedAnswer({required this.answer, this.hint});
}

class _DetectedEntry {
  final String value;
  bool included;
  final TextEditingController hintController;

  _DetectedEntry(this.value)
      : included = false,
        hintController = TextEditingController();

  void dispose() {
    hintController.dispose();
  }
}

class SensorAnswerScanner extends StatefulWidget {
  final StringDetector detector;
  final Widget Function(BuildContext, StringDetector) inputBuilder;
  final String title;

  const SensorAnswerScanner({
    super.key,
    required this.detector,
    required this.inputBuilder,
    required this.title,
  });

  @override
  State<SensorAnswerScanner> createState() => _SensorAnswerScannerState();
}

class _SensorAnswerScannerState extends State<SensorAnswerScanner> {
  final List<_DetectedEntry> _entries = [];
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.detector.detectedStrings.listen(_onDetected);
    widget.detector.startDetecting();
  }

  void _onDetected(String value) {
    if (!_entries.any((e) => e.value == value)) {
      setState(() {
        _entries.insert(0, _DetectedEntry(value));
      });
    }
  }

  List<ScannedAnswer> _buildResult() {
    return _entries
        .where((e) => e.included)
        .map((e) => ScannedAnswer(
              answer: e.value,
              hint: e.hintController.text.isEmpty
                  ? null
                  : e.hintController.text,
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            key: const Key('scanner-done'),
            onPressed: () => Navigator.pop(context, _buildResult()),
            child: const Text('Done'),
          ),
        ],
      ),
      body: Column(
        children: [
          widget.inputBuilder(context, widget.detector),
          Expanded(
            child: _entries.isEmpty
                ? const Center(child: Text('Scanning...'))
                : ListView.builder(
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      final entry = _entries[index];
                      return Card(
                        key: Key('scanned-item-$index'),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    key: Key('include-$index'),
                                    value: entry.included,
                                    onChanged: (value) {
                                      setState(() {
                                        entry.included = value ?? false;
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: Text(
                                      entry.value,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                              if (entry.included)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 48, right: 8, bottom: 8),
                                  child: TextField(
                                    key: Key('hint-$index'),
                                    controller: entry.hintController,
                                    decoration: const InputDecoration(
                                      labelText: 'Hint',
                                      isDense: true,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    widget.detector.dispose();
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }
}
