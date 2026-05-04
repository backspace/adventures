import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/draft.dart';
import 'package:poles/services/location_service.dart';
import 'package:poles/widgets/location_card.dart';

class EditPoleRoute extends StatefulWidget {
  final PolesApi api;
  final DraftPole pole;

  const EditPoleRoute({super.key, required this.api, required this.pole});

  @override
  State<EditPoleRoute> createState() => _EditPoleRouteState();
}

class _EditPoleRouteState extends State<EditPoleRoute> {
  late final TextEditingController _labelController;
  late final TextEditingController _notesController;

  LocationFix? _newFix;
  String? _locationError;
  bool _gettingFix = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.pole.label ?? '');
    _notesController = TextEditingController(text: widget.pole.notes ?? '');
  }

  Future<void> _reacquireLocation() async {
    setState(() {
      _gettingFix = true;
      _locationError = null;
    });
    try {
      final fix = await LocationService.getCurrent();
      if (!mounted) return;
      setState(() {
        _newFix = fix;
        _gettingFix = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = e.toString();
        _gettingFix = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await widget.api.updateDraftPole(
        widget.pole.id,
        label: _labelController.text.trim(),
        notes: _notesController.text.trim(),
        latitude: _newFix?.latitude,
        longitude: _newFix?.longitude,
        accuracyM: _newFix?.accuracyM,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Draft updated.')));
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      _showError(e);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete draft?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await widget.api.deleteDraftPole(widget.pole.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Draft deleted.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  void _showError(DioException e) {
    if (!mounted) return;
    final detail = e.response?.data?['error']?['detail'] ??
        e.response?.data?['errors']?.toString() ??
        e.message;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Save failed: $detail')));
  }

  @override
  void dispose() {
    _labelController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final original = widget.pole;
    final fixForCard = _newFix ??
        LocationFix(
          latitude: original.latitude,
          longitude: original.longitude,
          accuracyM: original.accuracyM ?? 0,
          timestamp: DateTime.now(),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit pole'),
        actions: [
          IconButton(
            tooltip: 'Delete draft',
            onPressed: _busy ? null : _delete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Barcode: ${original.barcode}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            LocationCard(
              fix: fixForCard,
              error: _locationError,
              busy: _gettingFix,
              onRetry: _reacquireLocation,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Label (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes for validators (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
