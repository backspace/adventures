import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:landgrab/viewer/qr_stream_sender.dart';

/// Shows an encrypted bundle as a QR stream for another device to scan. Source-
/// agnostic: [bundleSource] can fetch+encode real content, build a synthetic
/// set, or just hand back bytes already stored on this device (relay). The
/// bytes are produced once and cached for the life of the screen.
class ViewerSendRoute extends StatefulWidget {
  final Future<Uint8List> Function() bundleSource;
  final String label;
  const ViewerSendRoute({
    super.key,
    required this.bundleSource,
    this.label = 'Send',
  });

  @override
  State<ViewerSendRoute> createState() => _ViewerSendRouteState();
}

class _ViewerSendRouteState extends State<ViewerSendRoute> {
  late final Future<Uint8List> _bundle = widget.bundleSource();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Send · ${widget.label}')),
      body: Center(
        child: FutureBuilder<Uint8List>(
          future: _bundle,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Preparing the bundle…'),
                  ],
                ),
              );
            }
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not build the bundle:\n${snap.error}',
                    textAlign: TextAlign.center),
              );
            }
            final bytes = snap.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QrStreamSender(bundle: bytes),
                  const SizedBox(height: 16),
                  Text('${(bytes.length / 1024).toStringAsFixed(1)} kB encrypted',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
