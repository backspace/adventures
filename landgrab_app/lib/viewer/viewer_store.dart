import 'dart:convert';
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
/// No passphrase. The encrypted bundle is written as-is to a file; its random
/// key is held in the keychain, bound to this unlocked device
/// ([KeychainAccessibility.unlocked_this_device] on iOS): it never syncs to
/// iCloud, isn't carried in device backups, and is only readable while the
/// device is unlocked. So "the password" is just the device unlock the user
/// already does — nothing to remember — and a leaked file or backup can't be
/// decrypted off-device.
class ViewerStore {
  static const String _relPath = 'viewer/dataset.lgv';
  static const String _keyKey = 'viewer_dataset_key'; // base64 random key
  static const String _countKey = 'viewer_dataset_item_count';
  static const String _syncedAtKey = 'viewer_dataset_synced_at_ms';

  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/$_relPath');
    await file.parent.create(recursive: true);
    return file;
  }

  /// Resilient keychain read — a decrypt failure (invalidated key material)
  /// reads as "absent" rather than throwing into the caller.
  static Future<String?> _readKey() async {
    try {
      return await _secure.read(key: _keyKey);
    } catch (_) {
      return null;
    }
  }

  /// Persist a freshly-received bundle: [bundle] is the encrypted bytes, [key]
  /// the random key that decrypts them.
  static Future<void> save(
    Uint8List bundle, {
    required Uint8List key,
    required int itemCount,
  }) async {
    final file = await _file();
    await file.writeAsBytes(bundle, flush: true);
    await _secure.write(key: _keyKey, value: base64Encode(key));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_countKey, itemCount);
    await prefs.setInt(_syncedAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Whether a stored dataset is present (file exists). Cheap — no decrypt.
  static Future<bool> exists() async => (await _file()).exists();

  /// The stored ciphertext bundle (no key) — for relaying, paired with [rawKey].
  static Future<Uint8List?> rawBundle() async {
    final file = await _file();
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  /// The stored key bytes, or null if absent/unreadable.
  static Future<Uint8List?> rawKey() async {
    final b64 = await _readKey();
    if (b64 == null) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

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
  /// key is gone. Throws [ViewerBundleAuthException] only if bundle and key are
  /// both present but mismatched (shouldn't happen via [save]).
  static Future<ViewerDataset?> load() async {
    final bundle = await rawBundle();
    final key = await rawKey();
    if (bundle == null || key == null) return null;
    return ViewerBundle.decode(bundle, key);
  }

  /// Forget the stored dataset entirely — file, key, and metadata.
  static Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
    await _secure.delete(key: _keyKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_countKey);
    await prefs.remove(_syncedAtKey);
  }
}
