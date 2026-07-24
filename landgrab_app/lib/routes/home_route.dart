import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
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
import 'package:landgrab/routes/credits_route.dart';
import 'package:landgrab/routes/home/home_menu.dart';
import 'package:landgrab/routes/home/in_progress_card.dart';
import 'package:landgrab/routes/home/load_error_view.dart';
import 'package:landgrab/routes/home/map_markers.dart';
import 'package:landgrab/routes/home/pole_sheets.dart';
import 'package:landgrab/routes/home/pre_event_body.dart';
import 'package:landgrab/routes/home/territory_map_view.dart';
import 'package:landgrab/routes/instructions_route.dart';
import 'package:landgrab/routes/details_webview_route.dart';
import 'package:landgrab/routes/join_team_route.dart';
import 'package:landgrab/routes/login_route.dart';
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
import 'package:landgrab/widgets/liberated_zone_layer.dart';
import 'package:landgrab/widgets/liberated_zone_tuner.dart';
import 'package:landgrab/widgets/team_style.dart';

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
  // Clean, player-facing load-failure message (null when loaded fine).
  String? _error;
  // The raw error behind [_error], shown on demand for troubleshooting.
  String? _errorDetail;
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

  // Tap-link animations: poles are one colour now, so which pole owns which
  // zone isn't obvious. Tapping a zone pops its pole (a ripple from the pin);
  // tapping a pole flashes its zone. Keyed by pole id → when the animation
  // began, driven by the same ticker and purged on expiry like captures.
  static const Duration _polePopDuration = Duration(milliseconds: 550);
  static const Duration _zoneFlashDuration = Duration(milliseconds: 650);
  final Map<String, DateTime> _polePopAt = {};
  final Map<String, DateTime> _zoneFlashAt = {};

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
    final socket = LandgrabSocket(
      apiRoot: widget.api.dio.options.baseUrl,
      // If the socket drops because the access token expired, renew it via
      // the API's single-flight interceptor so the reconnect can auth.
      onReauthNeeded: widget.api.ensureFreshToken,
    );
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

    // Tap-link (pop / flash) expiries.
    _polePopAt.removeWhere(
        (_, start) => now.difference(start) >= _polePopDuration);
    _zoneFlashAt.removeWhere(
        (_, start) => now.difference(start) >= _zoneFlashDuration);

    // Ambient pulse for the attack rings — 0..1 loop.
    _pulsePhase = (elapsed.inMicroseconds / _pulseCycle.inMicroseconds) % 1.0;

    // Stop the ticker only when nothing on-screen needs animating —
    // liberated zones keep it alive so their hatch keeps drifting.
    if (_captureStartedAt.isEmpty &&
        _lastAttackAt.isEmpty &&
        _polePopAt.isEmpty &&
        _zoneFlashAt.isEmpty &&
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
    setState(() {
      _error = null;
      _errorDetail = null;
    });
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
      // A 401 means the session was rejected (usually a token that needs
      // refreshing) — give it its own guidance since "try again" then
      // "log out" is the fix; everything else is a generic load failure.
      // Either way the raw error is kept behind a "Show details" toggle.
      final is401 = e is DioException && e.response?.statusCode == 401;
      setState(() {
        _error = is401
            ? GameplayStrings.loadSessionExpired
            : GameplayStrings.loadFailed;
        _errorDetail = e.toString();
      });
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

  void _onMenuSelected(HomeMenuItem item) {
    switch (item) {
      case HomeMenuItem.author:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AuthorRoute(api: widget.api)),
        );
      case HomeMenuItem.validate:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ValidatorRoute(api: widget.api)),
        );
      case HomeMenuItem.supervise:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SupervisorRoute(api: widget.api)),
        );
      case HomeMenuItem.joinTeam:
        _openJoinTeam();
      case HomeMenuItem.details:
        _openDetails();
      case HomeMenuItem.instructions:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                InstructionsRoute(eventStarted: _event?.started ?? false),
          ),
        );
      case HomeMenuItem.credits:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                CreditsRoute(eventStarted: _event?.started ?? false),
          ),
        );
      case HomeMenuItem.settings:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsRoute()),
        );
      case HomeMenuItem.logOut:
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
      _onPoleTapped(nearestPole);
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
        _onZoneTapped(pole);
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
    _onZoneTapped(nearest);
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
  // Pole-tap detail (owner snackbar / accessibility sheet) lives in
  // home/pole_sheets.dart — a thin call from here with the live state it needs.
  void _showPoleOwner(Pole pole) => showPoleOwner(
        context,
        pole: pole,
        teamId: _teamId,
        underAttack: _lastAttackAt.containsKey(pole.id),
      );

  /// Tapped a pole (its marker, or close enough): flash its zone so the
  /// pole→zone link is visible, then show the owner.
  void _onPoleTapped(Pole pole) {
    _zoneFlashAt[pole.id] = DateTime.now();
    _ensureAnimTicker();
    _showPoleOwner(pole);
  }

  /// Tapped a zone: pop its pole (a ripple from the pin) so you can see which
  /// stake holds this ground, then show the owner. Skips the pop when the
  /// pole's pin isn't drawn — during the endgame shrink a zone stays painted
  /// after its pole is culled past the boundary (or hidden via declutter), and
  /// rippling an absent pin points at nothing.
  void _onZoneTapped(Pole pole) {
    if (_polesInPlay().any((p) => p.id == pole.id)) {
      _polePopAt[pole.id] = DateTime.now();
      _ensureAnimTicker();
    }
    _showPoleOwner(pole);
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
            onTap: () => showValidatorOnlySheet(context, p),
            child: Tooltip(
              message: p.instructions.length > 40
                  ? '${p.instructions.substring(0, 40)}…'
                  : p.instructions,
              child: ValidatorOnlyStar(size: size),
            ),
          ),
        ),
    ];
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
            if (myColorIndex == null) return label;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TeamSwatch(colorIndex: myColorIndex, isMine: true, size: 20),
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
          HomeMenu(
            isAuthor: _isAuthor,
            isValidator: _isValidator,
            isSupervisor: _isSupervisor,
            hasTeam: _teamName != null,
            preEvent: preEvent,
            accountEmail: _accountEmail,
            onSelected: _onMenuSelected,
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
                ? LoadErrorView(
                    message: _error!,
                    detail: _errorDetail,
                    onRetry: _load,
                    onLogout: _logout,
                  )
                : _poles == null || _event == null
                    ? const Center(child: CircularProgressIndicator())
                    : preEvent
                        ? PreEventBody(
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
                            TerritoryMapView(
                              mapController: _mapController,
                              center: _center(),
                              onMapTap: _showOwnerAt,
                              // Track camera zoom for size-scaled overlays
                              // (validator-only pins); only setState when it
                              // actually changes so panning doesn't rebuild
                              // every frame.
                              onZoomChanged: (z) {
                                if (z != _mapZoom) {
                                  setState(() => _mapZoom = z);
                                }
                              },
                              territory: _territory,
                              territoryBlocks: _territoryBlocks,
                              puzzletPoints: _puzzletPoints,
                              poles: _poles!,
                              teamId: _teamId,
                              colorIndexByTeam: _teamColorIndex,
                              captureStartedAt: _captureStartedAt,
                              captureFromOwner: _captureFromOwner,
                              captureAnimationDuration: _captureAnimationDuration,
                              polePopAt: _polePopAt,
                              polePopDuration: _polePopDuration,
                              zoneFlashAt: _zoneFlashAt,
                              zoneFlashDuration: _zoneFlashDuration,
                              liberatedShapes: _liberatedShapes(),
                              pulsePhase: _pulsePhase,
                              liberatedStyle: _liberatedStyle,
                              bathrooms: _bathrooms,
                              attackedPoleIds: _lastAttackAt.keys.toSet(),
                              highlightedPoleId: _highlightedPoleId,
                              polesInPlay: _polesInPlay(),
                              onPoleTap: _onPoleTapped,
                              validatorOnlyMarkers: _validatorOnlyPuzzlets.isEmpty
                                  ? const []
                                  : _validatorOnlyMarkers(),
                            ),
                            if (_gameEnded)
                              const Positioned(
                                top: 8,
                                left: 8,
                                right: 8,
                                child: SimulationEndedCard(),
                              )
                            else if (_activePuzzlets.isNotEmpty)
                              Positioned(
                                top: 8,
                                left: 8,
                                right: 8,
                                child: InProgressCard(
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
                            // Gone once the game's ended: there's nothing left
                            // to engage, and it would collide with the ended
                            // notice in the same corner.
                            if (!_gameEnded && _prohibitiveCount > 0)
                              Positioned(
                                top: _activePuzzlets.isNotEmpty ? 96 : 8,
                                right: 8,
                                child: HideProhibitiveChip(
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
