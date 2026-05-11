import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/pole.dart';
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
      final poles = await widget.api.listPoles();
      if (!mounted) return;
      setState(() {
        _poles = poles;
        _teamId = teamId;
        _teamName = teamName;
        _isAuthor = isAuthor;
        _isValidator = isValidator;
        _isSupervisor = isSupervisor;
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
          if (_isAuthor)
            IconButton(
              tooltip: 'Author',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AuthorRoute(api: widget.api)),
              ),
              icon: const Icon(Icons.edit_note),
            ),
          if (_isValidator)
            IconButton(
              tooltip: 'Validate',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ValidatorRoute(api: widget.api)),
              ),
              icon: const Icon(Icons.fact_check_outlined),
            ),
          if (_isSupervisor)
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
          : _poles == null
              ? const Center(child: CircularProgressIndicator())
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openScanner,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan'),
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
