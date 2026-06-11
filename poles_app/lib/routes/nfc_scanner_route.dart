import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';

/// Full-screen scanner that starts an NFC session and pops with the first
/// scanned tag's UID as an uppercase hex string (e.g. "04A1B2C3D4"), or
/// null if the user cancels.
class NfcScannerRoute extends StatefulWidget {
  final String title;
  const NfcScannerRoute({super.key, this.title = 'Scan NFC tag'});

  @override
  State<NfcScannerRoute> createState() => _NfcScannerRouteState();
}

class _NfcScannerRouteState extends State<NfcScannerRoute> {
  String? _status;
  String? _diagnostic;
  bool _popping = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final available = await NfcManager.instance.isAvailable();
    if (!available) {
      if (!mounted) return;
      setState(() => _status = 'NFC is not available on this device.');
      return;
    }

    NfcManager.instance.startSession(
      // Restrict to ISO14443 (MIFARE, NTAG, etc.) and ISO15693. Excluding
      // ISO18092 (FeliCa) avoids needing the felica.systemcodes entitlement,
      // which is intended for Japanese transit-card-style tags we don't use.
      pollingOptions: {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
      },
      onDiscovered: (NfcTag tag) async {
        if (_popping) return;
        final id = _extractIdentifier(tag);
        if (id == null) {
          // Capture what the platform actually exposed so we can extend
          // the probe list. Surfaced on-screen too because field-side
          // tag scans don't have a debug terminal attached.
          final diag = _formatTagDiagnostic(tag.data);
          debugPrint('NFC tag with unrecognized shape:\n$diag');
          await NfcManager.instance.stopSession(
            errorMessage: 'Could not read this tag.',
          );
          if (!mounted) return;
          setState(() {
            _status = 'Could not read that tag. See diagnostic below.';
            _diagnostic = diag;
          });
          // Re-start the session so user can scan a different tag.
          _start();
          return;
        }
        _popping = true;
        await NfcManager.instance.stopSession();
        if (!mounted) return;
        Navigator.of(context).pop<String>(id);
      },
      onError: (error) async {
        if (!mounted) return;
        setState(() => _status = error.message);
      },
    );
  }

  /// Read the tag's hardware identifier across platforms. nfc_manager
  /// exposes platform-specific tag-tech data; the same physical tag can
  /// surface under different keys depending on platform and whether it's
  /// NDEF-formatted, so we probe the common ones in order.
  String? _extractIdentifier(NfcTag tag) {
    final data = tag.data;
    const probes = [
      // iOS
      'mifare',
      'iso15693',
      'iso7816',
      'felica',
      // Android
      'nfca',
      'nfcb',
      'nfcf',
      'nfcv',
      'isodep',
      'mifareclassic',
      'mifareultralight',
    ];
    for (final key in probes) {
      final tech = data[key];
      if (tech is Map) {
        final id = tech['identifier'];
        if (id is List<int>) return _toHex(id);
        if (id is Uint8List) return _toHex(id);
      }
    }
    // Some platforms wrap the tag in `ndef` with the raw tech nested
    // under `cachedMessage`/`tag` — check one level down too.
    final ndef = data['ndef'];
    if (ndef is Map) {
      final id = ndef['identifier'];
      if (id is List<int>) return _toHex(id);
      if (id is Uint8List) return _toHex(id);
    }
    return null;
  }

  String _toHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();

  /// Render the raw tag.data map as a human-readable diagnostic. Bytes
  /// get hex-formatted so the identifier (if buried in there) is visible.
  String _formatTagDiagnostic(Map<String, dynamic> data) {
    final buf = StringBuffer();
    buf.writeln('Techs: ${data.keys.join(", ")}');
    data.forEach((key, value) {
      buf.writeln();
      buf.writeln('[$key]');
      if (value is Map) {
        value.forEach((k, v) {
          buf.writeln('  $k: ${_formatValue(v)}');
        });
      } else {
        buf.writeln('  $value');
      }
    });
    return buf.toString();
  }

  String _formatValue(dynamic v) {
    if (v is Uint8List) return '[${_toHex(v)}] (${v.length} bytes)';
    if (v is List<int>) return '[${_toHex(v)}] (${v.length} bytes)';
    if (v is List) return '[${v.length} items] $v';
    return '$v';
  }

  @override
  void dispose() {
    // Best-effort cleanup if the user backs out.
    NfcManager.instance.stopSession().catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.contactless, size: 80),
            const SizedBox(height: 16),
            Text(
              _status ?? 'Hold your phone near the NFC tag.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            if (_diagnostic != null) ...[
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Text('Diagnostic',
                        style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _diagnostic!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Diagnostic copied.')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _diagnostic!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
