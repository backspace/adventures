import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/pole.dart';
import 'package:poles/models/poles_event.dart';
import 'package:poles/flavors.dart';
import 'package:poles/routes/author/author_route.dart';
import 'package:poles/routes/login_route.dart';
import 'package:poles/routes/scan_route.dart';
import 'package:poles/routes/settings_route.dart';
import 'package:poles/routes/supervisor/supervisor_route.dart';
import 'package:poles/routes/validator/validator_route.dart';
import 'package:poles/services/poles_socket.dart';
import 'package:poles/services/user_service.dart';

class HomeRoute extends StatefulWidget {
  final PolesApi api;
  const HomeRoute({super.key, required this.api});

  @override
  State<HomeRoute> createState() => _HomeRouteState();
}

class _HomeRouteState extends State<HomeRoute> {
  List<Pole>? _poles;
  String? _teamId;
  String? _teamName;
  String? _error;
  bool _isAuthor = false;
  bool _isValidator = false;
  bool _isSupervisor = false;
  PolesEvent? _event;

  PolesSocket? _socket;
  StreamSubscription<PoleUpdate>? _updatesSub;
  StreamSubscription<void>? _reconnectsSub;

  @override
  void initState() {
    super.initState();
    _load();
    _connectSocket();
  }

  Future<void> _connectSocket() async {
    final socket = PolesSocket(apiRoot: widget.api.dio.options.baseUrl);
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
      ]);
      final event = results[0] as PolesEvent;
      final poles = results[1] as List<Pole>;
      if (!mounted) return;
      setState(() {
        _poles = poles;
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
    final titleText = _teamName == null ? 'Poles' : 'Poles — $_teamName';
    final preEvent = _event != null && !_event!.started;

    return Scaffold(
      appBar: AppBar(
        title: F.allowsEnvSwitch
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
        actions: [
          if (!preEvent && _isAuthor)
            IconButton(
              tooltip: 'Author',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AuthorRoute(api: widget.api)),
              ),
              icon: const Icon(Icons.edit_note),
            ),
          if (!preEvent && _isValidator)
            IconButton(
              tooltip: 'Validate',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ValidatorRoute(api: widget.api)),
              ),
              icon: const Icon(Icons.fact_check_outlined),
            ),
          if (!preEvent && _isSupervisor)
            IconButton(
              tooltip: 'Supervise',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SupervisorRoute(api: widget.api)),
              ),
              icon: const Icon(Icons.supervisor_account),
            ),
          if (F.allowsEnvSwitch)
            IconButton(
              tooltip: 'Settings',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsRoute()),
              ),
              icon: const Icon(Icons.settings_outlined),
            ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
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

class _PreEventBody extends StatelessWidget {
  final PolesEvent event;
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headline = event.startTime == null
        ? 'Event not yet scheduled'
        : 'Event begins ${_formatStart(event.startTime!)}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(headline, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Gameplay opens at start time. Until then, finish preparing your poles and puzzlets.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (isAuthor)
              _BigButton(
                icon: Icons.edit_note,
                label: 'Author',
                onPressed: onAuthor,
              ),
            if (isValidator) ...[
              const SizedBox(height: 12),
              _BigButton(
                icon: Icons.fact_check_outlined,
                label: 'Validate',
                onPressed: onValidate,
              ),
            ],
            if (isSupervisor) ...[
              const SizedBox(height: 12),
              _BigButton(
                icon: Icons.supervisor_account,
                label: 'Supervise',
                onPressed: onSupervise,
              ),
            ],
            if (!isAuthor && !isValidator && !isSupervisor)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'No tasks for your role yet. Check back when the event begins.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      ),
    );
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
