import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:landgrab/services/location_service.dart';
import 'package:landgrab/widgets/mini_location_map.dart';

class LocationCard extends StatelessWidget {
  final LocationFix? fix;
  final String? error;
  final bool busy;
  final VoidCallback onRetry;

  /// When the marker has been manually dragged, the chosen position
  /// (shown on the mini-map and coordinate line instead of the raw GPS
  /// point) and how far it sits from GPS. Both null in the default,
  /// GPS-only flow (puzzlets, bathrooms).
  final LatLng? adjustedPosition;
  final double? manualOffsetM;

  /// When non-null, an "Adjust on map" button appears that opens the
  /// full-screen draggable-pin editor. Callers wire this to push
  /// [AdjustPositionRoute] and fold the result back into their state.
  final VoidCallback? onAdjust;

  const LocationCard({
    super.key,
    required this.fix,
    required this.error,
    required this.busy,
    required this.onRetry,
    this.adjustedPosition,
    this.manualOffsetM,
    this.onAdjust,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (busy) {
      return _frame(theme,
          child: const Row(children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Getting GPS fix…'),
          ]));
    }

    if (error != null) {
      return _frame(theme,
          color: theme.colorScheme.errorContainer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(error!, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
              const SizedBox(height: 8),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ));
    }

    final f = fix;
    if (f == null) {
      return _frame(theme,
          child: Row(children: [
            const Expanded(child: Text('No location fix yet.')),
            FilledButton(onPressed: onRetry, child: const Text('Get GPS')),
          ]));
    }

    final usable = f.isUsable;
    final accuracy = f.accuracyM.toStringAsFixed(1);
    final ageMinutes = DateTime.now().difference(f.timestamp).inMinutes;
    final statusText = _statusText(f, accuracy, ageMinutes);
    // Where the marker actually sits — the dragged position if there is
    // one, otherwise the raw GPS point.
    final lat = adjustedPosition?.latitude ?? f.latitude;
    final lng = adjustedPosition?.longitude ?? f.longitude;
    final moved = manualOffsetM != null && manualOffsetM! >= 1;
    return _frame(theme,
        color: usable ? null : theme.colorScheme.errorContainer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'),
            const SizedBox(height: 4),
            Text(statusText),
            if (moved)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Marker moved ${manualOffsetM!.toStringAsFixed(0)} m from GPS',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
            MiniLocationMap(latitude: lat, longitude: lng),
            const SizedBox(height: 4),
            Row(
              children: [
                TextButton(onPressed: onRetry, child: const Text('Re-acquire')),
                if (onAdjust != null)
                  TextButton.icon(
                    onPressed: onAdjust,
                    icon: const Icon(Icons.edit_location_alt, size: 18),
                    label: const Text('Adjust on map'),
                  ),
              ],
            ),
          ],
        ));
  }

  String _statusText(LocationFix f, String accuracy, int ageMinutes) {
    if (!f.isAccurate) {
      return 'Accuracy: $accuracy m — too imprecise. Move to a clearer spot.';
    }
    if (!f.isFresh) {
      return 'Accuracy: $accuracy m — fix is $ageMinutes min old. Re-acquire if you\'ve moved.';
    }
    return 'Accuracy: $accuracy m  ✓';
  }

  Widget _frame(ThemeData theme, {Color? color, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}
