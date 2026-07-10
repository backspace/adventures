import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_compass/flutter_map_compass.dart';
import 'package:latlong2/latlong.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/bathroom.dart';
import 'package:landgrab/models/pole.dart';
import 'package:landgrab/models/landgrab_event.dart';
import 'package:landgrab/models/test_session.dart';
import 'package:landgrab/flavors.dart';
import 'package:landgrab/routes/author/author_route.dart';
import 'package:landgrab/routes/barcode_scanner_route.dart';
import 'package:landgrab/routes/credits_route.dart';
import 'package:landgrab/routes/details_webview_route.dart';
import 'package:landgrab/routes/login_route.dart';
import 'package:landgrab/routes/nfc_scanner_route.dart';
import 'package:landgrab/routes/scan_route.dart';
import 'package:landgrab/routes/settings_route.dart';
import 'package:landgrab/routes/supervisor/supervisor_route.dart';
import 'package:landgrab/routes/test_play/test_play_entry_route.dart';
import 'package:landgrab/routes/validator/validator_route.dart';
import 'package:landgrab/services/env_switch_service.dart';
import 'package:landgrab/services/landgrab_socket.dart';
import 'package:landgrab/services/user_service.dart';
import 'package:landgrab/widgets/bathroom_layer.dart';
import 'package:landgrab/widgets/territory_layer.dart';

class HomeRoute extends StatefulWidget {
  final LandgrabApi api;
  final TestSession? testSession;
  const HomeRoute({super.key, required this.api, this.testSession});

  @override
  State<HomeRoute> createState() => _HomeRouteState();
}

class _HomeRouteState extends State<HomeRoute> {
  List<Pole>? _poles;
  List<Bathroom> _bathrooms = const [];
  String? _teamId;
  String? _teamName;
  String? _error;
  bool _isAuthor = false;
  bool _isValidator = false;
  bool _isSupervisor = false;
  LandgrabEvent? _event;

  LandgrabSocket? _socket;
  StreamSubscription<PoleUpdate>? _updatesSub;
  StreamSubscription<void>? _reconnectsSub;

  bool get _inTestPlay => widget.testSession != null;

  @override
  void initState() {
    super.initState();
    _load();
    // Real-time updates only flow for the real game. In a test session
    // we're isolated and don't need the socket.
    if (!_inTestPlay) _connectSocket();
  }

  Future<void> _connectSocket() async {
    final socket = LandgrabSocket(apiRoot: widget.api.dio.options.baseUrl);
    _socket = socket;
    _updatesSub = socket.updates.listen(_applyUpdate);
    _reconnectsSub = socket.reconnects.listen((_) => _load());
    await socket.connect();
  }

  void _applyUpdate(PoleUpdate update) {
    final list = _poles;
    if (list == null) return;
    final index = list.indexWhere((p) => p.id == update.id);
    if (index < 0) return;
    final old = list[index];
    final replaced = Pole(
      id: old.id,
      barcode: old.barcode,
      label: old.label,
      latitude: old.latitude,
      longitude: old.longitude,
      currentOwnerTeamId: update.currentOwnerTeamId,
      locked: update.locked,
    );
    if (!mounted) return;
    setState(() {
      _poles = [...list]..[index] = replaced;
    });
  }

