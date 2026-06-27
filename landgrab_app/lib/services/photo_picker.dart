import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

class PhotoPicker {
  /// Prompt the user for a source, pick a photo, resize to <=1600px JPEG q=85.
  /// Returns null if the user cancelled.
  static Future<Uint8List?> pickAndResize(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked == null) return null;

    final resized = await FlutterImageCompress.compressWithFile(
      picked.path,
      minWidth: 1600,
      minHeight: 1600,
      quality: 85,
      format: CompressFormat.jpeg,
    );
    return resized ?? await File(picked.path).readAsBytes();
  }
}
