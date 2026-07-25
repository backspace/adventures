import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:landgrab/l10n/player_strings.dart';

/// Top-of-map pill counting down to the end of the simulation. Hidden until the
/// final [lead] (10 minutes) before [endsAt]; shows mm:ss and turns red in the
/// last minute. In the final [_heartbeatWindow] (10 s) it beats — a pop scaled
/// straight off the wall clock, so the peak lands exactly as each second flips
/// (both derive from the same instant). The final second collapses the pill to
/// nothing as the clock reaches zero. All scaling is a paint-time transform, so
/// the beat never reflows the overlay column. Zero-size outside its window.
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
  // Per-frame pump for the smooth pulse in the final window. Its value is
  // unused — the scale reads the wall clock — it just drives rebuilds at 60 Hz.
  late final AnimationController _frames;

  @override
  void initState() {
    super.initState();
    _frames = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    // Second-granularity rebuilds carry the mm:ss text through the whole
    // 10-minute window; the per-frame pump kicks in only for the last 10 s.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining() <= _heartbeatWindow && !_frames.isAnimating) {
        _frames.repeat();
      }
      setState(() {});
    });
  }

  Duration _remaining() =>
      widget.endsAt.toUtc().difference(DateTime.now().toUtc());

  @override
  void dispose() {
    _ticker?.cancel();
    _frames.dispose();
    super.dispose();
  }

  // Scale as a pure function of the time left, so the beat's peak coincides
  // with the second flipping (both come from the same clock), and the final
  // second shrinks the pill from its peak to nothing.
  double _scaleFor(Duration remaining) {
    final secs = remaining.inMilliseconds / 1000.0;
    if (secs > 10) return 1.0; // shown, not beating yet
    if (secs <= 1.0) {
      // Final second: collapse from the peak to zero as the clock hits 0.
      return 1.3 * secs.clamp(0.0, 1.0);
    }
    // A beat that peaks on each whole-second boundary (fract → 0), sitting near
    // rest between them. The number flips at that same boundary.
    final frac = secs - secs.floorToDouble();
    final beat = math.pow(math.cos(math.pi * frac).abs(), 6).toDouble();
    return 1.0 + 0.3 * beat;
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds every frame while _frames is repeating (final window); otherwise
    // once per second from the timer above.
    return AnimatedBuilder(
      animation: _frames,
      builder: (context, _) {
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
          // Paint-only scale: the pill can beat / collapse without changing its
          // layout box, so the hide-chip below never shifts.
          child: Center(
            child: Transform.scale(scale: _scaleFor(remaining), child: pill),
          ),
        );
      },
    );
  }

  static String _format(Duration r) {
    final m = r.inMinutes;
    final s = r.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
