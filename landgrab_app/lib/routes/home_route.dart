import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:landgrab/widgets/landgrab_tile_layer.dart';
import 'package:flutter_map_compass/flutter_map_compass.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
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
import 'package:landgrab/routes/join_team_route.dart';
import 'package:landgrab/routes/login_route.dart';
import 'package:landgrab/routes/nfc_scanner_route.dart';
import 'package:landgrab/routes/notifications_route.dart';
import 'package:landgrab/routes/puzzlet_route.dart';
import 'package:landgrab/routes/scan_route.dart';
import 'package:landgrab/routes/settings_route.dart';
import 'package:landgrab/routes/supervisor/supervisor_route.dart';
import 'package:landgrab/routes/validator/validator_route.dart';
import 'package:landgrab/services/env_switch_service.dart';
import 'package:landgrab/services/landgrab_socket.dart';
import 'package:landgrab/services/location_service.dart';
import 'package:landgrab/services/push_service.dart';
import 'package:landgrab/services/ui_preferences.dart';
import 'package:landgrab/services/block_territory_service.dart';
import 'package:landgrab/services/user_service.dart';
import 'package:landgrab/widgets/accent_colors.dart';
import 'package:landgrab/widgets/attack_rings_layer.dart';
import 'package:landgrab/widgets/bathroom_layer.dart';
import 'package:landgrab/widgets/block_territory_layer.dart';
import 'package:landgrab/widgets/capture_rings_layer.dart';
import 'package:landgrab/widgets/highlight_reticle.dart';
import 'package:landgrab/widgets/liberated_zone_layer.dart';
import 'package:landgrab/widgets/liberated_zone_tuner.dart';
import 'package:landgrab/widgets/live_location_layer.dart';
import 'package:landgrab/widgets/precomputed_territory_layer.dart';
import 'package:landgrab/widgets/region_context_card.dart';
import 'package:landgrab/widgets/team_style.dart';
import 'package:landgrab/widgets/territory_layer.dart';

/// Entries in the app bar's overflow menu. Role-gated tools and
/// occasional actions live here so the bar itself never overflows,
/// however many roles the signed-in user holds.
enum _HomeMenuItem {
  author,
  validate,
  supervise,
  joinTeam,
  details,
  credits,
  settings,
  logOut,
}

class HomeRoute extends StatefulWidget {
  final LandgrabApi api;
  const HomeRoute({super.key, required this.api});

  @override
  State<HomeRoute> createState() => _HomeRouteState();
}

class _HomeRouteState extends State<HomeRoute> with TickerProviderStateMixin {
  List<Pole>? _poles;
  List<Bathroom> _bathrooms = const [];
  // EXPERIMENT: street-aware territory. Pre-computed city blocks, loaded once
  // from a bundled asset if present; null → fall back to the Voronoi
  // TerritoryLayer. See landgrab-street-aware-territory.md.
  List<TerritoryBlock>? _territoryBlocks;
  // EXPERIMENT step 1: puzzlet locations (pole id → points), local-only asset,
  // so a pole's territory can extend into its puzzlets' blocks.
  Map<String, List<LatLng>>? _puzzletPoints;
  // EXPERIMENT: pre-dissolved per-pole territory shapes (from
  // assign_territory.py). When present, supersedes the live block path — one
  // shape per pole, used for both drawing and tap. See
  // landgrab-street-aware-territory.md.
  List<TerritoryRegion>? _territory;
  // PROTOTYPE: liberated-zone look (moving hatch over freed ground). Style is
  // dev-tunable via LiberatedZoneTuner; _liberatedPreview lets the tuner treat
  // N owned zones as liberated so the effect is visible without running a real
  // liberation. Both no-ops in normal builds.
  LiberatedZoneStyle _liberatedStyle = const LiberatedZoneStyle();
  int _liberatedPreview = 0;
  String? _teamId;
  String? _teamName;
  // The team's stable colour index from /me, so its swatch shows beside the
  // name from launch — before it owns any zone (independent of captures).
  int? _myColorIndex;
  String? _error;
  // Surfaced under "Log out" so the account you're signed in as is always
  // visible — not just for the dev account-switcher audience.
  String? _accountEmail;
  bool _isAuthor = false;
  bool _isValidator = false;
  int _unreadNotifications = 0;
  // The team's active puzzlet(s) — "in progress", resumable without a
  // rescan, shared across teammates. Refetched on load / refresh /
  // reconnect and when the team_puzzlets_changed socket event fires.
  List<ScanResult> _activePuzzlets = const [];
  List<ValidatorOnlyPuzzlet> _validatorOnlyPuzzlets = const [];
  // Camera zoom drives validator-only pin sizing — same treatment
  // poles get on the author map. Below _voTinyZoom they shrink to a
  // small star; above _voFullZoom they render at full size.
  double _mapZoom = 14;
  final MapController _mapController = MapController();
  // "Locate me" in flight — disables the button and shows a spinner.
  bool _locating = false;
  // True while the notifications list is on the stack, so a second "View"
  // (e.g. from a toast that arrived while the list is open) refreshes the
  // existing list rather than pushing another copy on top.
  bool _notificationsOpen = false;
  // Hide stakes flagged prohibitive (nothing the team can engage) from the map.
  // Persisted; the toggle only appears when there's at least one such stake.
  bool _hideProhibitive = false;
  // The stake a notification's "View on map" jumped to. Draws a transient
  // marching-ants reticle around it (cleared after a few seconds) so it's
  // unmistakable which one. Matches the TerritoryLayer radius.
  static const double _zoneRadiusMeters = 200;
  // Forgiving tap radius (logical px) around a pole pin. A pole can sit
  // outside its own region (by design), so a tap this close to one names
  // the stake rather than whatever zone the pin happens to overlap. Larger
  // than the 12 px pin so a near-miss still lands.
  static const double _poleTapSlopPx = 22;
  String? _highlightedPoleId;
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
  StreamSubscription<String>? _teamPuzzletsSub;

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
  static const Duration _captureAnimationDuration = Duration(milliseconds: 800);
  final Map<String, DateTime> _captureStartedAt = {};
  final Map<String, String?> _prevOwners = {};
  final Map<String, String?> _captureFromOwner = {};

  // team_id → colour index, accumulated from pole payloads and never
  // forgotten — so a just-deposed team still styles correctly during the
  //800 ms capture animation. Passed to TerritoryLayer.
  final Map<String, int> _teamColorIndex = {};

  void _rememberTeamColors(Iterable<Pole> poles) {
    for (final p in poles) {
      final id = p.currentOwnerTeamId;
      final idx = p.currentOwnerColorIndex;
      if (id != null && idx != null) _teamColorIndex[id] = idx;
    }
  }

