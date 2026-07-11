import 'package:flutter/material.dart';

import 'package:landgrab/flavors.dart';
import 'package:landgrab/l10n/player_strings.dart';
import 'package:landgrab/services/env_switch_service.dart';

/// Placeholder Credits page. The version line at the bottom hides an
/// easter egg — tap it 7 times inside 3 seconds to unlock the in-app
/// environment switcher on dev/alpha builds. In production the tap
/// counter still runs but `EnvSwitchService.unlock()` no-ops, so the
/// switcher never appears no matter how many times you tap.
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
          content: Text(CreditsStrings.envSwitcherUnlocked),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(CreditsStrings.appBarTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              CreditsStrings.acknowledgmentsHeading,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              CreditsStrings.placeholderCopy,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 48),
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
