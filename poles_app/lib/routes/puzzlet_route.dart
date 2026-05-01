import 'package:flutter/material.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/pole.dart';

class PuzzletRoute extends StatefulWidget {
  final PolesApi api;
  final Pole pole;
  final Puzzlet puzzlet;

  const PuzzletRoute({
    super.key,
    required this.api,
    required this.pole,
    required this.puzzlet,
  });

  @override
  State<PuzzletRoute> createState() => _PuzzletRouteState();
}

class _PuzzletRouteState extends State<PuzzletRoute> {
  final _answerController = TextEditingController();
  bool _busy = false;
  int? _attemptsRemaining;
  AttemptOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    _attemptsRemaining = widget.puzzlet.attemptsRemaining;
  }

  Future<void> _submit() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) return;

    setState(() => _busy = true);

    final outcome = await widget.api.submitAnswer(widget.puzzlet.id, answer);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _outcome = outcome;
      if (outcome is AttemptIncorrect) {
        _attemptsRemaining = outcome.attemptsRemaining;
      } else if (outcome is AttemptLockedOut) {
        _attemptsRemaining = 0;
      }
    });
  }

  String? _outcomeText() {
    final o = _outcome;
    return switch (o) {
      AttemptCorrect() => o.poleLocked
          ? 'Correct! Pole captured and now fully locked.'
          : 'Correct! Pole captured.',
      AttemptIncorrect() => 'Incorrect. ${o.attemptsRemaining} attempt(s) left.',
      AttemptLockedOut() => 'Locked out — too many wrong answers.',
      AttemptAlreadyCaptured() => 'Another team captured this puzzlet first.',
      _ => null,
    };
  }

  Color? _outcomeColor() => switch (_outcome) {
        AttemptCorrect() => Colors.green.shade700,
        AttemptIncorrect() => Colors.orange.shade700,
        AttemptLockedOut() || AttemptAlreadyCaptured() => Colors.red.shade700,
        _ => null,
      };

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled =
        _outcome is AttemptCorrect ||
            _outcome is AttemptLockedOut ||
            _outcome is AttemptAlreadyCaptured ||
            (_attemptsRemaining ?? 0) <= 0;

    final outcomeText = _outcomeText();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pole.label ?? widget.pole.barcode),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.puzzlet.instructions,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text('Difficulty: ${widget.puzzlet.difficulty}'),
            Text('Attempts remaining: ${_attemptsRemaining ?? 0}'),
            const SizedBox(height: 24),
            TextField(
              controller: _answerController,
              enabled: !disabled,
              decoration: const InputDecoration(
                labelText: 'Answer',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => disabled ? null : _submit(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: (_busy || disabled) ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
            if (outcomeText != null) ...[
              const SizedBox(height: 24),
              Text(outcomeText, style: TextStyle(color: _outcomeColor(), fontSize: 16)),
            ],
          ],
        ),
      ),
    );
  }
}