  // Re-filters pole pins as the (invisible) endgame boundary
  // shrinks past them. 10 s granularity is plenty: the shrink runs
  // over tens of minutes.
  Timer? _zoneTimer;
  Ticker? _animTicker;

  @override
  void initState() {
    super.initState();
    _loadTerritoryBlocks();
    _load();
    _connectSocket();
    UiPreferences.getHideProhibitive().then((v) {
      if (mounted && v) setState(() => _hideProhibitive = v);
    });
    // Ask for push permission here — the player has just signed in
    // and landed on the map, so "get alerts about your poles" has
    // context. Fire-and-forget; PushService owns retries/rotation.
    PushService.register(widget.api);
  }

  // EXPERIMENT: load pre-computed street blocks once. Absent asset → stays
  // null and the map keeps using the Voronoi TerritoryLayer.
  Future<void> _loadTerritoryBlocks() async {
    final territory = await BlockTerritoryService.loadTerritory();
    final blocks = await BlockTerritoryService.load();
    final puzzletPoints = await BlockTerritoryService.loadPuzzletPoints();
    if (mounted &&
        (territory != null || blocks != null || puzzletPoints != null)) {
      setState(() {
        _territory = territory;
        _territoryBlocks = blocks;
        _puzzletPoints = puzzletPoints;
      });
    }
  }