  @override
  void dispose() {
    _updatesSub?.cancel();
    _reconnectsSub?.cancel();
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final teamId = await UserService.getTeamId();
      final teamName = await UserService.getTeamName();
      final isAuthor = await UserService.hasRole('author');
      final isValidator = await UserService.hasRole('validator');
      final isSupervisor = await UserService.hasRole('validation_supervisor');
      final results = await Future.wait([
        widget.api.getEvent(),
        widget.api.listPoles(),
        // Bathrooms are independent data — players see them all the time,
        // and they're cheap. Fetched in parallel with poles.
        widget.api.listBathrooms(),
      ]);
      final event = results[0] as LandgrabEvent;
      final poles = results[1] as List<Pole>;
      final bathrooms = results[2] as List<Bathroom>;
      if (!mounted) return;
      setState(() {
        _poles = poles;
        _bathrooms = bathrooms;
        _teamId = teamId;
        _teamName = teamName;
        _isAuthor = isAuthor;
        _isValidator = isValidator;
        _isSupervisor = isSupervisor;
        _event = event;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load poles: $e');
    }
  }

  Future<void> _logout() async {
    await widget.api.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LoginRoute(api: widget.api)),
    );
  }

  Future<void> _openScanner() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => ScanRoute(api: widget.api)),
    );
    if (scanned != null && mounted) _load();
  }

  Color _pinColor(Pole pole) {
    if (pole.locked) return Colors.grey;
    if (pole.currentOwnerTeamId == null) return Colors.blue;
    // Test-play is single-tester: any capture in the session was you,
    // so treat any owned pole as green rather than red (rival).
    if (_inTestPlay) return Colors.green;
    if (pole.currentOwnerTeamId == _teamId) return Colors.green;
    return Colors.red;
  }

  LatLng _center() {
    final list = _poles ?? const <Pole>[];
    if (list.isEmpty) return const LatLng(49.8951, -97.1384); // Portage and Main
    final lat = list.map((p) => p.latitude).reduce((a, b) => a + b) / list.length;
    final lng = list.map((p) => p.longitude).reduce((a, b) => a + b) / list.length;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final titleText = _teamName == null ? 'LNDGRB' : 'LNDGRB — $_teamName';
    // In test play we intentionally bypass the event-start gate — the
    // whole point of a rehearsal is to play before the event begins.
    final preEvent = !_inTestPlay && _event != null && !_event!.started;

    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder<bool>(
          valueListenable: EnvSwitchService.visible,
          builder: (context, envVisible, _) => envVisible
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(titleText),
                    Text(
                      '${F.title} · ${widget.api.dio.options.baseUrl}',
                      style: const TextStyle(fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                )
              : Text(titleText),
        ),
        actions: [
          if (!_inTestPlay && !preEvent && _isAuthor)
            IconButton(
              tooltip: 'Author',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AuthorRoute(api: widget.api)),
              ),
              icon: const Icon(Icons.edit_note),
            ),
          if (!_inTestPlay && !preEvent && _isValidator)
            IconButton(
              tooltip: 'Validate',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ValidatorRoute(api: widget.api)),
              ),
              icon: const Icon(Icons.fact_check_outlined),
            ),
          if (!_inTestPlay && !preEvent && _isSupervisor)
            IconButton(
              tooltip: 'Supervise',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SupervisorRoute(api: widget.api)),
              ),
              icon: const Icon(Icons.supervisor_account),
            ),
          if (!_inTestPlay && (_isValidator || _isSupervisor))
            IconButton(
              tooltip: 'Test play',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TestPlayEntryRoute(api: widget.api),
                ),
              ),
              icon: const Icon(Icons.science_outlined),
            ),
          if (!_inTestPlay)
            IconButton(
              tooltip: 'Details',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DetailsWebViewRoute(api: widget.api)),
              ),
              icon: const Icon(Icons.badge_outlined),
            ),
          if (!_inTestPlay)
            IconButton(
              tooltip: 'Credits',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreditsRoute()),
              ),
              icon: const Icon(Icons.info_outline),
            ),
          if (!_inTestPlay)
            ValueListenableBuilder<bool>(
              valueListenable: EnvSwitchService.visible,
              builder: (context, envVisible, _) => envVisible
                  ? IconButton(
                      tooltip: 'Settings',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsRoute()),
                      ),
                      icon: const Icon(Icons.settings_outlined),
                    )
                  : const SizedBox.shrink(),
            ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          if (_inTestPlay)
            IconButton(
              tooltip: 'Exit test play',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            )
          else
            IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
        bottom: _inTestPlay
            ? PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Container(
                  width: double.infinity,
                  color: Colors.amber.shade100,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.science_outlined,
                          size: 16, color: Colors.amber.shade900),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Test play · ${widget.testSession!.name ?? widget.testSession!.id}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : _poles == null || _event == null
              ? const Center(child: CircularProgressIndicator())
              : preEvent
                  ? _PreEventBody(
                      event: _event!,
                      isAuthor: _isAuthor,
                      isValidator: _isValidator,
                      isSupervisor: _isSupervisor,
                      onAuthor: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => AuthorRoute(api: widget.api)),
                      ),
                      onValidate: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ValidatorRoute(api: widget.api)),
                      ),
                      onSupervise: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => SupervisorRoute(api: widget.api)),
                      ),
                    )
                  : FlutterMap(
                  options: MapOptions(
                    initialCenter: _center(),
                    initialZoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      retinaMode: RetinaMode.isHighDensity(context),
                      userAgentPackageName: 'ca.chromatin.poles',
                    ),
                    // Territory fills sit above the tiles and below
                    // the marker pins so pole icons remain readable
                    // over their own coloured cells.
                    TerritoryLayer(
                      poles: _poles!,
                      myOwnerId: _teamId,
                      inTestPlay: _inTestPlay,
                    ),
                    BathroomLayer(bathrooms: _bathrooms),
                    MarkerLayer(
                      markers: _poles!.map((pole) {
                        return Marker(
                          point: LatLng(pole.latitude, pole.longitude),
                          width: 36,
                          height: 36,
                          child: Tooltip(
                            message: pole.label ?? pole.barcode,
                            child: Icon(Icons.location_on, color: _pinColor(pole), size: 36),
                          ),
                        );
                      }).toList(),
                    ),
                    const _MapAttribution(),
                    // Compass appears only when the map is rotated; tap
                    // animates it back to north-up. The plugin picks up the
                    // enclosing FlutterMap's controller via context — no
                    // controller wiring on our side.
                    const MapCompass.cupertino(hideIfRotatedNorth: true),
                  ],
                ),
      floatingActionButton: preEvent
          ? null
          : FloatingActionButton.extended(
              onPressed: _openScanner,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan'),
            ),
    );
  }
}

