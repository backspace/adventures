import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/draft.dart';
import 'package:poles/services/location_service.dart';
import 'package:poles/widgets/location_card.dart';

class EditPuzzletRoute extends StatefulWidget {
  final PolesApi api;
  final DraftPuzzlet puzzlet;

  const EditPuzzletRoute({super.key, required this.api, required this.puzzlet});

  @override
  State<EditPuzzletRoute> createState() => _EditPuzzletRouteState();
}

class _EditPuzzletRouteState extends State<EditPuzzletRoute> {
  late final TextEditingController _instructionsController;
  late final TextEditingController _answerController;
  late int _difficulty;

  LocationFix? _newFix;
  String? _locationError;
  bool _gettingFix = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _instructionsController =
        TextEditingController(text: widget.puzzlet.instructions);
    _answerController = TextEditingController(text: widget.puzzlet.answer);
    _difficulty = widget.puzzlet.difficulty;
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
      await widget.api.updateDraftPuzzlet(
        widget.puzzlet.id,
        instructions: _instructionsController.text.trim(),
        answer: _answerController.text.trim(),
        difficulty: _difficulty,
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
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
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
      await widget.api.deleteDraftPuzzlet(widget.puzzlet.id);
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
    _instructionsController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final original = widget.puzzlet;
    LocationFix? fixForCard = _newFix;
    if (fixForCard == null && original.latitude != null && original.longitude != null) {
      fixForCard = LocationFix(
        latitude: original.latitude!,
        longitude: original.longitude!,
        accuracyM: original.accuracyM ?? 0,
        timestamp: DateTime.now(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit puzzlet'),
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
            LocationCard(
              fix: fixForCard,
              error: _locationError,
              busy: _gettingFix,
              onRetry: _reacquireLocation,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _instructionsController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Instructions',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _answerController,
              decoration: const InputDecoration(
                labelText: 'Answer',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Difficulty: $_difficulty / 10'),
            Slider(
              value: _difficulty.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '$_difficulty',
              onChanged: (v) => setState(() => _difficulty = v.round()),
            ),
            const SizedBox(height: 16),
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
