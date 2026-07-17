import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/region.dart';
import 'package:landgrab/models/validation.dart';
import 'package:landgrab/routes/barcode_scanner_route.dart';
import 'package:landgrab/routes/nfc_scanner_route.dart';
import 'package:landgrab/routes/validator/puzzlet_validation_form_route.dart';

/// Lets the validator work a puzzlet the way a player would after
/// scanning a pole — warning, region context, instructions, and an
/// **answer field to type or scan into** (the answer is NOT shown up
/// front). Once they submit an attempt, it checks it against the
/// expected answer, reveals it for comparison, and prompts for feedback
/// (endorse, or open the suggest-edits form).
class PuzzletValidationPreviewRoute extends StatefulWidget {
  final LandgrabApi api;
  final PuzzletValidationModel validation;

  const PuzzletValidationPreviewRoute({
    super.key,
    required this.api,
    required this.validation,
  });

  @override
  State<PuzzletValidationPreviewRoute> createState() =>
      _PuzzletValidationPreviewRouteState();
}

class _PuzzletValidationPreviewRouteState
    extends State<PuzzletValidationPreviewRoute> {
  final _answer = TextEditingController();
  bool _attempted = false;
  bool? _correct; // null = revealed without a real attempt
  bool _busy = false;
  final _note = TextEditingController();

  ValidationPuzzletSummary get _p => widget.validation.puzzlet!;

  bool get _editable =>
      widget.validation.status == ValidationStatus.assigned ||
      widget.validation.status == ValidationStatus.inProgress;

  bool get _isStrict =>
      _p.answerType == 'strict_text' ||
      _p.answerType == 'barcode' ||
      _p.answerType == 'nfc';

  bool get _canScan =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  String get _answerTypeLabel => switch (_p.answerType) {
        'strict_text' => 'Exact text',
        'barcode' => 'Barcode',
        'nfc' => 'NFC tag',
        _ => 'Text',
      };

  @override
  void dispose() {
    _answer.dispose();
    _note.dispose();
    super.dispose();
  }

  // Approximates the server's matching (loose = case-insensitive/trimmed;
  // everything else exact). It's only to give the validator a "does this
  // work?" signal, not an authoritative capture.
  bool _matches(String input) {
    if (_isStrict) return input == _p.answer;
    return input.trim().toLowerCase() == _p.answer.trim().toLowerCase();
  }

  void _submitAnswer({String? override}) {
    final raw = override ?? _answer.text;
    final input = _isStrict ? raw : raw.trim();
    if (input.isEmpty) return;
    setState(() {
      _attempted = true;
      _correct = _matches(input);
    });
  }

  Future<void> _scan(Widget scanner) async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => scanner),
    );
    if (scanned == null || scanned.isEmpty || !mounted) return;
    _answer.text = scanned;
    _submitAnswer(override: scanned);
  }

  void _reveal() => setState(() {
        _attempted = true;
        _correct = null; // revealed, not solved
      });

  Future<void> _endorse() async {
    setState(() => _busy = true);
    try {
      await widget.api.submitPuzzletValidation(widget.validation.id,
          overallNotes: _note.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Endorsed — looks good.')));
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = e.response?.data?['error']?['detail'] ?? e.message;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not endorse: $detail')));
    }
  }

  Future<void> _openForm() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PuzzletValidationFormRoute(
          api: widget.api,
          validation: widget.validation,
        ),
      ),
    );
    if (changed == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final revealed = _attempted || !_editable;
    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_p.warning != null && _p.warning!.trim().isNotEmpty) ...[
            _Banner(
              color: Colors.amber.shade800,
              icon: Icons.warning_amber_rounded,
              text: _p.warning!,
            ),
            const SizedBox(height: 16),
          ],
          if (_p.region != null) ...[
            _RegionCard(
              breadcrumb: _p.region!.breadcrumb,
              stanzas: _p.inheritedStanzas,
            ),
            const SizedBox(height: 16),
          ],
          Text(_p.instructions, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Difficulty ${_p.difficulty} / 10',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 20),

          // Answer entry — mirrors the player's puzzlet screen. Only
          // shown while the validation is still open.
          if (_editable) ...[
            if (_isStrict && _canScan) ...[
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _scan(_p.answerType == 'nfc'
                        ? const NfcScannerRoute(title: 'Scan the NFC tag')
                        : const BarcodeScannerRoute(title: 'Scan the barcode')),
                icon: Icon(_p.answerType == 'nfc'
                    ? Icons.contactless
                    : Icons.qr_code_scanner),
                label: Text(_p.answerType == 'nfc'
                    ? 'Tap NFC tag to answer'
                    : 'Scan barcode to answer'),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _answer,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [],
              decoration: InputDecoration(
                labelText: _isStrict ? 'Answer ($_answerTypeLabel)' : 'Answer',
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submitAnswer(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: _busy ? null : () => _submitAnswer(),
                  child: const Text('Check answer'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _busy ? null : _reveal,
                  child: const Text('Reveal / can’t test'),
                ),
              ],
            ),
          ],

          if (revealed) ...[
            const SizedBox(height: 20),
            if (_correct != null)
              _Banner(
                color: _correct! ? Colors.green : Colors.red.shade700,
                icon: _correct! ? Icons.check_circle_outline : Icons.error_outline,
                text: _correct!
                    ? 'That matches the expected answer.'
                    : 'That doesn’t match the expected answer.',
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.key_outlined, size: 16, color: theme.hintColor),
                    const SizedBox(width: 6),
                    Text('Expected answer · $_answerTypeLabel',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.hintColor)),
                  ]),
                  const SizedBox(height: 4),
                  SelectableText(_p.answer, style: theme.textTheme.titleMedium),
                ],
              ),
            ),
          ],

          // Feedback step — only once they've had a go (or revealed).
          if (_editable && _attempted) ...[
            const SizedBox(height: 24),
            Text('Any feedback?', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes for the supervisor (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _endorse,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.thumb_up_outlined),
              label: const Text('Looks good — endorse'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _openForm,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Something\'s wrong — suggest edits'),
            ),
          ],
          if (!_editable) ...[
            const SizedBox(height: 16),
            Text(
              'This validation is ${validationStatusLabel(widget.validation.status)}.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Region context, matching what a player sees.
class _RegionCard extends StatelessWidget {
  final String breadcrumb;
  final List<InheritedStanza> stanzas;

  const _RegionCard({required this.breadcrumb, required this.stanzas});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place_outlined, size: 18, color: theme.hintColor),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(breadcrumb, style: theme.textTheme.titleSmall)),
            ],
          ),
          for (final s in stanzas) ...[
            const SizedBox(height: 8),
            if (stanzas.length > 1)
              Text(s.source, style: theme.textTheme.labelMedium),
            if (s.entryInstructions != null &&
                s.entryInstructions!.trim().isNotEmpty)
              Text('Getting in: ${s.entryInstructions}',
                  style: theme.textTheme.bodyMedium),
            if (s.notes != null && s.notes!.trim().isNotEmpty)
              Text('Accessibility: ${s.notes}',
                  style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const _Banner({required this.color, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
