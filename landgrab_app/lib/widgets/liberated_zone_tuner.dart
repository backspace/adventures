import 'package:flutter/material.dart';
import 'package:landgrab/widgets/liberated_zone_layer.dart';

/// THROWAWAY dev aid — a compact on-device tuner for the liberated-zone look,
/// so the hatch can be dialled in against the real map/tiles instead of a web
/// mock. Off unless built with `--dart-define=LIBERATED_TUNER=true`; delete
/// this file (and its two call sites in home_route) once the look is settled.
///
/// Steppers, not sliders, per the design note: +/- nudges land on a value you
/// can read back and reproduce, where a slider only gets you "about there".
const bool kLiberatedTunerEnabled =
    bool.fromEnvironment('LIBERATED_TUNER', defaultValue: false);

class LiberatedZoneTuner extends StatelessWidget {
  final LiberatedZoneStyle style;
  final int previewCount;
  final ValueChanged<LiberatedZoneStyle> onStyle;
  final ValueChanged<int> onPreview;

  const LiberatedZoneTuner({
    super.key,
    required this.style,
    required this.previewCount,
    required this.onStyle,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Wrap(
          spacing: 10,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _stepper('preview', previewCount.toDouble(), 1, 0, 40,
                (v) => onPreview(v.round()),
                digits: 0),
            _stepper('gap', style.spacing, 1, 4, 60,
                (v) => onStyle(style.copyWith(spacing: v))),
            _stepper('width', style.strokeWidth, 0.5, 0.5, 10,
                (v) => onStyle(style.copyWith(strokeWidth: v)),
                digits: 1),
            _stepper('speed', style.speed, 0.25, 0, 8,
                (v) => onStyle(style.copyWith(speed: v)),
                digits: 2),
            _stepper('angle', style.angleDeg, 5, 0, 180,
                (v) => onStyle(style.copyWith(angleDeg: v))),
            _stepper('wash', style.washAlpha, 0.02, 0, 0.6,
                (v) => onStyle(style.copyWith(washAlpha: v)),
                digits: 2),
            _stepper('line', style.lineAlpha, 0.05, 0, 1,
                (v) => onStyle(style.copyWith(lineAlpha: v)),
                digits: 2),
          ],
        ),
      ),
    );
  }

  Widget _stepper(
    String label,
    double value,
    double step,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    int digits = 0,
  }) {
    void nudge(double delta) =>
        onChanged((value + delta).clamp(min, max).toDouble());
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn('−', () => nudge(-step)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '$label ${value.toStringAsFixed(digits)}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        _btn('+', () => nudge(step)),
      ],
    );
  }

  Widget _btn(String glyph, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(glyph,
              style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
      );
}
