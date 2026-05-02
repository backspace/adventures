import 'dart:async';

import 'package:logger/logger.dart';
import 'package:phoenix_socket/phoenix_socket.dart';
import 'package:poles/services/user_service.dart';

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
class PolesSocket {
  final String apiRoot;
  final Logger _log = Logger();

  PhoenixSocket? _socket;
  PhoenixChannel? _channel;
  StreamSubscription? _channelSub;
  StreamSubscription? _socketSub;

  final _updates = StreamController<PoleUpdate>.broadcast();
  final _reconnects = StreamController<void>.broadcast();
  bool _hadFirstConnect = false;

  PolesSocket({required this.apiRoot});

  Stream<PoleUpdate> get updates => _updates.stream;
  Stream<void> get reconnects => _reconnects.stream;

  Future<void> connect() async {
    final token = await UserService.getAccessToken();
    if (token == null) {
      _log.w('PolesSocket: no token, refusing to connect');
      return;
    }

    final wsUrl = '${apiRoot.replaceFirst('http', 'ws')}/socket/websocket';

    _socket = PhoenixSocket(
      wsUrl,
      socketOptions: PhoenixSocketOptions(params: {'Authorization': token}),
    );

    _socketSub = _socket!.openStream.listen((_) {
      if (_hadFirstConnect) {
        _log.d('PolesSocket: reconnected, signalling resync');
        _reconnects.add(null);
      }
      _hadFirstConnect = true;
    });

    await _socket!.connect();

    _channel = _socket!.addChannel(topic: 'poles:map');
    _channelSub = _channel!.messages.listen(_handleMessage);
    await _channel!.join().future;
  }

  void _handleMessage(Message message) {
    if (message.event.value != 'pole_updated') return;
    final payload = message.payload;
    if (payload is! Map<String, dynamic>) return;
    try {
      _updates.add(PoleUpdate.fromJson(payload));
    } catch (e, st) {
      _log.w('PolesSocket: bad pole_updated payload', error: e, stackTrace: st);
    }
  }

  Future<void> dispose() async {
    await _channelSub?.cancel();
    await _socketSub?.cancel();
    _channel?.leave();
    _socket?.close();
    await _updates.close();
    await _reconnects.close();
  }
}
