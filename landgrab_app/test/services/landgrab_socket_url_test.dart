import 'package:flutter_test/flutter_test.dart';
import 'package:landgrab/services/landgrab_socket.dart';

void main() {
  group('landgrabWebsocketUrl', () {
    test('https root → wss', () {
      expect(
        landgrabWebsocketUrl('https://poles-staging.chromatin.ca'),
        'wss://poles-staging.chromatin.ca/socket/websocket',
      );
    });

    test('localhost http stays ws (no TLS in local dev)', () {
      expect(
        landgrabWebsocketUrl('http://localhost:4000'),
        'ws://localhost:4000/socket/websocket',
      );
      expect(
        landgrabWebsocketUrl('http://127.0.0.1:4000'),
        'ws://127.0.0.1:4000/socket/websocket',
      );
    });

    // The bug this fix exists for: a plaintext http root to a real host would
    // build ws://, which the server force_ssl-301s and the socket never
    // connects. It must be coerced up to wss.
    test('remote http root is coerced to wss', () {
      expect(
        landgrabWebsocketUrl('http://poles-staging.chromatin.ca'),
        'wss://poles-staging.chromatin.ca/socket/websocket',
      );
      expect(
        landgrabWebsocketUrl('http://landgrab.chromatin.ca'),
        'wss://landgrab.chromatin.ca/socket/websocket',
      );
    });

    test('a base path on the root is replaced by the socket path', () {
      expect(
        landgrabWebsocketUrl('https://poles-staging.chromatin.ca/'),
        'wss://poles-staging.chromatin.ca/socket/websocket',
      );
    });
  });
}
