import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_compass/flutter_map_compass.dart';
import 'package:latlong2/latlong.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/bathroom.dart';
import 'package:landgrab/models/pole.dart';
import 'package:landgrab/models/landgrab_event.dart';
import 'package:landgrab/models/validator_only_puzzlet.dart';
import 'package:landgrab/l10n/player_strings.dart';
import 'package:landgrab/flavors.dart';
import 'package:landgrab/routes/author/author_route.dart';
import 'package:landgrab/routes/barcode_scanner_route.dart';
import 'package:landgrab/routes/credits_route.dart';
import 'package:landgrab/routes/details_webview_route.dart';
import 'package:landgrab/routes/login_route.dart';
import 'package:landgrab/routes/nfc_scanner_route.dart';
import 'package:landgrab/routes/notifications_route.dart';
import 'package:landgrab/routes/scan_route.dart';
import 'package:landgrab/routes/settings_route.dart';
import 'package:landgrab/routes/supervisor/supervisor_route.dart';
import 'package:landgrab/routes/validator/validator_route.dart';
import 'package:landgrab/services/env_switch_service.dart';
import 'package:landgrab/services/landgrab_socket.dart';
import 'package:landgrab/services/push_service.dart';
import 'package:landgrab/services/user_service.dart';
import 'package:landgrab/widgets/attack_rings_layer.dart';
import 'package:landgrab/widgets/bathroom_layer.dart';
import 'package:landgrab/widgets/capture_rings_layer.dart';
import 'package:landgrab/widgets/live_location_layer.dart';
import 'package:landgrab/widgets/territory_layer.dart';

/// Entries in the app bar's overflow menu. Role-gated tools and
/// occasional actions live here so the bar itself never overflows,
/// however many roles the signed-in user holds.
enum _HomeMenuItem {
  author,
  validate,
  supervise,
  details,
  credits,
  switchEnvironment,
  logOut,
}

class HomeRoute extends StatefulWidget {
  final LandgrabApi api;
  const HomeRoute({super.key, required this.api});

  @override
  State<HomeRoute> createState() => _HomeRouteState();
}

