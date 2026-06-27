import 'package:flutter/material.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/bathroom.dart';
import 'package:landgrab/routes/author/edit_bathroom_route.dart';
import 'package:landgrab/widgets/map_pin.dart';
import 'package:landgrab/widgets/pin_map.dart';

/// PinMap that also fetches and overlays bathroom pins. Used wherever
/// bathrooms should be visible alongside the primary data (poles,
/// puzzlet validations, etc.) — i.e. every map *except* the capture-flow
/// MiniLocationMap.
class MapWithBathrooms extends StatefulWidget {
  final LandgrabApi api;
  final List<MapPin> pins;
  final bool interactive;
  /// When true, tapping a bathroom pin opens the bathroom edit route.
  /// The route itself enforces creator-or-supervisor permission server-
  /// side, so it's fine to pass `true` from any author/supervisor view.
  final bool editableBathrooms;

  const MapWithBathrooms({
    super.key,
    required this.api,
    required this.pins,
    this.interactive = true,
    this.editableBathrooms = false,
  });

  @override
  State<MapWithBathrooms> createState() => _MapWithBathroomsState();
}

class _MapWithBathroomsState extends State<MapWithBathrooms> {
  List<Bathroom> _bathrooms = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.api.listBathrooms();
      if (!mounted) return;
      setState(() => _bathrooms = list);
    } catch (_) {
      // Bathrooms are decorative; quietly skip on failure.
    }
  }

  Future<void> _openBathroom(Bathroom b) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditBathroomRoute(api: widget.api, bathroom: b),
      ),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final bathroomPins = _bathrooms.map((b) => bathroomPin(
          b,
          onTap: widget.editableBathrooms ? () => _openBathroom(b) : null,
        ));
    return PinMap(
      pins: [...widget.pins, ...bathroomPins],
      interactive: widget.interactive,
    );
  }
}