  Future<void> _connectSocket() async {
    final socket = LandgrabSocket(apiRoot: widget.api.dio.options.baseUrl);
    _socket = socket;
    _updatesSub = socket.updates.listen(_applyUpdate);
    _notificationsSub = socket.notifications.listen(_handleNotification);
    _reconnectsSub = socket.reconnects.listen((_) => _load());
    // A teammate scanned/gave up, or a puzzlet resolved — refetch our
    // in-progress list so every member's screen stays in sync.
    _teamPuzzletsSub = socket.teamPuzzletsChanged.listen((teamId) {
      if (teamId == _teamId) _refreshActivePuzzlets();
    });
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
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: GameplayStrings.viewOnMap,
            textColor: Colors.white,
            onPressed: () => _focusPole(poleId),
          ),
        ));
      }
      if (mounted) setState(() {});
    }
    if (n.type == 'pole_lost' && mounted) {
      // Losing a pole is significant and infrequent — always toast.
      // The map recolours via the pole_updated broadcast that
      // arrives alongside; this is the "why" for that change.
      final poleId = n.metadata['pole_id'] as String?;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(n.body),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: poleId == null
            ? null
            : SnackBarAction(
                label: GameplayStrings.viewOnMap,
                textColor: Colors.white,
                onPressed: () => _focusPole(poleId),
              ),
      ));
    }
    if (n.type == 'message' && mounted) {
      // Storyline broadcast from the organisers — neutral styling so
      // it reads as narrative, not alarm. Sender name from metadata
      // (Sabuk / Sabuk's assistant).
      final sender = n.metadata['sender_name'] as String?;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(sender == null ? n.body : '$sender: ${n.body}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
      ));
    }
    if (n.type == 'liberation_invite' && mounted) {
      // Bedab's invitation — narrative styling like 'message', but with
      // a route to the history screen, where the accept/decline pair
      // lives. Long duration: it's a question, not a status.
      final sender = n.metadata['sender_name'] as String?;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(sender == null ? n.body : '$sender: ${n.body}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 12),
        action: SnackBarAction(
          label: NotificationStrings.inviteRespondAction,
          onPressed: _openNotifications,
        ),
      ));
    }
    if ((n.type == 'puzzlet_taken' || n.type == 'puzzlet_withdrawn') &&
        mounted) {
      // A rival solved the puzzlet we were on, or a supervisor withdrew it
      // from the game. Either way our active-puzzlet state clears via the
      // team_puzzlets_changed broadcast; here we just tell them (the body
      // comes from the server) and offer the pole's next puzzlet (no
      // rescan) when one remains.
      _refreshActivePuzzlets();
      final poleId = n.metadata['pole_id'] as String?;
      final hasNext = n.metadata['has_next'] == true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(n.body),
        backgroundColor: Colors.deepOrange.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: (hasNext && poleId != null)
            ? SnackBarAction(
                label: GameplayStrings.puzzletTakenTryNext,
                textColor: Colors.white,
                onPressed: () => _tryNextPuzzlet(poleId),
              )
            : null,
      ));
    }
    if (n.type == 'pole_contested' && mounted) {
      // A rival just started working a pole we're on. Informational,
      // blue styling — a race is on, but nothing's lost yet. Refetch
      // so the in-progress card's "others here" count updates.
      _refreshActivePuzzlets();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(n.body),
        backgroundColor: Colors.blue.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ));
    }
    // Future notification types (chat, etc.) get their own branches
    // here — or, once a notifications-history screen exists, hand
    // off to a shared inbox stream and drop this ad-hoc dispatch.
  }

  /// Centres the map on a stake — from a notification's "View on map" action
  /// (live toast or the history list). If the stake isn't currently on the map
  /// (poles not loaded yet, or the endgame boundary has passed it) a gentle
  /// notice replaces a silent no-op.
  void _focusPole(String poleId) {
    final poles = _poles;
    final idx = poles == null ? -1 : poles.indexWhere((p) => p.id == poleId);
    if (idx < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(GameplayStrings.zoneNotOnMap),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    final pole = poles![idx];
    _mapController.move(
      LatLng(pole.latitude, pole.longitude),
      _framingZoom(pole.latitude),
    );
    // Flag it highlighted, run the pulse ticker so the reticle marches, and
    // clear after a few seconds so it doesn't linger.
    setState(() => _highlightedPoleId = poleId);
    _ensureAnimTicker();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _highlightedPoleId == poleId) {
        setState(() => _highlightedPoleId = null);
      }
    });
  }

  /// A zoom that frames a stake's ~200 m zone at a consistent fraction of the
  /// viewport, so "View on map" always lands close enough to make it out
  /// (clamped so it neither over- nor under-zooms).
  double _framingZoom(double lat) {
    final size = MediaQuery.of(context).size;
    final shortest = math.min(size.width, size.height);
    if (shortest <= 0) return 17;
    // Target: the zone radius occupies ~35% of the shorter side.
    final metersPerPixel = _zoneRadiusMeters / (0.35 * shortest);
    final z = math.log(
              156543.03392 * math.cos(lat * math.pi / 180) / metersPerPixel) /
          math.ln2;
    return z.clamp(15.0, 18.0);
  }

  void _applyUpdate(PoleUpdate update) {
    final list = _poles;
    if (list == null) return;
    final index = list.indexWhere((p) => p.id == update.id);
    if (index < 0) return;
    final old = list[index];
    final replaced = Pole(
      id: old.id,
      name: old.name,
      latitude: old.latitude,
      longitude: old.longitude,
      currentOwnerTeamId: update.currentOwnerTeamId,
      currentOwnerTeamName: update.currentOwnerTeamName,
      currentOwnerColorIndex: update.currentOwnerColorIndex,
      locked: update.locked,
      liberated: update.liberated,
      // The owner-change broadcast is team-agnostic and carries no prohibitive
      // flag; keep the value from the last pole-list fetch. A full reload
      // (reconnect / event change) refreshes it authoritatively.
      prohibitive: old.prohibitive,
    );
    _rememberTeamColors([replaced]);
    if (!mounted) return;
    // A liberation lands here as owner→null + liberated: keep the ambient
    // ticker running so its hatch drifts.
    if (replaced.liberated) _ensureAnimTicker();
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
    _teamPuzzletsSub?.cancel();
    _socket?.dispose();
    _animTicker?.dispose();
    _zoneTimer?.cancel();
    _mapController.dispose();
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
        // Remembered past the animation's expiry (only overwritten by
        // the next transition) so the scanner-return replay can still
        // paint the deposed team's fill under the expanding disc.
        _captureFromOwner[pole.id] = prev;
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
    _pulsePhase = (elapsed.inMicroseconds / _pulseCycle.inMicroseconds) % 1.0;

    // Stop the ticker only when nothing on-screen needs animating —
    // liberated zones keep it alive so their hatch keeps drifting.
    if (_captureStartedAt.isEmpty &&
        _lastAttackAt.isEmpty &&
        _highlightedPoleId == null &&
        !_anyLiberated()) {
      _animTicker?.dispose();
      _animTicker = null;
    }
    if (mounted) setState(() {});
  }

  // PROTOTYPE: is there anything for the liberated-zone layer to animate?
  // Real liberated poles, or (dev) the tuner's preview count.
  bool _anyLiberated() =>
      _liberatedPreview > 0 || (_poles?.any((p) => p.liberated) ?? false);

  // The liberated zones to paint, drawn from whichever territory geometry is
  // active (precomputed per-pole regions preferred; live blocks otherwise).
  // Includes the tuner's preview poles so the look is visible without a real
  // liberation.
  List<LiberatedShape> _liberatedShapes() {
    final poles = _poles;
    if (poles == null || !_anyLiberated()) return const [];

    final ids = <String>{};
    for (final p in poles) {
      if (p.liberated) ids.add(p.id);
    }
    if (_liberatedPreview > 0) {
      for (final p in poles) {
        if (ids.length >= _liberatedPreview) break;
        if (p.currentOwnerTeamId != null && !p.liberated) ids.add(p.id);
      }
    }
    if (ids.isEmpty) return const [];

    final regions = _territory;
    if (regions != null) {
      return [
        for (final r in regions)
          if (ids.contains(r.poleId))
            LiberatedShape(ring: r.ring, holes: r.holes),
      ];
    }
    final blocks = _territoryBlocks;
    if (blocks != null) {
      final out = <LiberatedShape>[];
      for (final p in poles) {
        if (!ids.contains(p.id)) continue;
        final ring = _blockRingForPole(p, blocks);
        if (ring != null) out.add(LiberatedShape(ring: ring));
      }
      return out;
    }
    return const [];
  }

  // A pole's home block: the block it stands in, else the nearest centroid
  // within ~300 m (mirrors BlockTerritoryLayer's assignment closely enough
  // for a look-test; the shipped version should share that layer's exact
  // assignment rather than re-derive it).
  List<LatLng>? _blockRingForPole(Pole pole, List<TerritoryBlock> blocks) {
    final at = LatLng(pole.latitude, pole.longitude);
    final perDegLon = 111000.0 * math.cos(pole.latitude * math.pi / 180);
    List<LatLng>? near;
    var nearD = double.infinity;
    for (final b in blocks) {
      if (_ringContains(b.ring, at)) return b.ring;
      final dx = (b.centroid.longitude - pole.longitude) * perDegLon;
      final dy = (b.centroid.latitude - pole.latitude) * 111000.0;
      final d = dx * dx + dy * dy;
      if (d < nearD) {
        nearD = d;
        near = b.ring;
      }
    }
    return nearD <= 300 * 300 ? near : null;
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
      final teamColorIndex = await UserService.getTeamColorIndex();
      final isAuthor = await UserService.hasRole('author');
      final isValidator = await UserService.hasRole('validator');
      final isSupervisor = await UserService.hasRole('validation_supervisor');
      final accountEmail = await UserService.getUserEmail();
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
      _rememberTeamColors(poles);
      if (!mounted) return;
      setState(() {
        _seedCaptureAnimations(poles);
        _poles = poles;
        _bathrooms = bathrooms;
        _validatorOnlyPuzzlets = validatorOnly;
        _teamId = teamId;
        _teamName = teamName;
        _myColorIndex = teamColorIndex;
        _isAuthor = isAuthor;
        _isValidator = isValidator;
        _isSupervisor = isSupervisor;
        _accountEmail = accountEmail;
        _event = event;
      });
      // Poles may arrive already liberated (app reopened mid-phase) — start
      // the ambient ticker so the hatch drifts from first paint.
      if (_anyLiberated()) _ensureAnimTicker();
      _refreshUnreadCount();
      _refreshActivePuzzlets();
      if (event.endgame != null && _zoneTimer == null) {
        _zoneTimer = Timer.periodic(const Duration(seconds: 10), (_) {
          if (mounted) setState(() {});
        });
      }
    } catch (e, st) {
      // Report to Sentry as well as showing the message. This is a *handled*
      // error, so it'd otherwise be invisible there — and it's exactly the
      // surface a server/client compat break shows up on ("could not load
      // stakes"), so we want it tracked, not just displayed.
      unawaited(Sentry.captureException(e, stackTrace: st));
      if (!mounted) return;
      setState(() => _error = GameplayStrings.couldNotLoadPoles(e.toString()));
    }
  }

  // Non-blocking: the in-progress list arriving late shouldn't hold up
  // the map; a failure just leaves it stale until the next refresh.
  void _refreshActivePuzzlets() {
    widget.api.listActivePuzzlets().then((active) {
      if (mounted) setState(() => _activePuzzlets = active);
    }).catchError((_) {});
  }

  Future<void> _logout() async {
    await widget.api.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LoginRoute(api: widget.api)),
    );
  }

  Future<void> _openJoinTeam() async {
    final joined = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => JoinTeamRoute(api: widget.api)),
    );
    // Refresh so the new team name shows in the title (and anything
    // team-gated re-evaluates).
    if (joined == true && mounted) await _load();
  }

  Future<void> _openDetails() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailsWebViewRoute(api: widget.api)),
    );
    // Editing details in the WebView (accessibility choices, team info) can
    // change what the map should show, but the WebView is opaque so we can't
    // tell whether anything changed. Re-fetch identity and reload on return —
    // exactly what the refresh button does — so any change is reflected.
    if (mounted) await _refreshIdentityAndLoad();
  }

  // Prompt shown above the map/pre-event body when a signed-in player
  // isn't on a team yet — the common case for day-of walk-ups.
  Widget _noTeamBanner() {
    return MaterialBanner(
      content: const Text(JoinTeamStrings.noTeamPrompt),
      leading: const Icon(Icons.group_add_outlined),
      actions: [
        TextButton(
          onPressed: _openJoinTeam,
          child: const Text(JoinTeamStrings.appBarTitle),
        ),
      ],
    );
  }

  /// Poles the endgame boundary hasn't passed. Everything when no
  /// boundary is configured or it hasn't begun shrinking.
  List<Pole> _polesInPlay() {
    Iterable<Pole> poles = _poles!;
    // Optional declutter: drop stakes the whole team can't engage.
    if (_hideProhibitive) poles = poles.where((p) => !p.prohibitive);
    final zone = _event?.endgame;
    final now = DateTime.now().toUtc();
    if (zone != null && zone.activeAt(now)) {
      poles = poles
          .where((pole) => zone.containsAt(pole.latitude, pole.longitude, now));
    }
    return poles.toList(growable: false);
  }

  // How many loaded stakes are flagged prohibitive — gates the hide toggle so
  // it only appears for a team that actually has inaccessible stakes.
  int get _prohibitiveCount =>
      _poles?.where((p) => p.prohibitive).length ?? 0;

  Future<void> _openNotifications() async {
    // Dismiss the "N while you were away" catch-up toast — they're
    // acting on it by opening the list, so it shouldn't linger behind
    // the screen and reappear on return. (Tapping its own "View"
    // action clears it automatically; opening via the bell doesn't.)
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    // Already viewing the list (a toast's "View" tapped while it's open) —
    // don't stack a second copy. The open list live-refreshes from the socket
    // stream, so it's already current.
    if (_notificationsOpen) return;
    _notificationsOpen = true;
    final focusPoleId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => NotificationsRoute(
          api: widget.api,
          incoming: _socket?.notifications,
        ),
      ),
    );
    _notificationsOpen = false;
    if (!mounted) return;
    // "View on map" in the list pops with the stake's id — centre on it.
    if (focusPoleId != null) _focusPole(focusPoleId);
    // Opening marks everything read, but the player may have swiped
    // some back to unread — so reflect the real count rather than
    // assuming zero. Quiet fetch (no "while away" toast).
    widget.api.listNotifications().then((result) {
      if (mounted) setState(() => _unreadNotifications = result.unread);
    }).catchError((_) {
      if (mounted) setState(() => _unreadNotifications = 0);
    });
  }

  // Non-blocking: the badge count arriving late shouldn't delay the
  // map, and a failure just leaves the badge stale until next load.
  void _refreshUnreadCount() {
    widget.api.listNotifications().then((result) {
      if (!mounted) return;
      // Unread grew beyond what live socket handling counted, so the
      // extras happened while this app wasn't connected (cold boot,
      // backgrounded, socket blip) — surface them. Live arrivals
      // increment _unreadNotifications before this fetch runs, so
      // they never re-toast here.
      final missed = result.unread - _unreadNotifications;
      setState(() => _unreadNotifications = result.unread);
      if (missed > 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(NotificationStrings.whileAway(missed)),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: NotificationStrings.viewAction,
            onPressed: _openNotifications,
          ),
        ));
      }
    }).catchError((_) {});
  }

  PopupMenuItem<_HomeMenuItem> _menuItem(
      _HomeMenuItem value, IconData icon, String label,
      {String? subtitle}) {
    return PopupMenuItem<_HomeMenuItem>(
      value: value,
      child: Row(
        children: [
          // Explicit colour so the icon reads on the popup surface — without
          // it, it inherits the app bar's foreground (white) and vanishes on
          // the light menu background in light mode.
          Icon(icon,
              size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          if (subtitle == null)
            Text(label)
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
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
      case _HomeMenuItem.joinTeam:
        _openJoinTeam();
      case _HomeMenuItem.details:
        _openDetails();
      case _HomeMenuItem.credits:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                CreditsRoute(eventStarted: _event?.started ?? false),
          ),
        );
      case _HomeMenuItem.settings:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsRoute()),
        );
      case _HomeMenuItem.logOut:
        _logout();
    }
  }

  Future<void> _openScanner() async {
    final result = await Navigator.of(context).push<ScanRouteResult>(
      MaterialPageRoute(
        builder: (_) => ScanRoute(
          api: widget.api,
          teamPuzzletsChanged: _socket?.teamPuzzletsChanged,
          teamId: _teamId,
          gameEndsAt: _event?.endgame?.endsAt,
        ),
      ),
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

  /// Centre the map on the player's current location. Explicit tap, so it
  /// may re-ask for permission; a permanent denial offers a jump to
  /// Settings (same flow as the pin map's locate button).
  Future<void> _locateMe() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final fix = await LocationService.getCurrent(context: context);
      if (!mounted) return;
      _mapController.move(
        LatLng(fix.latitude, fix.longitude),
        _mapZoom < 16 ? 16 : _mapZoom,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          action: e is LocationPermissionDeniedException
              ? SnackBarAction(
                  label: LocationStrings.openSettings,
                  onPressed: LocationService.openAppSettings,
                )
              : null,
        ),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Resume an active puzzlet from the "in progress" card — no rescan.
  /// Opens the puzzlet directly; on capture, replays the territory
  /// animation like the scan flow does.
  Future<void> _openActivePuzzlet(ScanResult entry) async {
    final puzzlet = entry.activePuzzlet;
    if (puzzlet == null) return;
    final captured = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PuzzletRoute(
          api: widget.api,
          pole: entry.pole,
          puzzlet: puzzlet,
          contendingTeams: entry.contendingTeams,
          teamPuzzletsChanged: _socket?.teamPuzzletsChanged,
          teamId: _teamId,
          gameEndsAt: _event?.endgame?.endsAt,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
    if (captured == true && mounted) {
      setState(() => _captureStartedAt[entry.pole.id] = DateTime.now());
      _ensureAnimTicker();
    }
  }

  /// "Try the next one" after a rival captured your puzzlet: assign
  /// the pole's next puzzlet without a rescan and open it.
  Future<void> _tryNextPuzzlet(String poleId) async {
    try {
      final entry = await widget.api.assignActivePuzzlet(poleId);
      if (!mounted) return;
      _refreshActivePuzzlets();
      // Clear the "withdrawn / no longer available" snackbars from the pole
      // we just left — they live on the root messenger and would otherwise
      // linger over the fresh puzzlet screen we're about to open.
      ScaffoldMessenger.of(context).clearSnackBars();
      await _openActivePuzzlet(entry);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(PuzzletStrings.submissionFailedNetwork)));
    }
  }

  Future<void> _giveUpActivePuzzlet(ScanResult entry) async {
    final puzzlet = entry.activePuzzlet;
    if (puzzlet == null) return;
    final name = entry.pole.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(GameplayStrings.giveUpTitle),
        content: Text(GameplayStrings.giveUpBody(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(GameplayStrings.giveUpCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(GameplayStrings.giveUpConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.abandonActivePuzzlet(puzzlet.id);
    } catch (_) {
      // The socket broadcast + next refresh will reconcile anyway.
    }
    _refreshActivePuzzlets();
  }

  /// Map style for a pole's current owner — colour + pattern from the
  /// server's stable per-team index. Null when unclaimed.
  TeamStyle? _styleForPole(Pole pole) {
    final index = pole.currentOwnerColorIndex;
    if (pole.currentOwnerTeamId == null || index == null) return null;
    return TeamStyle.forIndex(index);
  }

  /// Tap-to-inspect: show who holds the tapped zone.
  ///
  /// With pre-dissolved territory shapes present, the tapped owner is whichever
  /// region *contains* the point — the same shape that's coloured there, so
  /// colour and tap always agree. Otherwise falls back to the Voronoi rule
  /// (nearest pole within the territory radius); taps in open space do nothing.
  void _showOwnerAt(LatLng point) {
    final poles = _poles;
    if (poles == null || poles.isEmpty) return;

    // Poles win the tap. A pole dot can sit outside its own region (you
    // asked for that), so resolving a tap purely by which zone it landed in
    // would name the unrelated zone the pin overlaps — and the pin's own hit
    // box is only ~12 px, easy to just miss. Project every in-play pole to
    // the screen; if the tap fell within a forgiving radius of one, name
    // that stake instead of the ground underneath it.
    final camera = _mapController.camera;
    final tapPx = camera.latLngToScreenPoint(point);
    Pole? nearestPole;
    var bestPx2 = double.infinity;
    for (final pole in _polesInPlay()) {
      final px =
          camera.latLngToScreenPoint(LatLng(pole.latitude, pole.longitude));
      final dx = px.x - tapPx.x;
      final dy = px.y - tapPx.y;
      final d2 = dx * dx + dy * dy;
      if (d2 < bestPx2) {
        bestPx2 = d2;
        nearestPole = pole;
      }
    }
    if (nearestPole != null && bestPx2 <= _poleTapSlopPx * _poleTapSlopPx) {
      _showPoleOwner(nearestPole);
      return;
    }

    final territory = _territory;
    if (territory != null) {
      for (final region in territory) {
        if (!_ringContains(region.ring, point)) continue;
        // Skip if the tap fell in a hole (an enclosed rival zone).
        if (region.holes.any((h) => _ringContains(h, point))) continue;
        final pole = poles.where((p) => p.id == region.poleId).firstOrNull;
        // A region is painted when its pole is captured OR liberated (the
        // freed hatch) — respond to a tap in either case. A never-claimed
        // pole paints nothing here, so its area stays silent (tap its pin).
        if (pole == null ||
            (pole.currentOwnerTeamId == null && !pole.liberated)) {
          return;
        }
        _showPoleOwner(pole);
        return;
      }
      return; // tapped outside every zone
    }

    const distance = Distance();
    Pole? nearest;
    var best = double.infinity;
    for (final pole in poles) {
      final d = distance.as(
          LengthUnit.Meter, point, LatLng(pole.latitude, pole.longitude));
      if (d < best) {
        best = d;
        nearest = pole;
      }
    }
    if (nearest == null || best > 200) return; // matches TerritoryLayer radius
    // An unclaimed pole paints no territory, so a tap this far from it landed
    // on blank space — popping something up there just reads as confusing.
    // Unclaimed stakes are revealed only by a direct tap on their marker
    // (wired on the marker itself); a claimed OR liberated zone (both painted)
    // responds anywhere within it.
    if (nearest.currentOwnerTeamId == null && !nearest.liberated) return;
    _showPoleOwner(nearest);
  }

  /// Ray-casting point-in-polygon on a (lat,lng) ring.
  static bool _ringContains(List<LatLng> ring, LatLng pt) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final yi = ring[i].latitude, xi = ring[i].longitude;
      final yj = ring[j].latitude, xj = ring[j].longitude;
      if (((yi > pt.latitude) != (yj > pt.latitude)) &&
          (pt.longitude < (xj - xi) * (pt.latitude - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// Brief snackbar naming a stake and its current owner, with the owning
  /// team's colour glyph. Reached by tapping a claimed zone, or by tapping any
  /// stake's marker directly (the only way to reveal an unclaimed stake).
  void _showPoleOwner(Pole pole) {
    final idx = pole.currentOwnerColorIndex;
    final owned = pole.currentOwnerTeamId != null && idx != null;
    final style = owned ? TeamStyle.forIndex(idx) : null;
    final isMine = pole.currentOwnerTeamId == _teamId;
    final name = pole.currentOwnerTeamName;

    final owner = !owned
        ? (pole.liberated
            ? GameplayStrings.zoneLiberated
            : GameplayStrings.zoneUnclaimed)
        : isMine
            ? GameplayStrings.zoneOwnerYou(name)
            : GameplayStrings.zoneOwnerOther(name);
    // The name is the author's label or a stable generated handle — never
    // the barcode. The barcode is the scannable code, withheld server-side so
    // reading it off the map can't let someone claim the stake without being
    // physically there.
    //
    // Explain every distinct map icon here: the owner line always, then a line
    // per marker state so a tap says what the icon means (lock, under-attack
    // ring, accessibility-blocked glyph). Locked and prohibitive are mutually
    // exclusive (a locked stake has no puzzlets left to conflict).
    final lines = <String>['${pole.name} — $owner'];
    if (pole.locked) lines.add(GameplayStrings.zoneLocked);
    if (_lastAttackAt.containsKey(pole.id)) {
      lines.add(GameplayStrings.zoneUnderAttack);
    }
    if (pole.prohibitive) lines.add(GameplayStrings.zoneProhibitive);
    final message = lines.join('\n');

    // Replace any current popup immediately rather than queueing — tapping a
    // new zone should show it at once, not wait for the previous one to time
    // out. removeCurrentSnackBar skips the dismiss animation so it feels instant.
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: Row(children: [
          // The exact marker from the map, larger — so "this icon means…" is
          // literally the same glyph beside the words.
          SizedBox(
            width: 24,
            height: 24,
            child: _PoleDot(
              style: style,
              isMine: isMine,
              prohibitive: pole.prohibitive,
              locked: pole.locked,
              dimension: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ]),
      ));
  }

  void _toggleHideProhibitive() {
    setState(() => _hideProhibitive = !_hideProhibitive);
    UiPreferences.setHideProhibitive(_hideProhibitive);
  }

  double get _voSize {
    if (_mapZoom >= _voFullZoom) return _voFullSize;
    if (_mapZoom <= _voTinyZoom) return _voTinySize;
    final t = (_mapZoom - _voTinyZoom) / (_voFullZoom - _voTinyZoom);
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
        final amber = AccentColors.forBrightness(theme.brightness, Colors.amber);
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
                Text('Reserved for helpers · status: ${p.status}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                if (p.region != null) ...[
                  const SizedBox(height: 16),
                  RegionContextCard(
                    breadcrumb: p.region!.breadcrumb,
                    stanzas: p.region!.stanzas,
                  ),
                ],
                const SizedBox(height: 16),
                Text(p.instructions, style: theme.textTheme.bodyLarge),
                if (p.warning != null && p.warning!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: amber.fill,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: amber.border),
                    ),
                    child: Row(children: [
                      Icon(Icons.warning_amber_outlined,
                          size: 20, color: amber.ink),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(p.warning!,
                            style: TextStyle(color: amber.ink)),
                      ),
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
    if (list.isEmpty) {
      return const LatLng(49.8951, -97.1384); // Portage and Main
    }
    final lat =
        list.map((p) => p.latitude).reduce((a, b) => a + b) / list.length;
    final lng =
        list.map((p) => p.longitude).reduce((a, b) => a + b) / list.length;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    // Once you're on a team the app bar is just the team name — the
    // "LANDGRAB" prefix is redundant here and only eats width that long
    // team names need in portrait.
    final titleText = (_teamName ?? 'LANDGRAB').toUpperCase();
    // The team's own map colour, shown as a swatch beside the name in the bar
    // (the same glyph the zone-tap snackbar uses). Prefer the index from /me
    // (known from launch, before owning any zone); fall back to what we've
    // learned from owned zones for an older server that doesn't send it. Null
    // only when not on a team.
    final myColorIndex =
        _myColorIndex ?? (_teamId == null ? null : _teamColorIndex[_teamId]);
    final myStyle =
        myColorIndex == null ? null : TeamStyle.forIndex(myColorIndex);
    // In test play we intentionally bypass the event-start gate — the
    // whole point of a rehearsal is to play before the event begins.
    final preEvent = _event != null && !_event!.started;

    // The "join a team" banner only earns its place near game time — hold it
    // back until 6h before start so early browsers aren't nagged for days.
    // Same time basis as the countdown (startTime vs now); shows through the
    // event once inside the window.
    final start = _event?.startTime;
    final showNoTeamBanner = _teamName == null &&
        start != null &&
        start.difference(DateTime.now()) <= const Duration(hours: 6);

    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder<bool>(
          valueListenable: EnvSwitchService.visible,
          builder: (context, envVisible, _) {
            final label = envVisible
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
                : Text(titleText);
            if (myStyle == null) return label;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CustomPaint(
                    painter: TeamGlyphPainter(
                        color: myStyle.color, pattern: myStyle.pattern),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(child: label),
              ],
            );
          },
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
              // Only while unteamed — once on a team "Join a team" reads
              // wrong, and hiding it avoids accidental mid-game switching.
              // (People without a team also get the banner on the map.)
              if (_teamName == null)
                _menuItem(_HomeMenuItem.joinTeam, Icons.group_add_outlined,
                    JoinTeamStrings.appBarTitle),
              _menuItem(_HomeMenuItem.details, Icons.badge_outlined,
                  GameplayStrings.details),
              _menuItem(_HomeMenuItem.credits, Icons.info_outline,
                  GameplayStrings.credits),
              // Settings is for everyone now (it holds the light/dark toggle);
              // the environment switcher inside it stays gated by the 7-tap
              // unlock (EnvSwitchService.visible), checked within the route.
              _menuItem(_HomeMenuItem.settings, Icons.settings_outlined,
                  GameplayStrings.settings),
              _menuItem(
                _HomeMenuItem.logOut,
                Icons.logout,
                GameplayStrings.logOut,
                // Always show which account you're signed in as, so it's
                // never a mystery who you're logged in with.
                subtitle: _accountEmail,
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error == null &&
              _poles != null &&
              _event != null &&
              showNoTeamBanner)
            _noTeamBanner(),
          Expanded(
            child: _error != null
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
                              MaterialPageRoute(
                                  builder: (_) => AuthorRoute(api: widget.api)),
                            ),
                            onValidate: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      ValidatorRoute(api: widget.api)),
                            ),
                            onSupervise: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      SupervisorRoute(api: widget.api)),
                            ),
                            onStarted: () => _load(),
                          )
                        : Stack(children: [
                            FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: _center(),
                                initialZoom: 14,
                                // Tap a zone to see who holds it.
                                onTap: (_, point) => _showOwnerAt(point),
                                // Make rotation deliberate: the gesture race
                                // commits a two-finger gesture to whichever
                                // intent (zoom/move/rotate) crosses its threshold
                                // first, and the raised rotation threshold means
                                // a casual twist mid-pinch stays a zoom. North
                                // is always restorable via the compass button.
                                interactionOptions: const InteractionOptions(
                                  enableMultiFingerGestureRace: true,
                                  rotationThreshold: 25,
                                ),
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
                                landgrabTileLayer(context),
                                // Territory fills sit above the tiles and below
                                // the marker pins so pole icons remain readable
                                // over their own coloured cells.
                                // EXPERIMENT: prefer pre-dissolved per-pole
                                // shapes; then the live block path; else the
                                // Voronoi layer (unchanged).
                                if (_territory != null)
                                  PrecomputedTerritoryLayer(
                                    regions: _territory!,
                                    poles: _poles!,
                                    myOwnerId: _teamId,
                                    colorIndexByTeam: _teamColorIndex,
                                  )
                                else if (_territoryBlocks != null)
                                  BlockTerritoryLayer(
                                    blocks: _territoryBlocks!,
                                    poles: _poles!,
                                    myOwnerId: _teamId,
                                    colorIndexByTeam: _teamColorIndex,
                                    puzzletPointsByPole: _puzzletPoints,
                                  )
                                else
                                  TerritoryLayer(
                                    poles: _poles!,
                                    myOwnerId: _teamId,
                                    colorIndexByTeam: _teamColorIndex,
                                    captureStartedAt: _captureStartedAt,
                                    captureFromOwner: _captureFromOwner,
                                    captureAnimationDuration:
                                        _captureAnimationDuration,
                                  ),
                                // PROTOTYPE: moving hatch over freed ground,
                                // above the static territory fill and below the
                                // pins. Empty (and free) unless zones are
                                // liberated (or the dev tuner previews some).
                                LiberatedZoneLayer(
                                  shapes: _liberatedShapes(),
                                  phase: _pulsePhase,
                                  style: _liberatedStyle,
                                ),
                                BathroomLayer(bathrooms: _bathrooms),
                                CaptureRingsLayer(
                                  poles: _poles!,
                                  captureStartedAt: _captureStartedAt,
                                  duration: _captureAnimationDuration,
                                  myOwnerId: _teamId,
                                  colorIndexByTeam: _teamColorIndex,
                                ),
                                AttackRingsLayer(
                                  poles: _poles!,
                                  attackedPoleIds: _lastAttackAt.keys.toSet(),
                                  pulsePhase: _pulsePhase,
                                ),
                                // Transient "which one" reticle from a
                                // notification's "View on map".
                                if (_highlightedPoleId != null)
                                  MarkerLayer(markers: [
                                    for (final pole in _poles!)
                                      if (pole.id == _highlightedPoleId)
                                        Marker(
                                          point: LatLng(
                                              pole.latitude, pole.longitude),
                                          width: 120,
                                          height: 120,
                                          child: HighlightReticle(
                                              phase: _pulsePhase),
                                        ),
                                  ]),
                                MarkerLayer(
                                  // The endgame boundary is invisible by design:
                                  // poles it has passed just disappear (their
                                  // territory stays — TerritoryLayer gets the
                                  // unfiltered list), so players sense the
                                  // squeeze without seeing a circle.
                                  markers: _polesInPlay().map((pole) {
                                    return Marker(
                                      // Keyed by pole so zoom-time culling can't
                                      // hand this element a different pole —
                                      // unkeyed, the _PoleDot's AnimatedContainer
                                      // tweened between neighbouring poles'
                                      // colours on every reshuffle.
                                      key: ValueKey(pole.id),
                                      point:
                                          LatLng(pole.latitude, pole.longitude),
                                      width: 12,
                                      height: 12,
                                      // A direct tap on the marker always
                                      // names the stake — the only way to
                                      // reveal an unclaimed one, since its
                                      // blank surroundings don't respond.
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => _showPoleOwner(pole),
                                        child: Tooltip(
                                          message: pole.name,
                                          child: _PoleDot(
                                            style: _styleForPole(pole),
                                            isMine: pole.currentOwnerTeamId ==
                                                _teamId,
                                            prohibitive: pole.prohibitive,
                                            locked: pole.locked,
                                          ),
                                        ),
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
                                const MapCompass.cupertino(
                                    hideIfRotatedNorth: true),
                              ],
                            ),
                            if (_activePuzzlets.isNotEmpty)
                              Positioned(
                                top: 8,
                                left: 8,
                                right: 8,
                                child: _InProgressCard(
                                  entry: _activePuzzlets.first,
                                  onOpen: () =>
                                      _openActivePuzzlet(_activePuzzlets.first),
                                  onGiveUp: () => _giveUpActivePuzzlet(
                                      _activePuzzlets.first),
                                ),
                              ),
                            // Locate-me lives bottom-left, matching the pin
                            // map — the Scan FAB owns the bottom-right.
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: Padding(
                                // Lift above the bottom safe-area inset
                                // (iOS home indicator) so this lines up with
                                // the Scan FAB, which the Scaffold already
                                // insets. Android's inset is typically ~0.
                                // Uniform 16 margin measured from the safe
                                // area: the bottom adds the home-indicator
                                // inset (matching the Scan FAB), while a
                                // device with no bottom inset (Android
                                // gesture nav, home-button iPhones) shows an
                                // even 16 all round.
                                padding: EdgeInsets.only(
                                  left: 16,
                                  bottom: 16 +
                                      MediaQuery.of(context).padding.bottom,
                                ),
                                child: FloatingActionButton.small(
                                  heroTag: null,
                                  tooltip: GameplayStrings.locateMe,
                                  onPressed: _locating ? null : _locateMe,
                                  child: _locating
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.my_location),
                                ),
                              ),
                            ),
                            // Hide-inaccessible toggle — only when the team has
                            // at least one prohibitive stake, so it never
                            // clutters the map for players without such needs.
                            if (_prohibitiveCount > 0)
                              Positioned(
                                top: _activePuzzlets.isNotEmpty ? 96 : 8,
                                right: 8,
                                child: _HideProhibitiveChip(
                                  hidden: _hideProhibitive,
                                  count: _prohibitiveCount,
                                  onToggle: _toggleHideProhibitive,
                                ),
                              ),
                            // THROWAWAY dev tuner for the liberated look —
                            // only in --dart-define=LIBERATED_TUNER=true builds.
                            if (kLiberatedTunerEnabled)
                              Positioned(
                                left: 8,
                                right: 8,
                                bottom: 80 +
                                    MediaQuery.of(context).padding.bottom,
                                child: LiberatedZoneTuner(
                                  style: _liberatedStyle,
                                  previewCount: _liberatedPreview,
                                  onStyle: (s) =>
                                      setState(() => _liberatedStyle = s),
                                  onPreview: (n) {
                                    setState(() => _liberatedPreview = n);
                                    if (n > 0) _ensureAnimTicker();
                                  },
                                ),
                              ),
                          ]),
          ),
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

  /// Fired a few seconds after the countdown reaches the start time — and then
  /// periodically — so the parent re-fetches the event. `started` is a server
  /// flag, so the map only appears once a reload reports the event underway.
  final VoidCallback onStarted;

  const _PreEventBody({
    required this.event,
    required this.isAuthor,
    required this.isValidator,
    required this.isSupervisor,
    required this.onAuthor,
    required this.onValidate,
    required this.onSupervise,
    required this.onStarted,
  });

  @override
  State<_PreEventBody> createState() => _PreEventBodyState();
}

class _PreEventBodyState extends State<_PreEventBody> {
  Timer? _ticker;
  String? _lastBarcode;
  String? _lastBarcodeFormat;
  String? _lastNfcUid;

  // `started` is a server flag, so when our local countdown crosses zero the
  // map doesn't appear on its own. A few seconds after the start passes we
  // nudge the parent to re-fetch the event, retrying every few seconds in case
  // the server clock lags ours, until `started` flips and this screen is gone.
  static const _startGrace = Duration(seconds: 3);
  static const _startPollInterval = Duration(seconds: 4);
  DateTime? _lastStartPoll;

  @override
  void initState() {
    super.initState();
    // Only run the countdown ticker when we have a target to count
    // down TO. If the event has no start time yet, the display shows
    // "not yet scheduled" and there's nothing to tick.
    if (widget.event.startTime != null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        _maybePollForStart();
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _maybePollForStart() {
    final start = widget.event.startTime;
    if (start == null) return;
    final now = DateTime.now();
    if (now.isBefore(start.add(_startGrace))) return;
    if (_lastStartPoll != null &&
        now.difference(_lastStartPoll!) < _startPollInterval) {
      return;
    }
    _lastStartPoll = now;
    widget.onStarted();
  }

  Future<void> _openBarcodeScanner() async {
    String? format;
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => BarcodeScannerRoute(
          title: PreEventStrings.barcodePracticeTitle,
          onFormat: (f) => format = f,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _lastBarcode = result;
      _lastBarcodeFormat = format;
    });
  }

  Future<void> _openNfcScanner() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            const NfcScannerRoute(title: PreEventStrings.nfcPracticeTitle),
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
            Text(PreEventStrings.practiceHeading,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _ScannerTile(
              icon: Icons.qr_code_scanner,
              label: PreEventStrings.barcodePracticeLabel,
              lastResult: _lastBarcode,
              resultDetail: _lastBarcodeFormat,
              onPressed: _openBarcodeScanner,
            ),
            const SizedBox(height: 8),
            _ScannerTile(
              icon: Icons.nfc,
              label: PreEventStrings.nfcPracticeLabel,
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
  // Extra detail shown alongside the value — the barcode symbology for the
  // barcode tile (e.g. "Code 128"); null for tiles that have no type (NFC).
  final String? resultDetail;
  final VoidCallback onPressed;

  const _ScannerTile({
    required this.icon,
    required this.label,
    required this.lastResult,
    this.resultDetail,
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
            ? Text(PreEventStrings.noScansYet, style: theme.textTheme.bodySmall)
            : Text(
                resultDetail == null
                    ? PreEventStrings.lastScan(lastResult!)
                    : PreEventStrings.lastScanWithType(
                        lastResult!, resultDetail!),
                style: theme.textTheme.bodySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()]),
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onPressed,
      ),
    );
  }
}

/// The team's active ("in progress") puzzlet, pinned over the map so
/// any member can resume it without rescanning. Tap to open; the
/// overflow gives it up.
class _InProgressCard extends StatelessWidget {
  final ScanResult entry;
  final VoidCallback onOpen;
  final VoidCallback onGiveUp;

  const _InProgressCard({
    required this.entry,
    required this.onOpen,
    required this.onGiveUp,
  });

  @override
  Widget build(BuildContext context) {
    final name = entry.pole.name;
    final instructions = entry.activePuzzlet?.instructions ?? '';
    return Card(
      elevation: 3,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              const Icon(Icons.hourglass_top, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${GameplayStrings.inProgressHeading}: $name',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (instructions.isNotEmpty)
                      Text(
                        instructions,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (entry.contendingTeams > 0)
                      Text(
                        GameplayStrings.othersHere(entry.contendingTeams),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                  ],
                ),
              ),
              TextButton(
                  onPressed: onOpen, child: const Text(GameplayStrings.resume)),
              IconButton(
                tooltip: GameplayStrings.giveUp,
                icon: const Icon(Icons.close),
                onPressed: onGiveUp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Matches the site's `.landgrab-pole` visual: a filled circle with a
/// stroke lightened toward white so dark colours (black especially)
/// still read against the map. Colour transitions ease over 200 ms to
/// match the site's `transition: fill 200ms ease-out, stroke 200ms
/// ease-out` rule, so a capture flip reads as a gradient rather than
/// Map control to show/hide stakes flagged prohibitive (nothing the team can
/// engage). A compact pill on the map; only rendered when such stakes exist.
class _HideProhibitiveChip extends StatelessWidget {
  final bool hidden;
  final int count;
  final VoidCallback onToggle;
  const _HideProhibitiveChip({
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

/// a hard cut.
/// A pole marker: the owning team's colour + pattern glyph, an unclaimed
/// neutral dot when nobody holds it, and a bold white ring when it's *your*
/// team's — so you can find yourself by shape, not colour alone.
class _PoleDot extends StatelessWidget {
  final TeamStyle? style;
  final bool isMine;
  // Every remaining puzzlet here conflicts with the team's needs — shown as a
  // distinct muted "blocked" marker (still claimable, hence not alarming).
  final bool prohibitive;
  // Fully captured — no puzzlets left to solve. Shown as a lock, distinct from
  // the prohibitive "blocked" glyph, tinted with the owner's colour so you can
  // still see who holds it.
  final bool locked;
  // Rendered size; drives icon sizing so the same marker is legible both as a
  // ~12px map pin and as a larger swatch in the tap snackbar.
  final double dimension;
  const _PoleDot({
    required this.style,
    this.isMine = false,
    this.prohibitive = false,
    this.locked = false,
    this.dimension = 12,
  });

  @override
  Widget build(BuildContext context) {
    if (locked) {
      // A lock in the owner's colour (grey if somehow unowned) — reads as
      // "done / nothing to do here", not as blocked-for-accessibility.
      final owner = style?.color ?? Colors.blueGrey.shade400;
      return DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: owner,
          border: Border.all(
              color: Colors.white.withValues(alpha: isMine ? 1 : 0.8),
              width: isMine ? 1.5 : 0.75),
        ),
        child: Icon(Icons.lock, size: dimension * 0.72, color: Colors.white),
      );
    }
    if (prohibitive) {
      // Distinct from owned/unowned dots: a muted circle with a "no entry"
      // glyph. Neutral, not red — it's a heads-up, not an error.
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
    final s = style;
    if (s == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blueGrey.shade400,
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.6), width: 0.75),
        ),
      );
    }
    final borderColor =
        isMine ? Colors.white : Color.lerp(s.color, Colors.white, 0.45)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor.withValues(alpha: isMine ? 1 : 0.7),
          width: isMine ? 1.5 : 0.75,
        ),
      ),
      child: CustomPaint(
        painter: TeamGlyphPainter(color: s.color, pattern: s.pattern),
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
