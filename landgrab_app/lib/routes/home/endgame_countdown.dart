import 'dart:async';

import 'package:flutter/material.dart';
import 'package:landgrab/l10n/player_strings.dart';

/// Top-of-map pill counting down to the end of the simulation. Hidden until the
/// final [lead] (10 minutes) before [endsAt]; ticks each second and turns red
/// in the last minute. In the final [_heartbeatWindow] (10 s) it "beats" — a
/// quick pop to 1.3× synced to each second, purely a paint-time scale so it
/// never reflows the overlay column. Renders zero-size outside its window so it
/// takes no layout room (the parent includes it whenever an endgame exists).
class EndgameCountdown extends StatefulWidget {
  final DateTime endsAt;
  final Duration lead;

  const EndgameCountdown({
    super.key,
    required this.endsAt,
    this.lead = const Duration(minutes: 10),
  });

  @override
  State<EndgameCountdown> createState() => _EndgameCountdownState();
}

class _EndgameCountdownState extends State<EndgameCountdown>
    with SingleTickerProviderStateMixin {
  static const _heartbeatWindow = Duration(seconds: 10);

  Timer? _ticker;
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    // One heartbeat per cycle: a quick pop up to 1.3× (first quarter) then an
    // ease back to rest (remaining three quarters). At rest (_pulse == 0) the
    // sequence sits at 1.0, so a non-beating pill is unscaled.
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 75,
      ),
    ]).animate(_pulse);

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = _remaining();
      // Fire a beat as each of the final seconds ticks over.
      if (remaining > Duration.zero && remaining <= _heartbeatWindow) {
        _pulse.forward(from: 0);
      }
      setState(() {});
    });
  }

  Duration _remaining() =>
      widget.endsAt.toUtc().difference(DateTime.now().toUtc());

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _remaining();
    // Only within the final window, and only before the end — the game-over
    // notice takes over at zero.
    if (remaining <= Duration.zero || remaining > widget.lead) {
      return const SizedBox.shrink();
    }

    final urgent = remaining <= const Duration(minutes: 1);
    final scheme = Theme.of(context).colorScheme;
    final bg = urgent ? Colors.red.shade700 : scheme.surface;
    final fg = urgent ? Colors.white : scheme.onSurface;

    final pill = Material(
      elevation: 2,
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_bottom, size: 18, color: fg),
            const SizedBox(width: 6),
            Text(
              GameplayStrings.endsIn(_format(remaining)),
              style: TextStyle(
                color: fg,
                fontWeight: urgent ? FontWeight.bold : FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      // ScaleTransition is a paint-time transform: the pill can beat to 1.3×
      // without changing its layout box, so the hide-chip below never shifts.
      child: Center(child: ScaleTransition(scale: _scale, child: pill)),
    );
  }

  static String _format(Duration r) {
    final m = r.inMinutes;
    final s = r.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
