import 'dart:io' show gzip;
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'package:landgrab/viewer/viewer_dataset.dart';

/// Thrown when a bundle can't be authenticated on decode — the key is wrong, or
/// the bytes were tampered/corrupted. Distinct from a [FormatException] (bad
/// magic / not a bundle) so the UI can tell the cases apart.
class ViewerBundleAuthException implements Exception {
  const ViewerBundleAuthException();
  @override
  String toString() =>
      'ViewerBundleAuthException: wrong key or corrupt bundle';
}

/// The output of [ViewerBundle.encode]: the encrypted bytes that live at rest,
/// and the random key that decrypts them. They are kept apart on purpose — the
/// file stores only [bytes] (ciphertext); the [key] goes to the keychain. Only
/// the transport (`forTransport`) ever puts them together, so a leaked file or
/// app binary carries no readable content.
class EncodedBundle {
  final Uint8List bytes;
  final Uint8List key;
  const EncodedBundle({required this.bytes, required this.key});
}

/// Compressed + authenticated-encrypted transport for a [ViewerDataset].
///
/// No passphrase: each bundle is encrypted under a fresh **random 256-bit key**
/// (AES-GCM), so there's nothing for anyone to remember. The key is delivered
/// with the transfer (see [forTransport]) and then held in the device keychain;
/// the encrypted file protects the content at rest, the keychain protects the
/// key. GCM's tag authenticates, so a wrong key or a flipped bit fails to
/// decrypt rather than yielding plausible garbage.
///
/// At-rest byte layout: `MAGIC(4) | NONCE(12) | MAC(16) | CIPHERTEXT(gzip(json))`
class ViewerBundle {
  static const List<int> _magic = [0x4C, 0x47, 0x56, 0x32]; // "LGV2"
  static const int _nonceLen = 12;
  static const int _macLen = 16;
  static const int _headerLen = 4 + _nonceLen + _macLen;

  /// Random key length (AES-256).
  static const int keyLen = 32;

  static final AesGcm _algorithm = AesGcm.with256bits();

  /// Compress + encrypt [data] under a fresh random key.
  static Future<EncodedBundle> encode(ViewerDataset data) async {
    final compressed = gzip.encode(data.toJsonBytes());
    final key = _randomBytes(keyLen);
    final nonce = _randomBytes(_nonceLen);

    final box = await _algorithm.encrypt(
      compressed,
      secretKey: SecretKey(key),
      nonce: nonce,
    );

    final out = BytesBuilder(copy: false)
      ..add(_magic)
      ..add(nonce)
      ..add(box.mac.bytes)
      ..add(box.cipherText);
    return EncodedBundle(bytes: out.toBytes(), key: key);
  }

  /// Decrypt + decompress [bundle] with [key] back into a [ViewerDataset].
  ///
  /// Throws [FormatException] if [bundle] isn't a viewer bundle, and
  /// [ViewerBundleAuthException] if the key is wrong or the bytes are corrupt.
  static Future<ViewerDataset> decode(Uint8List bundle, Uint8List key) async {
    if (bundle.length < _headerLen || !_startsWithMagic(bundle)) {
      throw const FormatException('Not a LANDGRAB viewer bundle');
    }
    var o = _magic.length;
    final nonce = bundle.sublist(o, o += _nonceLen);
    final mac = bundle.sublist(o, o += _macLen);
    final cipherText = bundle.sublist(o);

    final box = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));
    final List<int> compressed;
    try {
      compressed = await _algorithm.decrypt(box, secretKey: SecretKey(key));
    } on SecretBoxAuthenticationError {
      throw const ViewerBundleAuthException();
    }
    return ViewerDataset.fromJsonBytes(gzip.decode(compressed));
  }

  /// Pack a bundle + its key into the single blob that crosses the wire (QR
  /// stream): `KEY(32) | CIPHERTEXT_BUNDLE`. The receiver splits it with
  /// [fromTransport]. This is the only place the two are combined.
  static Uint8List forTransport(Uint8List bundle, Uint8List key) {
    if (key.length != keyLen) {
      throw ArgumentError('key must be $keyLen bytes');
    }
    return (BytesBuilder(copy: false)
          ..add(key)
          ..add(bundle))
        .toBytes();
  }

  /// Split a wire blob back into (key, bundle).
  static ({Uint8List key, Uint8List bundle}) fromTransport(Uint8List wire) {
    if (wire.length < keyLen + _headerLen) {
      throw const FormatException('Truncated viewer transport payload');
    }
    return (key: wire.sublist(0, keyLen), bundle: wire.sublist(keyLen));
  }

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
