import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/services/photo_picker.dart';
import 'package:poles/services/user_service.dart';

enum AttachmentParentKind { pole, puzzlet }

class AttachmentsSection extends StatefulWidget {
  final PolesApi api;
  final AttachmentParentKind kind;
  final String parentId;
  final List<String> initialIds;

  const AttachmentsSection({
    super.key,
    required this.api,
    required this.kind,
    required this.parentId,
    required this.initialIds,
  });

  @override
  State<AttachmentsSection> createState() => _AttachmentsSectionState();
}

class _AttachmentsSectionState extends State<AttachmentsSection> {
  late List<String> _ids;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ids = [...widget.initialIds];
  }

  Future<void> _addPhoto() async {
    final bytes = await PhotoPicker.pickAndResize(context);
    if (bytes == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final id = widget.kind == AttachmentParentKind.pole
          ? await widget.api.uploadPoleAttachment(
              poleId: widget.parentId,
              bytes: bytes,
              filename: 'photo.jpg',
              contentType: 'image/jpeg',
            )
          : await widget.api.uploadPuzzletAttachment(
              puzzletId: widget.parentId,
              bytes: bytes,
              filename: 'photo.jpg',
              contentType: 'image/jpeg',
            );

      if (!mounted) return;
      setState(() {
        _ids = [..._ids, id];
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> _deleteAttachment(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await widget.api.deleteAttachment(id);
      if (!mounted) return;
      setState(() {
        _ids = _ids.where((x) => x != id).toList();
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Photos (${_ids.length})',
                style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _addPhoto,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_ids.isEmpty)
          Text('No photos yet.',
              style: Theme.of(context).textTheme.bodySmall)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _ids
                .map((id) => _Thumbnail(
                      api: widget.api,
                      attachmentId: id,
                      onDelete: () => _deleteAttachment(id),
                    ))
                .toList(),
          ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final PolesApi api;
  final String attachmentId;
  final VoidCallback onDelete;

  const _Thumbnail({
    required this.api,
    required this.attachmentId,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onDelete,
      onTap: () => _openFullScreen(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FutureBuilder<Uint8List?>(
          future: _fetchBytes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return _placeholder(child: const CircularProgressIndicator(strokeWidth: 2));
            }
            final bytes = snapshot.data;
            if (bytes == null) {
              return _placeholder(child: const Icon(Icons.broken_image));
            }
            return Image.memory(bytes, width: 96, height: 96, fit: BoxFit.cover);
          },
        ),
      ),
    );
  }

  Widget _placeholder({required Widget child}) => Container(
        width: 96,
        height: 96,
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: child,
      );

  Future<Uint8List?> _fetchBytes() async {
    try {
      final headers = await _authHeaders();
      final response = await api.dio.get<List<int>>(
        '/poles/attachments/$attachmentId/thumb',
        options: Options(
          responseType: ResponseType.bytes,
          headers: headers,
        ),
      );
      final data = response.data;
      return data == null ? null : Uint8List.fromList(data);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await UserService.getAccessToken();
    return token == null ? {} : {'Authorization': token};
  }

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenAttachment(
          api: api,
          attachmentId: attachmentId,
        ),
      ),
    );
  }
}

class _FullScreenAttachment extends StatelessWidget {
  final PolesApi api;
  final String attachmentId;

  const _FullScreenAttachment({required this.api, required this.attachmentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: FutureBuilder<Uint8List?>(
          future: _fetchBytes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const CircularProgressIndicator();
            }
            final bytes = snapshot.data;
            if (bytes == null) {
              return const Icon(Icons.broken_image, color: Colors.white, size: 64);
            }
            return InteractiveViewer(
              child: Image.memory(bytes),
            );
          },
        ),
      ),
    );
  }

  Future<Uint8List?> _fetchBytes() async {
    try {
      final token = await UserService.getAccessToken();
      final response = await api.dio.get<List<int>>(
        '/poles/attachments/$attachmentId',
        options: Options(
          responseType: ResponseType.bytes,
          headers: token == null ? {} : {'Authorization': token},
        ),
      );
      final data = response.data;
      return data == null ? null : Uint8List.fromList(data);
    } catch (_) {
      return null;
    }
  }
}
