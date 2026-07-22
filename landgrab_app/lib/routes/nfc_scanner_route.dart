import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:landgrab/widgets/landgrab_app_bar.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

/// Full-screen scanner that starts an NFC session and pops with the first
/// scanned tag's UID as an uppercase hex string (e.g. "04A1B2C3D4"), or
/// null if the user cancels.
///
/// On Android we drive the reader directly via [NfcManagerAndroid] rather
/// than the cross-platform helper, specifically so we can pass
/// SKIP_NDEF_CHECK + NO_PLATFORM_SOUNDS. Without those, Android's own tag
/// dispatcher ("New tag scanned" overlay) and scan sound fire alongside our
/// read — the reason for the migration off nfc_manager 3.x, whose Android
/// reader mode set neither flag and offered no way to.
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
    final availability = await NfcManager.instance.checkAvailability();
    if (availability != NfcAvailability.enabled) {
      if (!mounted) return;
      setState(() => _status = availability == NfcAvailability.disabled
          ? 'NFC is turned off. Enable it in system settings and try again.'
          : 'NFC is not available on this device.');
      return;
    }

    if (Platform.isAndroid) {
      await _startAndroid();
    } else {
      await _startIos();
    }
  }

  Future<void> _startAndroid() async {
    await NfcManagerAndroid.instance.enableReaderMode(
      // ISO14443 (MIFARE, NTAG, …) = NFC-A/B; ISO15693 = NFC-V. FeliCa
      // (NFC-F) is deliberately excluded, matching iOS. skipNdefCheck +
      // noPlatformSounds keep the OS tag dispatcher and scan sound out of
      // the way so only the app reacts to the tag.
      flags: {
        NfcReaderFlagAndroid.nfcA,
        NfcReaderFlagAndroid.nfcB,
        NfcReaderFlagAndroid.nfcV,
        NfcReaderFlagAndroid.skipNdefCheck,
        NfcReaderFlagAndroid.noPlatformSounds,
      },
      onTagDiscovered: (tag) async {
        if (_popping) return;
        final android = NfcTagAndroid.from(tag);
        final id = android?.id;
        if (id == null || id.isEmpty) {
          // Field-side scans have no debug terminal attached, so surface
          // what the platform exposed on-screen too.
          final diag = _androidDiagnostic(android);
          debugPrint('NFC tag with no identifier:\n$diag');
          await NfcManagerAndroid.instance.disableReaderMode();
          if (!mounted) return;
          setState(() {
            _status = 'Could not read that tag. See diagnostic below.';
            _diagnostic = diag;
          });
          // Re-arm so the user can try a different tag.
          _start();
          return;
        }
        _popping = true;
        // Deliberately do NOT disableReaderMode here. Disabling while the
        // tag is still on the antenna hands it straight to Android's own
        // dispatcher, which pops the "New tag" / NDEF overlay (this showed
        // up as the overlay appearing during the post-answer celebration —
        // the one moment the tag rests on the phone while no screen is
        // actively reading). dispose() swaps to a silent no-op reader mode
        // instead, so the OS never sees the lingering tag.
        if (!mounted) return;
        Navigator.of(context).pop<String>(_toHex(id));
      },
    );
  }

  /// Keep Android in reader mode after a successful read, but with an empty
  /// callback and the OS-silencing flags — so a tag left on the antenna
  /// (e.g. during the answer celebration) is swallowed by us rather than
  /// dispatched by the OS. Android clears reader mode automatically when the
  /// app next backgrounds; the next real scan replaces this.
  Future<void> _enableSilentAndroidReaderMode() async {
    try {
      await NfcManagerAndroid.instance.enableReaderMode(
        flags: {
          NfcReaderFlagAndroid.nfcA,
          NfcReaderFlagAndroid.nfcB,
          NfcReaderFlagAndroid.nfcV,
          NfcReaderFlagAndroid.skipNdefCheck,
          NfcReaderFlagAndroid.noPlatformSounds,
        },
        onTagDiscovered: (_) {},
      );
    } catch (_) {}
  }

  Future<void> _startIos() async {
    await NfcManager.instance.startSession(
      // Restrict to ISO14443 (MIFARE, NTAG, etc.) and ISO15693. Excluding
      // ISO18092 (FeliCa) avoids needing the felica.systemcodes entitlement,
      // which is intended for Japanese transit-card-style tags we don't use.
      pollingOptions: {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
      },
      alertMessageIos: widget.title,
      onDiscovered: (tag) async {
        if (_popping) return;
        final id = _iosIdentifier(tag);
        if (id == null) {
          final diag = _iosDiagnostic(tag);
          debugPrint('NFC tag with unrecognized shape:\n$diag');
          await NfcManager.instance
              .stopSession(errorMessageIos: 'Could not read this tag.');
          if (!mounted) return;
          setState(() {
            _status = 'Could not read that tag. See diagnostic below.';
            _diagnostic = diag;
          });
          _start();
          return;
        }
        _popping = true;
        await NfcManager.instance.stopSession();
        if (!mounted) return;
        Navigator.of(context).pop<String>(id);
      },
      onSessionErrorIos: (error) {
        if (!mounted) return;
        setState(() => _status = error.message);
      },
    );
  }

  /// The tag's hardware identifier on iOS. The same physical tag surfaces
  /// under different tech classes depending on its type, so probe the ones
  /// we poll for in order.
  String? _iosIdentifier(NfcTag tag) {
    final mifare = MiFareIos.from(tag)?.identifier;
    if (mifare != null && mifare.isNotEmpty) return _toHex(mifare);
    final iso15693 = Iso15693Ios.from(tag)?.identifier;
    if (iso15693 != null && iso15693.isNotEmpty) return _toHex(iso15693);
    final iso7816 = Iso7816Ios.from(tag)?.identifier;
    if (iso7816 != null && iso7816.isNotEmpty) return _toHex(iso7816);
    final felica = FeliCaIos.from(tag)?.currentIDm;
    if (felica != null && felica.isNotEmpty) return _toHex(felica);
    return null;
  }

  String _toHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();

  String _androidDiagnostic(NfcTagAndroid? tag) {
    if (tag == null) return 'No Android tag data was exposed.';
    final id = tag.id.isEmpty ? '(empty)' : _toHex(tag.id);
    final techs = tag.techList.isEmpty ? '(none)' : tag.techList.join(', ');
    return 'Techs: $techs\nID: $id';
  }

  String _iosDiagnostic(NfcTag tag) {
    final types = <String>[
      if (MiFareIos.from(tag) != null) 'MiFare',
      if (Iso15693Ios.from(tag) != null) 'ISO15693',
      if (Iso7816Ios.from(tag) != null) 'ISO7816',
      if (FeliCaIos.from(tag) != null) 'FeliCa',
    ];
    return types.isEmpty
        ? 'No recognized tag type on this tag.'
        : 'Recognized ${types.join(", ")} but no identifier was present.';
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      if (_popping) {
        // A tag was read and we're unwinding to show the result — keep the
        // OS suppressed (see _enableSilentAndroidReaderMode) so a tag still
        // on the antenna doesn't trigger the system overlay.
        _enableSilentAndroidReaderMode();
      } else {
        // Backed out without reading — fully release the reader.
        NfcManagerAndroid.instance.disableReaderMode().catchError((_) {});
      }
    } else {
      NfcManager.instance.stopSession().catchError((_) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: LandgrabAppBar(title: widget.title),
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
