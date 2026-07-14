import 'dart:async';

import 'package:logger/logger.dart';
import 'package:phoenix_socket/phoenix_socket.dart';
import 'package:landgrab/models/notification.dart';
import 'package:landgrab/services/user_service.dart';

// The model moved to models/notification.dart when the history
// screen arrived; re-exported so socket consumers keep compiling.
export 'package:landgrab/models/notification.dart';

class PoleUpdate {
  final String id;
  final String? currentOwnerTeamId;
  final bool locked;

  PoleUpdate({
    required this.id,
    required this.currentOwnerTeamId,
    required this.locked,
  });

  factory PoleUpdate.fromJson(Map<String, dynamic> json) => PoleUpdate(
        id: json['id'] as String,
        currentOwnerTeamId: json['current_owner_team_id'] as String?,
        locked: json['locked'] as bool? ?? false,
      );
}

/// Subscribes to the `poles:map` channel and emits a [PoleUpdate] for every
/// `pole_updated` broadcast. Also exposes a [reconnects] stream so callers can
/// trigger a full resync after a connection blip drops broadcasts.
class LandgrabSocket {
  final String apiRoot;
  final Logger _log = Logger();

  PhoenixSocket? _socket;
  PhoenixChannel? _channel;
  StreamSubscription? _channelSub;
  StreamSubscription? _socketSub;

  final _updates = StreamController<PoleUpdate>.broadcast();
  final _notifications = StreamController<LandgrabNotification>.broadcast();
  final _reconnects = StreamController<void>.broadcast();
  bool _hadFirstConnect = false;

  LandgrabSocket({required this.apiRoot});

  Stream<PoleUpdate> get updates => _updates.stream;
  Stream<LandgrabNotification> get notifications => _notifications.stream;
  Stream<void> get reconnects => _reconnects.stream;

  Future<void> connect() async {
    final token = await UserService.getAccessToken();
    if (token == null) {
      _log.w('LandgrabSocket: no token, refusing to connect');
      return;
    }

    final wsUrl = '${apiRoot.replaceFirst('http', 'ws')}/socket/websocket';

    _socket = PhoenixSocket(
      wsUrl,
      socketOptions: PhoenixSocketOptions(params: {'Authorization': token}),
    );

    _socketSub = _socket!.openStream.listen((_) {
      if (_hadFirstConnect) {
        _log.d('LandgrabSocket: reconnected, signalling resync');
        _reconnects.add(null);
      }
      _hadFirstConnect = true;
    });

    await _socket!.connect();

    _channel = _socket!.addChannel(topic: 'landgrab:map');
    _channelSub = _channel!.messages.listen(_handleMessage);
    await _channel!.join().future;
  }

  void _handleMessage(Message message) {
    final payload = message.payload;
    if (payload is! Map<String, dynamic>) return;
    switch (message.event.value) {
      case 'pole_updated':
        try {
          _updates.add(PoleUpdate.fromJson(payload));
        } catch (e, st) {
          _log.w('LandgrabSocket: bad pole_updated payload', error: e, stackTrace: st);
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
    }
  }

  Future<void> dispose() async {
    await _channelSub?.cancel();
    await _socketSub?.cancel();
    _channel?.leave();
    _socket?.close();
    await _updates.close();
    await _notifications.close();
    await _reconnects.close();
  }
}
