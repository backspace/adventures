import 'dart:io' show gzip;
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'package:landgrab/viewer/viewer_dataset.dart';

/// Thrown when a bundle can't be authenticated on decode — the passphrase is
/// wrong, or the bytes were tampered/corrupted. Kept distinct from a
/// [FormatException] (bad magic / not a bundle at all) so the UI can tell
/// "wrong password" apart from "this isn't a viewer bundle".
class ViewerBundleAuthException implements Exception {
  const ViewerBundleAuthException();
  @override
  String toString() => 'ViewerBundleAuthException: wrong passphrase or corrupt bundle';
}

/// Encrypted, compressed transport for a [ViewerDataset] — the payload that
/// moves device-to-device (as a file or a QR stream).
///
/// Pipeline: JSON → utf8 → gzip → AES-GCM-256, where the key is PBKDF2-HMAC-
/// SHA256 over the passphrase and a random per-bundle salt. GCM's tag
/// authenticates the ciphertext, so a wrong passphrase or a flipped bit fails
/// to decrypt rather than yielding plausible garbage.
///
/// Byte layout:
///   MAGIC(4) | SALT(16) | NONCE(12) | MAC(16) | CIPHERTEXT(gzip(json))
class ViewerBundle {
  static const List<int> _magic = [0x4C, 0x47, 0x56, 0x31]; // "LGV1"
  static const int _saltLen = 16;
  static const int _nonceLen = 12;
  static const int _macLen = 16;
  static const int _headerLen = 4 + _saltLen + _nonceLen + _macLen;
  static const int _pbkdf2Iterations = 100000;

  static final AesGcm _algorithm = AesGcm.with256bits();
  static final Pbkdf2 _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _pbkdf2Iterations,
    bits: 256,
  );

  /// Compress + encrypt [data] into a self-describing bundle.
  static Future<Uint8List> encode(
    ViewerDataset data, {
    required String passphrase,
  }) async {
    final compressed = gzip.encode(data.toJsonBytes());
    final salt = _randomBytes(_saltLen);
    final nonce = _randomBytes(_nonceLen);
    final key = await _deriveKey(passphrase, salt);

    final box = await _algorithm.encrypt(
      compressed,
      secretKey: key,
      nonce: nonce,
    );

    final out = BytesBuilder(copy: false)
      ..add(_magic)
      ..add(salt)
      ..add(nonce)
      ..add(box.mac.bytes)
      ..add(box.cipherText);
    return out.toBytes();
  }

  /// Decrypt + decompress a bundle back into a [ViewerDataset].
  ///
  /// Throws [FormatException] if [bundle] isn't a viewer bundle, and
  /// [ViewerBundleAuthException] if the passphrase is wrong or it's corrupt.
  static Future<ViewerDataset> decode(
    Uint8List bundle, {
    required String passphrase,
  }) async {
    if (bundle.length < _headerLen || !_startsWithMagic(bundle)) {
      throw const FormatException('Not a LANDGRAB viewer bundle');
    }
    var o = _magic.length;
    final salt = bundle.sublist(o, o += _saltLen);
    final nonce = bundle.sublist(o, o += _nonceLen);
    final mac = bundle.sublist(o, o += _macLen);
    final cipherText = bundle.sublist(o);

    final key = await _deriveKey(passphrase, salt);
    final box = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));

    final List<int> compressed;
    try {
      compressed = await _algorithm.decrypt(box, secretKey: key);
    } on SecretBoxAuthenticationError {
      throw const ViewerBundleAuthException();
    }
    return ViewerDataset.fromJsonBytes(gzip.decode(compressed));
  }

  static Future<SecretKey> _deriveKey(String passphrase, List<int> salt) =>
      _kdf.deriveKeyFromPassword(password: passphrase, nonce: salt);

  static bool _startsWithMagic(Uint8List b) {
    for (var i = 0; i < _magic.length; i++) {
      if (b[i] != _magic[i]) return false;
    }
    return true;
  }

  static Uint8List _randomBytes(int n) {
    final rng = Random.secure();
    final bytes = Uint8List(n);
    for (var i = 0; i < n; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return bytes;
  }
}
