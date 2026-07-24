import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A non-colour cue layered on top of a team's colour, so teams that share a
/// palette colour (there are more teams than colours) and colour-blind players
/// can still tell them apart. The same texture is used on the pole-dot glyph
/// and the territory fill, so a team reads consistently in both places.
///
/// Ordered so adjacent bands look as different as possible: `solid` (the plain
/// first 12 teams), then dots, a diagonal hatch, X marks, and the
/// opposite-diagonal hatch.
enum TeamPattern { solid, dots, hatch, xes, backHatch }

/// The colour + pattern a team is drawn with on the map. Derived purely from
/// the server's stable per-team ordinal (`currentOwnerColorIndex`), so a team
/// looks the same in every player's view. `colours × patterns` = 60 distinct
/// combinations before any repeat.
class TeamStyle {
  final Color color;
  final TeamPattern pattern;
  const TeamStyle(this.color, this.pattern);

  /// Colour-blind-conscious qualitative palette (Paul Tol / Okabe-Ito
  /// lineage), medium-dark so it reads on the light basemap and as a
  /// translucent territory fill.
  static const palette = <Color>[
    Color(0xFFEE6677), // red
    Color(0xFF4477AA), // blue
    Color(0xFF228833), // green
    Color(0xFFCCBB44), // yellow
    Color(0xFF66CCEE), // cyan
    Color(0xFFAA3377), // purple
    Color(0xFFEE7733), // orange
    Color(0xFF009988), // teal
    Color(0xFF882255), // wine
    Color(0xFF332288), // indigo
    Color(0xFF999933), // olive
    Color(0xFF777777), // grey
  ];

  static TeamStyle forIndex(int index) {
    final i = index < 0 ? 0 : index;
    final color = palette[i % palette.length];
    final pattern =
        TeamPattern.values[(i ~/ palette.length) % TeamPattern.values.length];
    return TeamStyle(color, pattern);
  }
}

/// Paints a team's colour swatch plus its pattern glyph (in [glyphColor], a
/// contrasting ink). Used for the team-identity swatches (header, tap-a-zone
/// sheet). [square] draws a rounded square rather than a disc, so a team
/// swatch reads as "the team" and not as a (round) pole pin.
class TeamGlyphPainter extends CustomPainter {
  final Color color;
  final TeamPattern pattern;
  final Color glyphColor;
  final bool square;

  /// Optional opaque backing painted under [color] as the same shape. Lets the
  /// swatch use the map's translucent fill opacity over white, so its colour
  /// composites the same pale tint the zone shows over the light basemap.
  final Color? background;

  TeamGlyphPainter({
    required this.color,
    required this.pattern,
    this.glyphColor = Colors.white,
    this.square = false,
    this.background,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: 2 * r, height: 2 * r),
      Radius.circular(r * 0.42),
    );
    void drawShape(Paint paint) {
      if (square) {
        canvas.drawRRect(rrect, paint);
      } else {
        canvas.drawCircle(c, r, paint);
      }
    }

    if (background != null) drawShape(Paint()..color = background!);
    drawShape(Paint()..color = color);

    if (pattern == TeamPattern.solid) return; // plain fill is its own "pattern"

    // Clip to the swatch so the texture (a miniature of the team's territory
    // hatch/dots) stays inside it.
    canvas.save();
    if (square) {
      canvas.clipRRect(rrect);
    } else {
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    }

    if (pattern == TeamPattern.dots) {
      final dot = Paint()
        ..color = glyphColor
        ..style = PaintingStyle.fill;
      final step = r * 0.62;
      final dr = r * 0.17;
      for (var x = c.dx - r; x <= c.dx + r; x += step) {
        for (var y = c.dy - r; y <= c.dy + r; y += step) {
          canvas.drawCircle(Offset(x, y), dr, dot);
        }
      }
    } else if (pattern == TeamPattern.xes) {
      final ink = Paint()
        ..color = glyphColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.14
        ..strokeCap = StrokeCap.round;
      final step = r * 0.72;
      final a = r * 0.21;
      for (var x = c.dx - r; x <= c.dx + r; x += step) {
        for (var y = c.dy - r; y <= c.dy + r; y += step) {
          canvas.drawLine(Offset(x - a, y - a), Offset(x + a, y + a), ink);
          canvas.drawLine(Offset(x - a, y + a), Offset(x + a, y - a), ink);
        }
      }
    } else {
      final ink = Paint()
        ..color = glyphColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.26
        ..strokeCap = StrokeCap.round;
      final step = r * 0.62;
      final deg = pattern == TeamPattern.hatch ? 45.0 : -45.0;
      final theta = deg * math.pi / 180;
      final dir = Offset(math.cos(theta), math.sin(theta));
      final perp = Offset(-math.sin(theta), math.cos(theta));
      for (var d = -r; d <= r; d += step) {
        final mid = c + perp * d;
        canvas.drawLine(mid - dir * r * 1.5, mid + dir * r * 1.5, ink);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TeamGlyphPainter old) =>
      old.color != color ||
      old.pattern != pattern ||
      old.glyphColor != glyphColor ||
      old.square != square ||
      old.background != background;
}

/// A team-identity swatch: the team's colour at the map's territory-fill
/// opacity over a white tile, plus its pattern — so it reads the same pale
/// tint the team's zone shows over the light basemap, on any surface (the dark
/// snackbar, the header bar, a sheet). Square, to distinguish it from a (round)
/// pole pin.
class TeamSwatch extends StatelessWidget {
  final int colorIndex;
  final bool isMine;
  final double size;

  const TeamSwatch({
    super.key,
    required this.colorIndex,
    this.isMine = false,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final style = TeamStyle.forIndex(colorIndex);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: TeamGlyphPainter(
          // Match the territory fill's opacity (0.40 for your own zones, 0.26
          // for rivals) over a backing the colour of the map's built area.
          color: style.color.withValues(alpha: isMine ? 0.40 : 0.26),
          // CartoDB Positron renders buildings a light grey (most of the map a
          // stake sits on), so backing the swatch with it composites the same
          // tint the zone shows over the map — not the brighter pure white.
          background: const Color(0xFFE8E8E8),
          pattern: style.pattern,
          // The same faint darkened-hue ink the territory pattern uses.
          glyphColor: Color.lerp(style.color, Colors.black, 0.35)!
              .withValues(alpha: 0.3),
          square: true,
        ),
      ),
    );
  }
}
