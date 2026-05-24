import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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
          await NfcManager.instance.stopSession(
            errorMessage: 'Could not read this tag.',
          );
          if (!mounted) return;
          setState(() => _status = 'Could not read that tag. Try another.');
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

  /// Read the tag's hardware identifier across platforms. nfc_manager exposes
  /// platform-specific tag-tech data; we probe the common ones in order.
  String? _extractIdentifier(NfcTag tag) {
    final data = tag.data;
    for (final key in ['mifare', 'nfca', 'nfcb', 'nfcf', 'nfcv', 'isodep', 'iso7816']) {
      final tech = data[key];
      if (tech is Map) {
        final id = tech['identifier'];
        if (id is List<int>) return _toHex(id);
        if (id is Uint8List) return _toHex(id);
      }
    }
    return null;
  }

  String _toHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();

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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.contactless, size: 80),
              const SizedBox(height: 16),
              Text(
                _status ?? 'Hold your phone near the NFC tag.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
