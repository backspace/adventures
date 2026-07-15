import 'package:flutter/material.dart';

import 'package:landgrab/flavors.dart';
import 'package:landgrab/services/env_switch_service.dart';

// Credits copy is plain real-world chrome (not in-storyline), so it
// lives here rather than in player_strings.dart. Sections are mostly
// short unbulleted lines — put one entry per line; the blank-line gap
// between groups is just a `\n\n`. Replace the examples below.
const _appBarTitle = 'Credits';

const _acknowledgementsHeading = 'Acknowledgements';
const _acknowledgementsBody = '''
CC Slaughters
XYZ
''';

const _soundtrackHeading = 'Soundtrack';
const _soundtrackBody = '''
ABC
''';

const _softwareHeading = 'Software';
const _softwareBody = '''
Flutter, Phoenix
Coolify, Hetzner, Tailscale
''';
const _softwareLicensesButton = 'Open-source licenses';

const _envSwitcherUnlocked = 'Environment switcher unlocked.';

/// Placeholder Credits page. The version line at the bottom hides an
/// easter egg — tap it 7 times inside 3 seconds to unlock the in-app
/// environment switcher. Works on every flavor (production included),
/// but it's off by default and only this deliberate gesture reveals
/// it, so an attendee never sees it without hunting for it.
class CreditsRoute extends StatefulWidget {
  const CreditsRoute({super.key});

  @override
  State<CreditsRoute> createState() => _CreditsRouteState();
}

class _CreditsRouteState extends State<CreditsRoute> {
  static const _tapsToUnlock = 7;
  static const _tapWindow = Duration(seconds: 3);

  int _tapCount = 0;
  DateTime? _firstTapAt;

  void _onVersionTap() async {
    final now = DateTime.now();
    // Reset the counter if the pause between taps is too long — a
    // stray tap while reading shouldn't count toward the sequence.
    if (_firstTapAt == null || now.difference(_firstTapAt!) > _tapWindow) {
      _firstTapAt = now;
      _tapCount = 1;
    } else {
      _tapCount += 1;
    }
    if (_tapCount >= _tapsToUnlock && !EnvSwitchService.visible.value) {
      await EnvSwitchService.unlock();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(_envSwitcherUnlocked),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(_appBarTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Section(
              heading: _acknowledgementsHeading,
              body: _acknowledgementsBody,
            ),
            _Section(
              heading: _soundtrackHeading,
              body: _soundtrackBody,
            ),
            _Section(
              heading: _softwareHeading,
              body: _softwareBody,
              // Flutter auto-collects every bundled package's license,
              // so this stays correct without a hand-maintained list.
              trailing: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text(_softwareLicensesButton),
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: F.title,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _onVersionTap,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    F.title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A headed credits section: title, body copy, and an optional
/// trailing widget (e.g. the licenses button).
class _Section extends StatelessWidget {
  final String heading;
  final String body;
  final Widget? trailing;

  const _Section({required this.heading, required this.body, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodyMedium),
          if (trailing != null) ...[
            const SizedBox(height: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}
