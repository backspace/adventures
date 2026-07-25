import 'dart:async';

import 'package:logger/logger.dart';
import 'package:phoenix_socket/phoenix_socket.dart';
import 'package:landgrab/models/notification.dart';
import 'package:landgrab/services/user_service.dart';

// The model moved to models/notification.dart when the history
// screen arrived; re-exported so socket consumers keep compiling.
export 'package:landgrab/models/notification.dart';

/// Derive the websocket endpoint from an API root.
///
/// `https://` → `wss://` and a localhost `http://` → `ws://` (there's no TLS
/// in local dev). Crucially, any *non-localhost* `http://` root is coerced up
/// to `wss://`: the deployed servers `force_ssl`-redirect the socket handshake
/// with a 301, and WebSocket clients don't follow redirects — so a plaintext
/// `ws://` to a real host silently never connects, and live delivery
/// (notifications, territory) dies while HTTP (which does follow the redirect)
/// keeps working. A stale build or a typo'd `http://` env override used to be
/// enough to trigger exactly that; this makes it impossible.
String landgrabWebsocketUrl(String apiRoot) {
  final uri = Uri.parse(apiRoot);
  final isLocal = uri.host == 'localhost' || uri.host == '127.0.0.1';
  final scheme = (uri.scheme == 'https' || !isLocal) ? 'wss' : 'ws';
  return uri.replace(scheme: scheme, path: '/socket/websocket').toString();
}

class PoleUpdate {
  final String id;
  final String? currentOwnerTeamId;
  final String? currentOwnerTeamName;
  final int? currentOwnerColorIndex;
  final bool locked;

  /// The event was a liberation — owner nil, but distinct from
  /// never-claimed. The block territory layer will render this state;
  /// the flag flows through now so the map's local pole list stays true.
  final bool liberated;

  PoleUpdate({
    required this.id,
    required this.currentOwnerTeamId,
    this.currentOwnerTeamName,
    this.currentOwnerColorIndex,
    required this.locked,
    this.liberated = false,
  });

  factory PoleUpdate.fromJson(Map<String, dynamic> json) => PoleUpdate(
        id: json['id'] as String,
        currentOwnerTeamId: json['current_owner_team_id'] as String?,
        currentOwnerTeamName: json['current_owner_team_name'] as String?,
        currentOwnerColorIndex: json['current_owner_color_index'] as int?,
        locked: json['locked'] as bool? ?? false,
        liberated: json['liberated'] as bool? ?? false,
      );
}

/// Subscribes to the `poles:map` channel and emits a [PoleUpdate] for every
/// `pole_updated` broadcast. Also exposes a [reconnects] stream so callers can
/// trigger a full resync after a connection blip drops broadcasts.
class LandgrabSocket {
  final String apiRoot;
  final Logger _log = Logger();

  // Fetches the access token for each (re)connect. Injectable for tests;
  // defaults to the stored token.
  final Future<String?> Function() _tokenProvider;

  // Called when the socket drops, so the app can renew an expired access
  // token (the usual cause) before the next reconnect. Optional.
  final Future<void> Function()? _onReauthNeeded;

  PhoenixSocket? _socket;
  PhoenixChannel? _channel;
  StreamSubscription? _channelSub;
  StreamSubscription? _socketSub;
  StreamSubscription? _closeSub;
  StreamSubscription? _errorSub;

  final _updates = StreamController<PoleUpdate>.broadcast();
  final _notifications = StreamController<LandgrabNotification>.broadcast();
  final _reconnects = StreamController<void>.broadcast();
  // Emits the affected team_id when that team's active puzzlets
  // change (a member scanned/gave up, or a puzzlet resolved), so
  // teammates' apps refetch and stay in sync.
  final _teamPuzzletsChanged = StreamController<String>.broadcast();
  bool _hadFirstConnect = false;
  // One reauth nudge per outage — reset when the socket opens again — so a
  // reconnect backoff loop doesn't hammer the renewal endpoint.
  bool _reauthNudged = false;

