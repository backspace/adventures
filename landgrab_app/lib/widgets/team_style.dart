import 'package:flutter/material.dart';

/// A non-colour cue layered on top of a team's colour, so teams that share a
/// palette colour (there are more teams than colours) and colour-blind
/// players can still tell them apart. Rendered as a small glyph on the pin.
enum TeamPattern { solid, bar, ring, cross }

/// The colour + pattern a team is drawn with on the map. Derived purely from
/// the server's stable per-team ordinal (`currentOwnerColorIndex`), so a team
/// looks the same in every player's view. `colours × patterns` = 48 distinct
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

/// Paints a team's colour disc plus its pattern glyph (in [glyphColor], a
/// contrasting ink). Used by the map pins; kept here so the pin and any
/// legend/owner-sheet swatch render identically.
class TeamGlyphPainter extends CustomPainter {
  final Color color;
  final TeamPattern pattern;
  final Color glyphColor;

  TeamGlyphPainter({
    required this.color,
    required this.pattern,
    this.glyphColor = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = color);

    final ink = Paint()
      ..color = glyphColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.34
      ..strokeCap = StrokeCap.round;

    switch (pattern) {
      case TeamPattern.solid:
        break; // the plain disc is its own "pattern"
      case TeamPattern.bar:
        canvas.drawLine(
            Offset(c.dx - r * 0.55, c.dy), Offset(c.dx + r * 0.55, c.dy), ink);
      case TeamPattern.ring:
        canvas.drawCircle(c, r * 0.45, ink);
      case TeamPattern.cross:
        canvas.drawLine(
            Offset(c.dx - r * 0.5, c.dy), Offset(c.dx + r * 0.5, c.dy), ink);
        canvas.drawLine(
            Offset(c.dx, c.dy - r * 0.5), Offset(c.dx, c.dy + r * 0.5), ink);
    }
  }

  @override
  bool shouldRepaint(covariant TeamGlyphPainter old) =>
      old.color != color || old.pattern != pattern || old.glyphColor != glyphColor;
}
