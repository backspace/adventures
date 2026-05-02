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
  late List<String> _previousWrongAnswers;

  @override
  void initState() {
    super.initState();
    _attemptsRemaining = widget.puzzlet.attemptsRemaining;
    _previousWrongAnswers = List.of(widget.puzzlet.previousWrongAnswers);
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
        _previousWrongAnswers = List.of(outcome.previousWrongAnswers);
        _answerController.clear();
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
      AttemptAlreadyOwner() => 'Your team already owns this pole. Wait for a rival.',
      _ => null,
    };
  }

  Color? _outcomeColor() => switch (_outcome) {
        AttemptCorrect() => Colors.green.shade700,
        AttemptIncorrect() => Colors.orange.shade700,
        AttemptLockedOut() ||
        AttemptAlreadyCaptured() ||
        AttemptAlreadyOwner() =>
          Colors.red.shade700,
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
            _outcome is AttemptAlreadyOwner ||
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
            if (_previousWrongAnswers.isNotEmpty) ...[
              const SizedBox(height: 16),
              _PreviousWrongAnswers(answers: _previousWrongAnswers),
            ],
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

class _PreviousWrongAnswers extends StatelessWidget {
  final List<String> answers;
  const _PreviousWrongAnswers({required this.answers});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Already tried by your team:',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.onErrorContainer),
          ),
          const SizedBox(height: 6),
          ...answers.map(
            (a) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.close, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      a,
                      style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