  LandgrabSocket({
    required this.apiRoot,
    Future<String?> Function()? tokenProvider,
    Future<void> Function()? onReauthNeeded,
  })  : _tokenProvider = tokenProvider ?? UserService.getAccessToken,
        _onReauthNeeded = onReauthNeeded;

  Stream<PoleUpdate> get updates => _updates.stream;
  Stream<LandgrabNotification> get notifications => _notifications.stream;
  Stream<void> get reconnects => _reconnects.stream;
  Stream<String> get teamPuzzletsChanged => _teamPuzzletsChanged.stream;

  Future<void> connect() async {
    if (await _tokenProvider() == null) {
      _log.w('LandgrabSocket: no token, refusing to connect');
      return;
    }

    final wsUrl = landgrabWebsocketUrl(apiRoot);

    _socket = PhoenixSocket(
      wsUrl,
      socketOptions: PhoenixSocketOptions(
        // Fetch the token lazily on EVERY (re)connect. Previously the token
        // was captured once here, so once it expired (Pow's 30-min access
        // token TTL) every auto-reconnect re-sent the stale token, the
        // server rejected the socket, and live delivery (notifications,
        // territory) died silently for the rest of the session. Reading it
        // fresh each time picks up whatever the HTTP layer (or the reauth
        // nudge below) has since renewed.
        dynamicParams: () async {
          final token = await _tokenProvider();
          return token == null || token.isEmpty
              ? <String, String>{}
              : {'Authorization': token};
        },
      ),
    );

    _socketSub = _socket!.openStream.listen((_) {
      _reauthNudged = false; // healthy again — allow a future nudge
      if (_hadFirstConnect) {
        _log.d('LandgrabSocket: reconnected, signalling resync');
        _reconnects.add(null);
      }
      _hadFirstConnect = true;
    });

    // A dropped/errored socket used to be silent. Log it, and nudge a token
    // renewal — the usual cause is an expired access token, and the next
    // reconnect re-reads the token via dynamicParams.
    _closeSub = _socket!.closeStream.listen((_) => _onDisconnected('closed'));
    _errorSub = _socket!.errorStream
        .listen((e) => _onDisconnected('error: ${e.error}'));

    await _socket!.connect();

    _channel = _socket!.addChannel(topic: 'landgrab:map');
    _channelSub = _channel!.messages.listen(_handleMessage);
    await _channel!.join().future;
  }

  void _onDisconnected(String why) {
    _log.d('LandgrabSocket: $why');
    final reauth = _onReauthNeeded;
    if (reauth == null || _reauthNudged) return;
    _reauthNudged = true;
    // Fire-and-forget: refresh the access token so the next reconnect
    // (which re-reads it) can authenticate. Reset when we reconnect.
    reauth().catchError((_) {});
  }

  void _handleMessage(Message message) {
    final payload = message.payload;
    if (payload is! Map<String, dynamic>) return;
    switch (message.event.value) {
      case 'pole_updated':
        try {
          _updates.add(PoleUpdate.fromJson(payload));
        } catch (e, st) {
          _log.w('LandgrabSocket: bad pole_updated payload',
              error: e, stackTrace: st);
        }
      case 'notification_created':
        try {
          _notifications.add(LandgrabNotification.fromJson(payload));
        } catch (e, st) {
          _log.w('LandgrabSocket: bad notification_created payload',
              error: e, stackTrace: st);
        }
      case 'event_updated':
        // Event config changed mid-game (e.g. the endgame boundary
        // moved). Piggyback on the reconnect stream — listeners
        // respond to both with the same full resync.
        _reconnects.add(null);
      case 'team_puzzlets_changed':
        final teamId = payload['team_id'];
        if (teamId is String) _teamPuzzletsChanged.add(teamId);
    }
  }

  Future<void> dispose() async {
    await _channelSub?.cancel();
    await _socketSub?.cancel();
    await _closeSub?.cancel();
    await _errorSub?.cancel();
    _channel?.leave();
    _socket?.close();
    await _updates.close();
    await _notifications.close();
    await _reconnects.close();
    await _teamPuzzletsChanged.close();
  }
}
