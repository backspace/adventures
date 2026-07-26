import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:landgrab/viewer/bundle_codec.dart';
import 'package:landgrab/viewer/viewer_dataset.dart';

/// Metadata about a stored dataset — enough to label the menu entry without
/// decrypting anything.
class ViewerStoreMeta {
  final int itemCount;
  final DateTime? syncedAt;
  const ViewerStoreMeta({required this.itemCount, this.syncedAt});
}

/// On-device persistence for a received viewer bundle, so it can be browsed
/// offline after the QR sync.
///
/// Encryption at rest without a second layer: the persisted file is the bundle
/// exactly as received — already AES-GCM ciphertext (see [ViewerBundle]). The
/// only secret is the passphrase, which lives in the OS keychain via
/// flutter_secure_storage (hardware-backed, device-locked). Lose the keychain
/// entry and the file is undecryptable; that's the point.
class ViewerStore {
  static const String _relPath = 'viewer/dataset.lgv';
  static const String _passKey = 'viewer_dataset_passphrase';
  static const String _countKey = 'viewer_dataset_item_count';
  static const String _syncedAtKey = 'viewer_dataset_synced_at_ms';

  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/$_relPath');
    await file.parent.create(recursive: true);
    return file;
  }

  /// Persist a freshly-received bundle. [bundle] is the encrypted bytes (as
  /// scanned), [passphrase] the key to decrypt them later.
  static Future<void> save(
    Uint8List bundle, {
    required String passphrase,
    required int itemCount,
  }) async {
    final file = await _file();
    await file.writeAsBytes(bundle, flush: true);
    await _secure.write(key: _passKey, value: passphrase);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_countKey, itemCount);
    await prefs.setInt(_syncedAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Whether a stored dataset is present (file exists). Cheap — no decrypt.
  static Future<bool> exists() async => (await _file()).exists();

  /// Display metadata for the menu entry, or null if nothing is stored.
  static Future<ViewerStoreMeta?> meta() async {
    if (!await exists()) return null;
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_syncedAtKey);
    return ViewerStoreMeta(
      itemCount: prefs.getInt(_countKey) ?? 0,
      syncedAt: ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms),
    );
  }

  /// Decrypt and return the stored dataset, or null if nothing is stored or the
  /// keychain entry is gone. Throws [ViewerBundleAuthException] only if the file
  /// and key are present but mismatched (shouldn't happen via [save]).
  static Future<ViewerDataset?> load() async {
    final file = await _file();
    if (!await file.exists()) return null;
    final passphrase = await _secure.read(key: _passKey);
    if (passphrase == null) return null;
    final bytes = await file.readAsBytes();
    return ViewerBundle.decode(bytes, passphrase: passphrase);
  }

  /// Forget the stored dataset entirely — file, key, and metadata.
  static Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
    await _secure.delete(key: _passKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_countKey);
    await prefs.remove(_syncedAtKey);
  }
}
