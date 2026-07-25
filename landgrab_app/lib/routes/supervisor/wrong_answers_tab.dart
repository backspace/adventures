import 'package:flutter/material.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/wrong_answers_board.dart';

/// Supervisor dashboard of wrong guesses: which puzzlets have been missed,
/// what teams guessed, and the correct answer for reference. Puzzlets are
/// listed most-recently-failed first (server-ordered); tap one to expand its
/// guesses.
class WrongAnswersTab extends StatefulWidget {
  final LandgrabApi api;
  const WrongAnswersTab({super.key, required this.api});

  @override
  State<WrongAnswersTab> createState() => _WrongAnswersTabState();
}

class _WrongAnswersTabState extends State<WrongAnswersTab> {
  WrongAnswersBoard? _board;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final board = await widget.api.getSupervisionWrongAnswers();
      if (!mounted) return;
      setState(() => _board = board);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load wrong answers: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _centered(
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: const Text('Try again')),
        ]),
      );
    }
    final board = _board;
    if (board == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (board.puzzlets.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: _centered(const Text('No wrong answers yet.')),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: board.puzzlets.length,
        itemBuilder: (context, i) => _puzzletCard(board.puzzlets[i]),
      ),
    );
  }

  Widget _puzzletCard(WrongAnswerPuzzlet p) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(p.titleDisplay),
        subtitle: Text(
          '${p.wrongCount} wrong guess${p.wrongCount == 1 ? '' : 'es'}'
          '${p.difficulty != null ? ' · difficulty ${p.difficulty}' : ''}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          if (p.instructions != null && p.instructions!.trim().isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(p.instructions!, style: theme.textTheme.bodyMedium),
            ),
            const SizedBox(height: 10),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(Icons.check_circle_outline,
                  size: 18, color: theme.colorScheme.onSecondaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  'Answer: ${p.answer ?? '(none)'}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          for (final a in p.attempts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.close, color: Colors.redAccent),
              title: Text(a.teamDisplay),
              subtitle: SelectableText('guessed “${a.answerGiven}”'),
              trailing: a.at == null
                  ? null
                  : Text(_ago(a.at!), style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }

  Widget _centered(Widget child) =>
      Center(child: Padding(padding: const EdgeInsets.all(24), child: child));

  // Compact "how long ago" label for an attempt's timestamp.
  static String _ago(DateTime when) {
    final d = DateTime.now().toUtc().difference(when.toUtc());
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
