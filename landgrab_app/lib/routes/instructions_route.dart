import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:landgrab/l10n/player_strings.dart';
import 'package:landgrab/models/landgrab_event.dart';
import 'package:landgrab/widgets/landgrab_app_bar.dart';
import 'package:landgrab/widgets/markdown_view.dart';

/// Player instructions. Until the onboarding window opens (15 min before the
/// simulation begins — see [LandgrabEvent.onboardingStarted]), shows a
/// placeholder in place of the real briefing; from then on it renders a
/// precompiled Markdown file (like the validator's Criteria view).
///
/// The briefing is LOCAL-ONLY — like Credits, `instructions.md` is gitignored
/// so the storyline text isn't published to a public repo (see
/// assets/instructions/README.md). A build without the file just shows a
/// short "no instructions" note once onboarding opens.
class InstructionsRoute extends StatefulWidget {
  /// The current event; its [LandgrabEvent.onboardingStarted] gates the
  /// briefing. Null (e.g. in a bare test) keeps the placeholder up.
  final LandgrabEvent? event;

  const InstructionsRoute({super.key, this.event});

  @override
  State<InstructionsRoute> createState() => _InstructionsRouteState();
}

class _InstructionsRouteState extends State<InstructionsRoute> {
  static const _asset = 'assets/instructions/instructions.md';

  // Null until loaded. Only fetched once onboarding opens — before that the
  // placeholder shows and the file stays sealed.
  String? _markdown;
  bool _loaded = false;
  Timer? _revealTimer;

  bool get _revealed => widget.event?.onboardingStarted ?? false;

  @override
  void initState() {
    super.initState();
    if (_revealed) {
      _load();
    } else {
      // Flip to the briefing the moment onboarding opens, even if the page is
      // left open across that boundary. Poll (rather than a single exact
      // timer) so a clock change or long sleep can't miss it.
      _revealTimer = Timer.periodic(const Duration(seconds: 20), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        if (_revealed) {
          t.cancel();
          _load();
          setState(() {}); // swap placeholder → loading/briefing
        }
      });
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
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
    if (!_revealed) {
      return Text(
        InstructionsStrings.placeholder,
        style: theme.textTheme.bodyMedium,
      );
    }
    // Onboarding open: wait for the load, then render the briefing or fallback.
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
