import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:landgrab/l10n/player_strings.dart';
import 'package:landgrab/widgets/landgrab_app_bar.dart';
import 'package:landgrab/widgets/markdown_view.dart';

/// Player instructions. Before the simulation begins, shows a placeholder in
/// place of the real briefing; once it's begun, renders a precompiled
/// Markdown file (like the validator's Criteria view).
///
/// The briefing is LOCAL-ONLY — like Credits, `instructions.md` is gitignored
/// so the storyline text isn't published to a public repo (see
/// assets/instructions/README.md). A build without the file just shows a
/// short "no instructions" note after the event starts.
class InstructionsRoute extends StatefulWidget {
  /// Whether the simulation has begun. Until it has, the page shows the
  /// placeholder rather than the briefing. Callers pass the server's
  /// [LandgrabEvent.started] flag.
  final bool eventStarted;

  const InstructionsRoute({super.key, this.eventStarted = false});

  @override
  State<InstructionsRoute> createState() => _InstructionsRouteState();
}

class _InstructionsRouteState extends State<InstructionsRoute> {
  static const _asset = 'assets/instructions/instructions.md';

  // Null until loaded. Only fetched once the event has started — before that
  // the placeholder shows and the file stays sealed.
  String? _markdown;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.eventStarted) _load();
  }

  Future<void> _load() async {
    String? md;
    try {
      final s = (await rootBundle.loadString(_asset)).trim();
      md = s.isEmpty ? null : s;
    } catch (_) {
      // Absent/unreadable (e.g. a build with no briefing dropped in) — fall
      // back to the "unavailable" note below.
      md = null;
    }
    if (!mounted) return;
    setState(() {
      _markdown = md;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: LandgrabAppBar(title: InstructionsStrings.appBarTitle),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: _body(theme),
      ),
    );
  }

  Widget _body(ThemeData theme) {
    if (!widget.eventStarted) {
      return Text(
        InstructionsStrings.placeholder,
        style: theme.textTheme.bodyMedium,
      );
    }
    // Started: wait for the load, then render the briefing or the fallback.
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    final md = _markdown;
    if (md == null) {
      return Text(
        InstructionsStrings.unavailable,
        style: theme.textTheme.bodyMedium,
      );
    }
    return MarkdownView(md);
  }
}
