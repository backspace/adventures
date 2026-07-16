import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:http/retry.dart';

/// The shared CartoDB Positron base layer used by every LANDGRAB map, so
/// all of them share one tuned network setup.
///
/// Tuned for desktop, where a burst of tile requests (panning/zooming a
/// retina map) makes macOS intermittently fail DNS resolution —
/// `ClientException with SocketException: Failed host lookup … errno = 8`
/// — leaving tiles blank and the map "degrading" over a session. Two
/// things address that:
///
///  * **Connection reuse.** A single keep-alive [HttpClient] per layer
///    (capped per host) means the tile host is resolved far less often
///    instead of once per tile, which is what pressures the resolver.
///  * **Retry transient failures.** flutter_map's default [RetryClient]
///    only retries HTTP 503 — not socket/DNS exceptions — so a blip left
///    the tile permanently blank. We also retry [SocketException] /
///    [ClientException] with a short backoff, so the map self-heals.
TileLayer landgrabTileLayer(BuildContext context) => TileLayer(
      urlTemplate:
          'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
      subdomains: const ['a', 'b', 'c', 'd'],
      retinaMode: RetinaMode.isHighDensity(context),
      userAgentPackageName: 'ca.chromatin.poles',
      tileProvider: _resilientTileProvider(),
    );

// A fresh provider per layer: NetworkTileProvider.dispose() closes its
// client, so a shared instance would break other maps when one closes.
// Connection reuse still happens within each map's lifetime.
NetworkTileProvider _resilientTileProvider() => NetworkTileProvider(
      httpClient: RetryClient(
        IOClient(HttpClient()..maxConnectionsPerHost = 8),
        retries: 4,
        when: (response) => response.statusCode == 503,
        whenError: (error, _) =>
            error is SocketException || error is ClientException,
        delay: (retryCount) => Duration(milliseconds: 200 * (retryCount + 1)),
      ),
    );
