import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:landgrab/flavors.dart';
import 'package:landgrab/routes/server_licenses_route.dart';
import 'package:landgrab/services/env_service.dart';
import 'package:landgrab/services/env_switch_service.dart';
import 'package:landgrab/widgets/landgrab_app_bar.dart';

// Credits copy is plain real-world chrome (not in-storyline), so it
// lives here rather than in player_strings.dart.
//
// The bodies name the real-world venue, soundtrack, and stack, which we
// don't want published to a public repo — so each section's text is
// loaded at runtime from a plain-text asset rather than hard-coded here.
// The .txt files are gitignored (see assets/credits/README.md); write
// them as normal multi-line text, one entry per line. A missing, empty,
// or unreadable file just hides that section.
const _appBarTitle = 'Credits';

const _acknowledgementsHeading = 'Acknowledgements';
const _acknowledgementsAsset = 'assets/credits/acknowledgements.txt';

const _soundtrackHeading = 'Soundtrack';
const _soundtrackAsset = 'assets/credits/soundtrack.txt';

const _softwareHeading = 'Computering';
const _softwareAsset = 'assets/credits/software.txt';
const _softwareLicensesButton = 'App open-source licenses';
const _serverLicensesButton = 'Server open-source licenses';

const _envSwitcherUnlocked = 'Environment switcher unlocked.';

// Shown on the Credits page until the simulation begins, in place of the
// real credits (which name the venue, soundtrack, and stack). Edit this to
// whatever pre-event copy you want; once the event starts, the file-backed
// sections replace it.
const _placeholderBody =
    'Full credits will appear here once the simulation has begun.';

/// Reads a credits section body from a bundled asset, returning null
/// when the file is absent (e.g. a fresh clone), unreadable, or blank —
/// so the caller can drop the section entirely.
Future<String?> _loadCredit(String asset) async {
  try {
    final value = (await rootBundle.loadString(asset)).trim();
    return value.isEmpty ? null : value;
  } catch (_) {
    return null;
  }
}

/// Placeholder Credits page. The version line at the bottom hides an
/// easter egg — tap it 7 times inside 3 seconds to unlock the in-app
/// environment switcher. Works on every flavor (production included),
/// but it's off by default and only this deliberate gesture reveals
/// it, so an attendee never sees it without hunting for it.
class CreditsRoute extends StatefulWidget {
  /// Whether the simulation has begun. Until it has, the page shows a
  /// placeholder in place of the real credits. Callers pass the server's
  /// [LandgrabEvent.started] flag; the login screen has no event loaded,
  /// so it defaults to false — the placeholder — which is also the safe
  /// default for an unauthenticated screen.
  final bool eventStarted;

  const CreditsRoute({super.key, this.eventStarted = false});

  @override
  State<CreditsRoute> createState() => _CreditsRouteState();
}

class _CreditsRouteState extends State<CreditsRoute> {
  static const _tapsToUnlock = 7;
  static const _tapWindow = Duration(seconds: 3);

  int _tapCount = 0;
  DateTime? _firstTapAt;

  String? _acknowledgements;
  String? _soundtrack;
  String? _software;

  @override
  void initState() {
    super.initState();
    _loadCredits();
  }

  Future<void> _loadCredits() async {
    final bodies = await Future.wait([
      _loadCredit(_acknowledgementsAsset),
      _loadCredit(_soundtrackAsset),
      _loadCredit(_softwareAsset),
    ]);
    if (!mounted) return;
    setState(() {
      _acknowledgements = bodies[0];
      _soundtrack = bodies[1];
      _software = bodies[2];
    });
  }

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
      appBar: LandgrabAppBar(title: _appBarTitle),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.eventStarted)
              // Before the simulation begins, hold the real credits (venue,
              // soundtrack, stack) back behind a placeholder.
              Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: Text(
                  _placeholderBody,
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else ...[
              if (_acknowledgements != null)
                _Section(
                  heading: _acknowledgementsHeading,
                  body: _acknowledgements,
                ),
              if (_soundtrack != null)
                _Section(
                  heading: _soundtrackHeading,
                  body: _soundtrack,
                ),
            ],
            // Software section: the open-source-licenses button is generic
            // and stays available always; the software.txt body (our stack)
            // shows only once the simulation has begun.
            _Section(
              heading: _softwareHeading,
              body: widget.eventStarted ? _software : null,
              // Flutter auto-collects every bundled package's license,
              // so this stays correct without a hand-maintained list.
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The app's own (Flutter/Dart) licenses — Flutter
                  // auto-collects every bundled package's license.
                  OutlinedButton.icon(
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text(_softwareLicensesButton),
                    onPressed: () => showLicensePage(
                      context: context,
                      applicationName: F.title,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // The Phoenix/Elixir server's dependency licenses,
                  // generated by `mix landgrab.licenses`.
                  OutlinedButton.icon(
                    icon: const Icon(Icons.dns_outlined, size: 18),
                    label: const Text(_serverLicensesButton),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ServerLicensesRoute(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
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
                  // The server this build is actually talking to. Surfaced so
                  // a wrong environment — e.g. a stale staging override left by
                  // the env switcher — is visible rather than silent.
                  ValueListenableBuilder<String?>(
                    valueListenable: EnvService.instance.currentApiRoot,
                    builder: (context, root, _) => Text(
                      root ?? '—',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A headed credits section: title, optional body copy, and an optional
/// trailing widget (e.g. the licenses button).
class _Section extends StatelessWidget {
  final String heading;
  final String? body;
  final Widget? trailing;

  const _Section({required this.heading, this.body, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: theme.textTheme.titleLarge),
          if (body != null) ...[
            const SizedBox(height: 8),
            Text(body!, style: theme.textTheme.bodyMedium),
          ],
          if (trailing != null) ...[
            const SizedBox(height: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}
