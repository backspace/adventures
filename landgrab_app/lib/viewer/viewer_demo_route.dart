import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/viewer/bundle_codec.dart';
import 'package:landgrab/viewer/qr_stream_receiver.dart';
import 'package:landgrab/viewer/viewer_browse_route.dart';
import 'package:landgrab/viewer/viewer_dataset.dart';
import 'package:landgrab/viewer/viewer_export.dart';
import 'package:landgrab/viewer/viewer_send_route.dart';
import 'package:landgrab/viewer/viewer_store.dart';

/// Self-contained prototype of the device-to-device viewer flow. One device
/// **sends** (shows a looping QR stream), the other **receives** (scans it),
/// and on completion the decrypted dataset opens in the browse view and is
/// stored for offline use.
///
/// No password: each bundle is encrypted under a fresh random key that travels
/// inside the QR stream and is then held in the device keychain. Send sources:
/// the real content (fetched from the supervisor endpoints on this signed-in
/// "bootstrap" machine), whatever's already stored on this device (relay), or a
/// synthetic demo set.
class ViewerDemoRoute extends StatelessWidget {
  final LandgrabApi api;
  const ViewerDemoRoute({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Viewer demo')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Move a browsable dataset phone-to-phone with no server. Sending '
              'needs no camera — run Send on the Mac and Receive on the phone, '
              'then point the phone at the screen.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Text('Send', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.cloud_download),
              label: const Text('Send REAL content (fetch from server)'),
              onPressed: () => _openSend(context, 'Real content', () async {
                final enc = await ViewerBundle.encode(await ViewerExport.fetch(api));
                return ViewerBundle.forTransport(enc.bytes, enc.key);
              }),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.smartphone),
              label: const Text('Send SAVED content (from this device)'),
              onPressed: () => _openSend(context, 'Saved content', () async {
                final bundle = await ViewerStore.rawBundle();
                final key = await ViewerStore.rawKey();
                if (bundle == null || key == null) {
                  throw StateError('No data has been synced to this device yet.');
                }
                return ViewerBundle.forTransport(bundle, key);
              }),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_2),
              label: const Text('Send demo content (synthetic)'),
              onPressed: () => _openSend(context, 'Demo content', () async {
                final enc = await ViewerBundle.encode(demoDataset());
                return ViewerBundle.forTransport(enc.bytes, enc.key);
              }),
            ),
            const SizedBox(height: 24),
            Text('Receive', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Receive (scan QR stream)'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const _ReceiveScreen()),
              ),
            ),
            const Spacer(),
            Text(
              'No password: the decryption key travels inside the QR stream and '
              'is stored on-device, bound to this unlocked device.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  void _openSend(
    BuildContext context,
    String label,
    Future<Uint8List> Function() bundleSource,
  ) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ViewerSendRoute(bundleSource: bundleSource, label: label),
    ));
  }
}

/// A synthetic dataset big enough to make the QR stream a few frames — all
/// clearly fake content, nothing sensitive.
ViewerDataset demoDataset() => ViewerDataset(
      poles: List.generate(
        10,
        (i) => ViewerPole(
          id: 'pole-$i',
          name: 'Demo stake ${i + 1}',
          latitude: 49.8999 + i * 0.0003,
          longitude: -97.1349 - i * 0.0003,
          accessibilityTags: i.isEven ? const ['stairs'] : const [],
        ),
      ),
      regions: List.generate(
        8,
        (i) => ViewerRegion(
          id: 'region-$i',
          name: 'Demo region ${i + 1}',
          entryInstructions: 'Enter region ${i + 1} through the marked door.',
        ),
      ),
      puzzlets: List.generate(
        120,
        (i) => ViewerPuzzlet(
          id: 'puz-$i',
          poleId: 'pole-${i % 10}',
          regionId: 'region-${i % 8}',
          instructions:
              'Demo clue ${i + 1}: find the labelled object and read its code.',
          answer: 'demo-answer-${i + 1}',
          answerType: const ['loose_text', 'strict_text', 'barcode', 'nfc'][i % 4],
          difficulty: i % 3,
          latitude: i % 7 == 0 ? null : 49.8999 + (i % 10) * 0.0004,
          longitude: i % 7 == 0 ? null : -97.1349 - (i % 8) * 0.0004,
        ),
      ),
    );

class _ReceiveScreen extends StatefulWidget {
  const _ReceiveScreen();

  @override
  State<_ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<_ReceiveScreen> {
  bool _handling = false;

  Future<void> _onComplete(Uint8List wire) async {
    if (_handling) return;
    _handling = true;
    try {
      final parts = ViewerBundle.fromTransport(wire);
      final data = await ViewerBundle.decode(parts.bundle, parts.key);
      // Persist the ciphertext + its key (key → device-bound keychain) so it
      // can be browsed offline later via the home menu.
      await ViewerStore.save(parts.bundle,
          key: parts.key, itemCount: data.itemCount);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          // Pass the wire (key+bundle) so the browser can relay it onward.
          builder: (_) => ViewerBrowseRoute(dataset: data, bundleBytes: wire),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open bundle: $e')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receive')),
      body: QrStreamReceiver(onComplete: _onComplete),
    );
  }
}