class _PreEventBody extends StatefulWidget {
  final LandgrabEvent event;
  final bool isAuthor;
  final bool isValidator;
  final bool isSupervisor;
  final VoidCallback onAuthor;
  final VoidCallback onValidate;
  final VoidCallback onSupervise;

  const _PreEventBody({
    required this.event,
    required this.isAuthor,
    required this.isValidator,
    required this.isSupervisor,
    required this.onAuthor,
    required this.onValidate,
    required this.onSupervise,
  });

  @override
  State<_PreEventBody> createState() => _PreEventBodyState();
}

class _PreEventBodyState extends State<_PreEventBody> {
  Timer? _ticker;
  String? _lastBarcode;
  String? _lastNfcUid;

  @override
  void initState() {
    super.initState();
    // Only run the countdown ticker when we have a target to count
    // down TO. If the event has no start time yet, the display shows
    // "not yet scheduled" and there's nothing to tick.
    if (widget.event.startTime != null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _openBarcodeScanner() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerRoute(title: 'Barcode toy'),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _lastBarcode = result);
  }

  Future<void> _openNfcScanner() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const NfcScannerRoute(title: 'NFC toy'),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _lastNfcUid = result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = widget.event.startTime;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (start == null)
              Text('Event not yet scheduled',
                  style: theme.textTheme.titleLarge)
            else
              _Countdown(startTime: start),
            const SizedBox(height: 12),
            Text(
              'Gameplay opens at start time. Until then, warm up.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (widget.isAuthor)
              _BigButton(
                icon: Icons.edit_note,
                label: 'Author',
                onPressed: widget.onAuthor,
              ),
            if (widget.isValidator) ...[
              const SizedBox(height: 12),
              _BigButton(
                icon: Icons.fact_check_outlined,
                label: 'Validate',
                onPressed: widget.onValidate,
              ),
            ],
            if (widget.isSupervisor) ...[
              const SizedBox(height: 12),
              _BigButton(
                icon: Icons.supervisor_account,
                label: 'Supervise',
                onPressed: widget.onSupervise,
              ),
            ],
            const SizedBox(height: 32),
            Text('Toys', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _ScannerTile(
              icon: Icons.qr_code_scanner,
              label: 'Barcode scanner',
              lastResult: _lastBarcode,
              onPressed: _openBarcodeScanner,
            ),
            const SizedBox(height: 8),
            _ScannerTile(
              icon: Icons.nfc,
              label: 'NFC scanner',
              lastResult: _lastNfcUid,
              onPressed: _openNfcScanner,
            ),
          ],
        ),
      ),
    );
  }
}

/// Live-updating countdown for the event start. Rebuilds each second
/// from the parent's ticker; hides its subtitle line once the
/// remaining duration crosses zero (server flips `started` at that
/// point and this whole widget is swapped out anyway).
class _Countdown extends StatelessWidget {
  final DateTime startTime;
  const _Countdown({required this.startTime});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = startTime.difference(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Event begins in',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
        const SizedBox(height: 4),
        Text(
          _formatRemaining(remaining),
          style: theme.textTheme.displaySmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(_formatStart(startTime),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
      ],
    );
  }

  /// "3d 14:22:07" when > 1 day away, "14:22:07" when < 1 day, and
  /// "starting now" once the remaining crosses zero (a transient
  /// state until the server flips `started`).
  static String _formatRemaining(Duration r) {
    if (r.isNegative || r.inSeconds == 0) return 'starting now';
    final days = r.inDays;
    final hours = r.inHours.remainder(24);
    final minutes = r.inMinutes.remainder(60);
    final seconds = r.inSeconds.remainder(60);
    final hhmmss =
        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    return days > 0 ? '${days}d $hhmmss' : hhmmss;
  }

  static String _formatStart(DateTime utc) {
    final local = utc.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

class _ScannerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? lastResult;
  final VoidCallback onPressed;

  const _ScannerTile({
    required this.icon,
    required this.label,
    required this.lastResult,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: lastResult == null
            ? Text('No scans yet — tap to try',
                style: theme.textTheme.bodySmall)
            : Text(
                'Last: $lastResult',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onPressed,
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _BigButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 32),
        label: Text(label, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}

class _MapAttribution extends StatelessWidget {
  const _MapAttribution();

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
