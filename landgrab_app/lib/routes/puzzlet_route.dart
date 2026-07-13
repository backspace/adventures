import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/l10n/player_strings.dart';
import 'package:landgrab/models/pole.dart';
import 'package:landgrab/routes/barcode_scanner_route.dart';
import 'package:landgrab/routes/nfc_scanner_route.dart';

class PuzzletRoute extends StatefulWidget {
  final LandgrabApi api;
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
  // How long the confetti burst plays before we auto-pop back to the
  // map, where the territory-capture animation takes over.
  static const _celebrationDuration = Duration(milliseconds: 1600);

  final _answerController = TextEditingController();
  late final ConfettiController _confetti =
      ConfettiController(duration: _celebrationDuration);
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

  /// Correct answer: no text — celebrate with a confetti burst, then
  /// pop back (with `true` so the scanner can tell the map which pole
  /// to animate). maybePop rather than pop so a bare test harness
  /// with a single route doesn't underflow the navigator.
  void _celebrateAndPop() {
    _confetti.play();
    Future.delayed(_celebrationDuration, () {
      if (mounted) Navigator.of(context).maybePop(true);
    });
  }

  Future<void> _submit({String? override}) async {
    final raw = override ?? _answerController.text;
    final isStrict = widget.puzzlet.answerType == 'strict_text' ||
        widget.puzzlet.answerType == 'barcode' ||
        widget.puzzlet.answerType == 'nfc';
    final answer = isStrict ? raw : raw.trim();
    if (answer.isEmpty) return;

    setState(() => _busy = true);

    // submitAnswer maps every failure it understands (and, as of the
    // AttemptFailed catch-all, every one it doesn't) to an outcome
    // rather than throwing — but guard with try/finally anyway so no
    // future exception can strand the screen with _busy stuck true.
    try {
      final outcome =
          await widget.api.submitAnswer(widget.puzzlet.id, answer);

      if (!mounted) return;
      setState(() {
        _outcome = outcome;
        if (outcome is AttemptIncorrect) {
          _attemptsRemaining = outcome.attemptsRemaining;
          _previousWrongAnswers = List.of(outcome.previousWrongAnswers);
          _answerController.clear();
        } else if (outcome is AttemptLockedOut) {
          _attemptsRemaining = 0;
        }
      });
      if (outcome is AttemptCorrect) _celebrateAndPop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _outcome = AttemptFailed(e.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _outcomeText() {
    final o = _outcome;
    return switch (o) {
      // AttemptCorrect deliberately renders no text — the confetti
      // burst plus the return-to-map territory animation carry the
      // success feedback.
      AttemptCorrect() => null,
      AttemptIncorrect() => PuzzletStrings.incorrect(o.attemptsRemaining),
      AttemptLockedOut() => PuzzletStrings.lockedOut,
      AttemptAlreadyCaptured() => PuzzletStrings.alreadyCapturedByOther,
      AttemptAlreadyOwner() => PuzzletStrings.alreadyOwner,
      AttemptFailed() => o.message,
      _ => null,
    };
  }

  Color? _outcomeColor() => switch (_outcome) {
        AttemptIncorrect() => Colors.orange.shade700,
        AttemptLockedOut() ||
        AttemptAlreadyCaptured() ||
        AttemptAlreadyOwner() ||
        AttemptFailed() =>
          Colors.red.shade700,
        _ => null,
      };

  Future<void> _scanForBarcodeAnswer() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerRoute(title: PuzzletStrings.scanBarcodeAnswerTitle),
      ),
    );
    if (scanned == null || scanned.isEmpty || !mounted) return;
    _answerController.text = scanned;
    await _submit(override: scanned);
  }

  Future<void> _scanForNfcAnswer() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const NfcScannerRoute(title: PuzzletStrings.scanNfcAnswerTitle),
      ),
    );
    if (scanned == null || scanned.isEmpty || !mounted) return;
    _answerController.text = scanned;
    await _submit(override: scanned);
  }

  @override
  void dispose() {
    _answerController.dispose();
    _confetti.dispose();
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
        title: Text('${PuzzletStrings.titlePrefix}  ${widget.pole.label ?? widget.pole.barcode}'),
      ),
      body: Stack(children: [
        // Confetti overlays the whole screen from the top centre,
        // firing in every direction on a correct answer. Behind the
        // scroll view in source order but painted above it because
        // it's later in the Stack.
        SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.puzzlet.warning != null &&
                widget.puzzlet.warning!.trim().isNotEmpty) ...[
              _WarningBanner(text: widget.puzzlet.warning!),
              const SizedBox(height: 16),
            ],
            Text(
              widget.puzzlet.instructions,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(PuzzletStrings.attemptsRemaining(_attemptsRemaining ?? 0)),
            if (_previousWrongAnswers.isNotEmpty) ...[
              const SizedBox(height: 16),
              _PreviousWrongAnswers(answers: _previousWrongAnswers),
            ],
            const SizedBox(height: 24),
            if (widget.puzzlet.answerType == 'barcode') ...[
              FilledButton.icon(
                onPressed: (_busy || disabled) ? null : _scanForBarcodeAnswer,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text(PuzzletStrings.scanBarcodeAnswerButton),
              ),
              const SizedBox(height: 12),
              Text(
                PuzzletStrings.scanBarcodeAnswerHelp,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
            ] else if (widget.puzzlet.answerType == 'nfc') ...[
              FilledButton.icon(
                onPressed: (_busy || disabled) ? null : _scanForNfcAnswer,
                icon: const Icon(Icons.contactless),
                label: const Text(PuzzletStrings.scanNfcAnswerButton),
              ),
              const SizedBox(height: 12),
              Text(
                PuzzletStrings.scanNfcAnswerHelp,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _answerController,
              enabled: !disabled,
              decoration: InputDecoration(
                labelText: widget.puzzlet.answerType == 'strict_text'
                    ? PuzzletStrings.answerLabelExact
                    : PuzzletStrings.answerLabel,
                border: const OutlineInputBorder(),
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
                  : const Text(PuzzletStrings.submitButton),
            ),
            if (outcomeText != null) ...[
              const SizedBox(height: 24),
              Text(outcomeText, style: TextStyle(color: _outcomeColor(), fontSize: 16)),
            ],
          ],
        ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 40,
            maxBlastForce: 25,
            minBlastForce: 8,
            gravity: 0.3,
            shouldLoop: false,
          ),
        ),
      ]),
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
            PuzzletStrings.previouslyTried,
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

class _WarningBanner extends StatelessWidget {
  final String text;
  const _WarningBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        border: Border.all(color: Colors.amber.shade700, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.amber.shade900, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
