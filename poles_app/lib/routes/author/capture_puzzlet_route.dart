import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/services/location_service.dart';
import 'package:poles/widgets/location_card.dart';

class CapturePuzzletRoute extends StatefulWidget {
  final PolesApi api;
  const CapturePuzzletRoute({super.key, required this.api});

  @override
  State<CapturePuzzletRoute> createState() => _CapturePuzzletRouteState();
}

class _CapturePuzzletRouteState extends State<CapturePuzzletRoute> {
  final _instructionsController = TextEditingController();
  final _answerController = TextEditingController();
  int _difficulty = 3;
  bool _submitting = false;

  LocationFix? _fix;
  String? _locationError;
  bool _gettingFix = false;

  @override
  void initState() {
    super.initState();
    _captureLocation();
  }

  Future<void> _captureLocation() async {
    setState(() {
      _gettingFix = true;
      _locationError = null;
    });
    try {
      final fix = await LocationService.getCurrent();
      if (!mounted) return;
      setState(() {
        _fix = fix;
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

  Future<void> _submit() async {
    final instructions = _instructionsController.text.trim();
    final answer = _answerController.text.trim();
    final fix = _fix;
    if (instructions.isEmpty || answer.isEmpty || fix == null || !fix.isUsable) return;

    setState(() => _submitting = true);
    try {
      await widget.api.createDraftPuzzlet(
        instructions: instructions,
        answer: answer,
        difficulty: _difficulty,
        latitude: fix.latitude,
        longitude: fix.longitude,
        accuracyM: fix.accuracyM,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Puzzlet submitted as draft.')),
      );
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = e.response?.data?['error']?['detail'] ??
          e.response?.data?['errors']?.toString() ??
          e.message;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Submit failed: $detail')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Submit failed: $e')));
    }
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _fix?.isUsable == true &&
        !_submitting &&
        _instructionsController.text.trim().isNotEmpty &&
        _answerController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Submit a puzzlet')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Puzzlets are pooled and assigned to poles later by an admin. '
              'Capturing your location now helps the admin pair this puzzlet with the right pole. '
              'Difficulty is your initial estimate; validators may adjust it.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            LocationCard(
              fix: _fix,
              error: _locationError,
              busy: _gettingFix,
              onRetry: _captureLocation,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _instructionsController,
              minLines: 3,
              maxLines: 6,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Instructions',
                hintText: 'What does the player need to find or do?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _answerController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Answer',
                hintText: 'Case-insensitive, whitespace trimmed',
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
              onPressed: canSubmit ? _submit : null,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload),
              label: const Text('Submit draft'),
            ),
          ],
        ),
      ),
    );
  }
}
