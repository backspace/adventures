import 'package:flutter/material.dart';
import 'package:landgrab/l10n/player_strings.dart';

/// A pole marker. Poles are ONE consistent colour on the map regardless of
/// owner — ownership (colour + pattern) is read from the zone fill, so the pin
/// just needs to stay visible over any zone. A bold white ring marks *your*
/// team's stakes so you can still find yourself.
class PoleDot extends StatelessWidget {
  final bool isMine;
  // Every remaining puzzlet here conflicts with the team's needs — shown as a
  // distinct muted "blocked" marker (still claimable, hence not alarming).
  final bool prohibitive;
  // Fully captured — no puzzlets left to solve. Shown as a lock.
  final bool locked;
  // Rendered size; drives icon sizing so the same marker is legible both as a
  // ~12px map pin and as a larger swatch in the tap snackbar.
  final double dimension;
  const PoleDot({
    super.key,
    this.isMine = false,
    this.prohibitive = false,
    this.locked = false,
    this.dimension = 12,
  });

  // The one stake colour — a strong indigo (the pole identity used on the
  // author/supervisor maps too), high-contrast over any translucent zone fill
  // and the pale basemap.
  static const Color _color = Color(0xFF303F9F);

  @override
  Widget build(BuildContext context) {
    if (prohibitive) {
      // Distinct from the ordinary dot: a muted circle with a "no entry" glyph.
      // Neutral, not red — a heads-up, not an error.
      return DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blueGrey.shade700.withValues(alpha: 0.85),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.85), width: 0.75),
        ),
        child: Icon(Icons.do_not_disturb_on_outlined,
            size: dimension, color: Colors.white),
      );
    }
    final border = Border.all(
      color: Colors.white.withValues(alpha: isMine ? 1 : 0.85),
      width: isMine ? 2 : 0.75,
    );
    if (locked) {
      // A lock — "done / nothing to do here", distinct from the prohibitive
      // "blocked" glyph.
      return DecoratedBox(
        decoration:
            BoxDecoration(shape: BoxShape.circle, color: _color, border: border),
        child: Icon(Icons.lock, size: dimension * 0.72, color: Colors.white),
      );
    }
    return DecoratedBox(
      decoration:
          BoxDecoration(shape: BoxShape.circle, color: _color, border: border),
    );
  }
}

/// Small info badge hung on a pole marker's edge when the stake carries
/// accessibility notes or tags — a cue that tapping it reveals more. A white
/// disc (so it reads against any territory colour) with a blue info glyph.
class AccessibilityInfoBadge extends StatelessWidget {
  final double size;
  const AccessibilityInfoBadge({super.key, this.size = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
              color: Color(0x40000000), blurRadius: 2, offset: Offset(0, 0.5)),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(Icons.info, size: size, color: Colors.blue.shade700),
    );
  }
}

/// The starred puzzlet marker for validator-only content. Amber
/// star on a white disc for legibility against the light basemap.
/// Scales its inner icon proportionally so at very small sizes the
/// star still reads as a star rather than a formless dot.
class ValidatorOnlyStar extends StatelessWidget {
  final double size;
  const ValidatorOnlyStar({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border:
            Border.all(color: Colors.amber.shade700, width: size >= 20 ? 2 : 1),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.star,
        color: Colors.amber.shade700,
        size: size * 0.65,
      ),
    );
  }
}

/// Bottom-right map attribution chip for the tile provider.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 4, bottom: 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(
              '© CartoDB · © OpenStreetMap',
              style: TextStyle(fontSize: 10, color: Colors.black87),
            ),
          ),
        ),
      ),
    );
  }
}

/// Map control to show/hide stakes flagged prohibitive (nothing the team can
/// engage). A compact pill on the map; only rendered when such stakes exist.
class HideProhibitiveChip extends StatelessWidget {
  final bool hidden;
  final int count;
  final VoidCallback onToggle;
  const HideProhibitiveChip({
    super.key,
    required this.hidden,
    required this.count,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      color: theme.colorScheme.surface.withValues(alpha: 0.95),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
                hidden
                    ? Icons.visibility_off_outlined
                    : Icons.do_not_disturb_on_outlined,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              hidden
                  ? GameplayStrings.prohibitiveShow(count)
                  : GameplayStrings.prohibitiveHide(count),
              style: theme.textTheme.labelMedium,
            ),
          ]),
        ),
      ),
    );
  }
}