class _HomeRouteState extends State<HomeRoute>
    with TickerProviderStateMixin {
  List<Pole>? _poles;
  List<Bathroom> _bathrooms = const [];
  String? _teamId;
  String? _teamName;
  String? _error;
  bool _isAuthor = false;
  bool _isValidator = false;
  int _unreadNotifications = 0;
  List<ValidatorOnlyPuzzlet> _validatorOnlyPuzzlets = const [];
  // Camera zoom drives validator-only pin sizing — same treatment
  // poles get on the author map. Below _voTinyZoom they shrink to a
  // small star; above _voFullZoom they render at full size.
  double _mapZoom = 14;
  static const double _voFullZoom = 16;
  static const double _voTinyZoom = 13;
  static const double _voFullSize = 32;
  static const double _voTinySize = 10;
  bool _isSupervisor = false;
  LandgrabEvent? _event;

  LandgrabSocket? _socket;
  StreamSubscription<PoleUpdate>? _updatesSub;
  StreamSubscription<LandgrabNotification>? _notificationsSub;
  StreamSubscription<void>? _reconnectsSub;

  // Under-attack state. `_attackedPoleIds` drives the pulsing red
  // ring layer; expiry (10 min after the last attack signal on that
  // pole) is checked on each animation tick. The pulse phase runs
  // 0→1→0→… continuously via the same ticker that already exists
  // for capture animations, so we don't need a second ticker.
  static const Duration _attackExpiry = Duration(minutes: 10);
  static const Duration _pulseCycle = Duration(milliseconds: 1600);
  final Map<String, DateTime> _lastAttackAt = {};
  double _pulsePhase = 0;

  // Coordinated capture animation state. When a pole's owner
  // transitions to a new non-null value, we stamp `DateTime.now()`
  // into `_captureStartedAt`; the ticker drives frame-by-frame
  // rebuilds until every animation has passed [_captureAnimationDuration],
  // at which point the entry is purged and the ticker stops. Both
  // the ping ring and the territory disc-clip read this same map,
  // so they're guaranteed to run in lockstep.
  static const Duration _captureAnimationDuration =
      Duration(milliseconds: 800);
  final Map<String, DateTime> _captureStartedAt = {};
  final Map<String, String?> _prevOwners = {};
  Ticker? _animTicker;

  @override
  void initState() {
    super.initState();
    _load();
    _connectSocket();
    // Ask for push permission here — the player has just signed in
    // and landed on the map, so "get alerts about your poles" has
    // context. Fire-and-forget; PushService owns retries/rotation.
    PushService.register(widget.api);
  }

  Future<void> _connectSocket() async {
    final socket = LandgrabSocket(apiRoot: widget.api.dio.options.baseUrl);
    _socket = socket;
    _updatesSub = socket.updates.listen(_applyUpdate);
    _notificationsSub = socket.notifications.listen(_handleNotification);
    _reconnectsSub = socket.reconnects.listen((_) => _load());
    await socket.connect();
  }

  void _handleNotification(LandgrabNotification n) {
    // Recipient filter — everyone on landgrab:map sees every
    // notification, so each client scopes to its own team.
    if (n.recipientTeamId != _teamId) return;
    if (mounted) setState(() => _unreadNotifications += 1);
    if (n.type == 'attack') {
      final poleId = n.metadata['pole_id'] as String?;
      if (poleId == null) return;
      final isFirstAlert = !_lastAttackAt.containsKey(poleId);
      _lastAttackAt[poleId] = DateTime.now();
      _ensureAnimTicker();
      if (isFirstAlert && mounted) {
        // Only toast on the FIRST alert per pole per session — the
        // pulsing ring carries the ongoing state; a re-toast on
        // every follow-up scan would be nagging.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(n.body),
          backgroundColor: Colors.deepOrange.shade700,
          behavior: SnackBarBehavior.floating,
        ));
      }
      if (mounted) setState(() {});
    }
    if (n.type == 'pole_lost' && mounted) {
      // Losing a pole is significant and infrequent — always toast.
      // The map recolours via the pole_updated broadcast that
      // arrives alongside; this is the "why" for that change.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(n.body),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ));
    }
    // Future notification types (chat, etc.) get their own branches
    // here — or, once a notifications-history screen exists, hand
    // off to a shared inbox stream and drop this ad-hoc dispatch.
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
      _seedCaptureAnimations([replaced]);
      // A change of ownership on a pole retires any active attack
      // ring on it — either the attacker succeeded (defender loses
      // it anyway) or somebody recaptured, either way "under attack"
      // is stale.
      _lastAttackAt.remove(replaced.id);
      _poles = [...list]..[index] = replaced;
    });
  }

  @override
  void dispose() {
    _updatesSub?.cancel();
    _notificationsSub?.cancel();
    _reconnectsSub?.cancel();
    _socket?.dispose();
    _animTicker?.dispose();
    super.dispose();
  }

  /// Diff the incoming pole list against the last-seen owners and
  /// stamp a capture animation for any pole whose owner just became
  /// (or changed to) a non-null value. First observation of the pole
  /// set (`_prevOwners` empty) is silent — we don't fireworks over
  /// the initial load, only actual transitions.
  void _seedCaptureAnimations(Iterable<Pole> newPoles) {
    final wasCold = _prevOwners.isEmpty;
    for (final pole in newPoles) {
      final prev = _prevOwners[pole.id];
      final now = pole.currentOwnerTeamId;
      if (!wasCold && now != null && now != prev) {
        _captureStartedAt[pole.id] = DateTime.now();
      }
      _prevOwners[pole.id] = now;
    }
    if (_captureStartedAt.isNotEmpty) _ensureAnimTicker();
  }

  void _ensureAnimTicker() {
    if (_animTicker != null) return;
    _animTicker = createTicker(_onAnimTick);
    _animTicker!.start();
  }

  void _onAnimTick(Duration elapsed) {
    final now = DateTime.now();

    // Capture-ping expiries.
    final expiredCaptures = <String>[];
    for (final entry in _captureStartedAt.entries) {
      if (now.difference(entry.value) >= _captureAnimationDuration) {
        expiredCaptures.add(entry.key);
      }
    }
    for (final id in expiredCaptures) {
      _captureStartedAt.remove(id);
    }

    // Attack-ring expiries.
    final expiredAttacks = <String>[];
    for (final entry in _lastAttackAt.entries) {
      if (now.difference(entry.value) >= _attackExpiry) {
        expiredAttacks.add(entry.key);
      }
    }
    for (final id in expiredAttacks) {
      _lastAttackAt.remove(id);
    }

    // Ambient pulse for the attack rings — 0..1 loop.
    _pulsePhase =
        (elapsed.inMicroseconds / _pulseCycle.inMicroseconds) % 1.0;

    // Stop the ticker only when nothing on-screen needs animating.
    if (_captureStartedAt.isEmpty && _lastAttackAt.isEmpty) {
      _animTicker?.dispose();
      _animTicker = null;
    }
    if (mounted) setState(() {});
  }

  /// The app-bar refresh button: re-fetch identity (team, roles)
  /// from the server, then reload the map. Explicit refresh is the
  /// one place identity re-syncs without a re-login — so if the
  /// organiser assigns teams mid-session, "tap refresh" is the
  /// remedy to hand players. Automatic loads (boot, scanner return,
  /// socket reconnect) stay on cached identity to keep them fast.
  Future<void> _refreshIdentityAndLoad() async {
    try {
      await widget.api.loadAndStoreMe();
    } catch (_) {
      // Cached identity is still usable; _load's own fetches will
      // surface a real connectivity problem.
    }
    // Re-sends the push token if the signed-in user changed, so the
    // device follows the account (PushService no-ops otherwise).
    PushService.register(widget.api);
    if (mounted) await _load();
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
        // Validator-only puzzlets are only meaningful for
        // validators/supervisors; players see nothing. A 403 here
        // (server-gated) yields an empty list rather than a hard
        // failure — the map is usable without this layer.
        if (isValidator || isSupervisor)
          widget.api.listValidatorOnlyPuzzlets().catchError(
                (_) => <ValidatorOnlyPuzzlet>[],
              )
        else
          Future.value(<ValidatorOnlyPuzzlet>[]),
      ]);
      final event = results[0] as LandgrabEvent;
      final poles = results[1] as List<Pole>;
      final bathrooms = results[2] as List<Bathroom>;
      final validatorOnly = results[3] as List<ValidatorOnlyPuzzlet>;
      if (!mounted) return;
      setState(() {
        _seedCaptureAnimations(poles);
        _poles = poles;
        _bathrooms = bathrooms;
        _validatorOnlyPuzzlets = validatorOnly;
        _teamId = teamId;
        _teamName = teamName;
        _isAuthor = isAuthor;
        _isValidator = isValidator;
        _isSupervisor = isSupervisor;
        _event = event;
      });
      _refreshUnreadCount();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = GameplayStrings.couldNotLoadPoles(e.toString()));
    }
  }

  Future<void> _logout() async {
    await widget.api.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LoginRoute(api: widget.api)),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NotificationsRoute(api: widget.api)),
    );
    // The route marked everything read server-side on open.
    if (mounted) setState(() => _unreadNotifications = 0);
  }

  // Non-blocking: the badge count arriving late shouldn't delay the
  // map, and a failure just leaves the badge stale until next load.
  void _refreshUnreadCount() {
    widget.api.listNotifications().then((result) {
      if (mounted) setState(() => _unreadNotifications = result.unread);
    }).catchError((_) {});
  }

  PopupMenuItem<_HomeMenuItem> _menuItem(
      _HomeMenuItem value, IconData icon, String label) {
    return PopupMenuItem<_HomeMenuItem>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  void _onMenuSelected(_HomeMenuItem item) {
    switch (item) {
      case _HomeMenuItem.author:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AuthorRoute(api: widget.api)),
        );
      case _HomeMenuItem.validate:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ValidatorRoute(api: widget.api)),
        );
      case _HomeMenuItem.supervise:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SupervisorRoute(api: widget.api)),
        );
      case _HomeMenuItem.details:
        Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => DetailsWebViewRoute(api: widget.api)),
        );
      case _HomeMenuItem.credits:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreditsRoute()),
        );
      case _HomeMenuItem.switchEnvironment:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsRoute()),
        );
      case _HomeMenuItem.logOut:
        _logout();
    }
  }

  Future<void> _openScanner() async {
    final result = await Navigator.of(context).push<ScanRouteResult>(
      MaterialPageRoute(builder: (_) => ScanRoute(api: widget.api)),
    );
    if (result == null || !mounted) return;
    await _load();
    // If the scan flow ended in a capture, replay the territory
    // animation for that pole now that the map is visible again. The
    // socket's pole_updated broadcast fired while the player was
    // still on the puzzlet screen, so its 800 ms animation played
    // (and expired) unseen behind the navigation stack.
    final capturedPoleId = result.capturedPoleId;
    if (capturedPoleId != null && mounted) {
      setState(() => _captureStartedAt[capturedPoleId] = DateTime.now());
      _ensureAnimTicker();
    }
  }

  Color _pinColor(Pole pole) {
    if (pole.locked) return Colors.grey;
    if (pole.currentOwnerTeamId == null) return Colors.blue;
    if (pole.currentOwnerTeamId == _teamId) return Colors.green;
    return Colors.red;
  }

  double get _voSize {
    if (_mapZoom >= _voFullZoom) return _voFullSize;
    if (_mapZoom <= _voTinyZoom) return _voTinySize;
    final t =
        (_mapZoom - _voTinyZoom) / (_voFullZoom - _voTinyZoom);
    return _voTinySize + (_voFullSize - _voTinySize) * t;
  }

  List<Marker> _validatorOnlyMarkers() {
    final size = _voSize;
    return [
      for (final p in _validatorOnlyPuzzlets)
        Marker(
          point: LatLng(p.latitude, p.longitude),
          width: size,
          height: size,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showValidatorOnlySheet(p),
            child: Tooltip(
              message: p.instructions.length > 40
                  ? '${p.instructions.substring(0, 40)}…'
                  : p.instructions,
              child: _ValidatorOnlyStar(size: size),
            ),
          ),
        ),
    ];
  }

  void _showValidatorOnlySheet(ValidatorOnlyPuzzlet p) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const _ValidatorOnlyStar(size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Puzzlet · difficulty ${p.difficulty}',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text('Validators only · status: ${p.status}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                const SizedBox(height: 16),
                Text(p.instructions, style: theme.textTheme.bodyLarge),
                if (p.warning != null && p.warning!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_outlined, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(p.warning!)),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
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
    final preEvent = _event != null && !_event!.started;

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
          IconButton(
            tooltip: GameplayStrings.notificationsTooltip,
            onPressed: _openNotifications,
            icon: Badge.count(
              count: _unreadNotifications,
              isLabelVisible: _unreadNotifications > 0,
              child: const Icon(Icons.notifications_none),
            ),
          ),
          IconButton(
            tooltip: GameplayStrings.refresh,
            onPressed: _refreshIdentityAndLoad,
            icon: const Icon(Icons.refresh),
          ),
          // Everything else lives in one menu so the bar never
          // overflows for people holding several roles.
          PopupMenuButton<_HomeMenuItem>(
            tooltip: GameplayStrings.menuTooltip,
            onSelected: _onMenuSelected,
            itemBuilder: (context) => [
              if (!preEvent && _isAuthor)
                _menuItem(_HomeMenuItem.author, Icons.edit_note,
                    GameplayStrings.author),
              if (!preEvent && _isValidator)
                _menuItem(_HomeMenuItem.validate, Icons.fact_check_outlined,
                    GameplayStrings.validate),
              if (!preEvent && _isSupervisor)
                _menuItem(_HomeMenuItem.supervise, Icons.supervisor_account,
                    GameplayStrings.supervise),
              _menuItem(_HomeMenuItem.details, Icons.badge_outlined,
                  GameplayStrings.details),
              _menuItem(_HomeMenuItem.credits, Icons.info_outline,
                  GameplayStrings.credits),
              // Read directly instead of via ValueListenableBuilder:
              // itemBuilder runs on every open, so it's always fresh.
              if (EnvSwitchService.visible.value)
                _menuItem(_HomeMenuItem.switchEnvironment, Icons.dns_outlined,
                    LoginStrings.switchEnvironmentTooltip),
              _menuItem(
                  _HomeMenuItem.logOut, Icons.logout, GameplayStrings.logOut),
            ],
          ),
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
                    // Track camera zoom for size-scaled overlays
                    // (validator-only puzzlet pins). Only setState
                    // when the zoom actually changes so panning
                    // doesn't force a rebuild every frame.
                    onPositionChanged: (position, _) {
                      final z = position.zoom;
                      if (z != null && z != _mapZoom) {
                        setState(() => _mapZoom = z);
                      }
                    },
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
                      captureStartedAt: _captureStartedAt,
                      captureAnimationDuration: _captureAnimationDuration,
                    ),
                    BathroomLayer(bathrooms: _bathrooms),
                    CaptureRingsLayer(
                      poles: _poles!,
                      captureStartedAt: _captureStartedAt,
                      duration: _captureAnimationDuration,
                      myOwnerId: _teamId,
                    ),
                    AttackRingsLayer(
                      poles: _poles!,
                      attackedPoleIds: _lastAttackAt.keys.toSet(),
                      pulsePhase: _pulsePhase,
                    ),
                    MarkerLayer(
                      markers: _poles!.map((pole) {
                        return Marker(
                          point: LatLng(pole.latitude, pole.longitude),
                          width: 24,
                          height: 24,
                          child: Tooltip(
                            message: pole.label ?? pole.barcode,
                            child: _PoleDot(color: _pinColor(pole)),
                          ),
                        );
                      }).toList(),
                    ),
                    // Validator-only puzzlets: rendered outside the
                    // pole/cluster stack so they never spider with
                    // other markers, and sized against the current
                    // zoom so they shrink to a small star far out and
                    // grow to full pin close in — same treatment
                    // poles get on the author map.
                    if (_validatorOnlyPuzzlets.isNotEmpty)
                      MarkerLayer(markers: _validatorOnlyMarkers()),
                    // User's own position + heading cone (only while
                    // walking). Above the pole markers so a pole
                    // directly under the user doesn't obscure the
                    // marker; below attribution/compass.
                    const LiveLocationLayer(),
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
              label: const Text(GameplayStrings.scanFab),
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
        builder: (_) => const BarcodeScannerRoute(title: PreEventStrings.barcodeToyTitle),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _lastBarcode = result);
  }

  Future<void> _openNfcScanner() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const NfcScannerRoute(title: PreEventStrings.nfcToyTitle),
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
              Text(PreEventStrings.notYetScheduled,
                  style: theme.textTheme.titleLarge)
            else
              _Countdown(startTime: start),
            const SizedBox(height: 12),
            Text(
              PreEventStrings.openingCopy,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (widget.isAuthor)
              _BigButton(
                icon: Icons.edit_note,
                label: GameplayStrings.author,
                onPressed: widget.onAuthor,
              ),
            if (widget.isValidator) ...[
              const SizedBox(height: 12),
              _BigButton(
                icon: Icons.fact_check_outlined,
                label: GameplayStrings.validate,
                onPressed: widget.onValidate,
              ),
            ],
            if (widget.isSupervisor) ...[
              const SizedBox(height: 12),
              _BigButton(
                icon: Icons.supervisor_account,
                label: GameplayStrings.supervise,
                onPressed: widget.onSupervise,
              ),
            ],
            const SizedBox(height: 32),
            Text(PreEventStrings.toysHeading, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _ScannerTile(
              icon: Icons.qr_code_scanner,
              label: PreEventStrings.barcodeToyLabel,
              lastResult: _lastBarcode,
              onPressed: _openBarcodeScanner,
            ),
            const SizedBox(height: 8),
            _ScannerTile(
              icon: Icons.nfc,
              label: PreEventStrings.nfcToyLabel,
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
        Text(PreEventStrings.countdownHeading,
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
    if (r.isNegative || r.inSeconds == 0) return PreEventStrings.startingNow;
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
            ? Text(PreEventStrings.noScansYet,
                style: theme.textTheme.bodySmall)
            : Text(
                PreEventStrings.lastScan(lastResult!),
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onPressed,
      ),
    );
  }
}

/// Matches the site's `.landgrab-pole` visual: a filled circle with a
/// stroke lightened toward white so dark colours (black especially)
/// still read against the map. Colour transitions ease over 200 ms to
/// match the site's `transition: fill 200ms ease-out, stroke 200ms
/// ease-out` rule, so a capture flip reads as a gradient rather than
/// a hard cut.
class _PoleDot extends StatelessWidget {
  final Color color;
  const _PoleDot({required this.color});

  @override
  Widget build(BuildContext context) {
    // `color-mix(fill 55%, white 45%)` on the site becomes
    // Color.lerp(fill, white, 0.45) here — same shape, same lift.
    final borderColor = Color.lerp(color, Colors.white, 0.45)!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: borderColor.withValues(alpha: 0.65),
          width: 1.5,
        ),
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

/// The starred puzzlet marker for validator-only content. Amber
/// star on a white disc for legibility against the light basemap.
/// Scales its inner icon proportionally so at very small sizes the
/// star still reads as a star rather than a formless dot.
class _ValidatorOnlyStar extends StatelessWidget {
  final double size;
  const _ValidatorOnlyStar({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.amber.shade700, width: size >= 20 ? 2 : 1),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1)),
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
