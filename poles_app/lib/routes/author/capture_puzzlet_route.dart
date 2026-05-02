import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:poles/api/poles_api.dart';

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

  Future<void> _submit() async {
    final instructions = _instructionsController.text.trim();
    final answer = _answerController.text.trim();
    if (instructions.isEmpty || answer.isEmpty) return;

    setState(() => _submitting = true);
    try {
      await widget.api.createDraftPuzzlet(
        instructions: instructions,
        answer: answer,
        difficulty: _difficulty,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Submit a puzzlet')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Puzzlets are pooled and assigned to poles later by an admin. '
              'Difficulty is your initial estimate; validators may adjust it.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _instructionsController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Instructions',
                hintText: 'What does the player need to find or do?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _answerController,
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
              onPressed: _submitting ? null : _submit,
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
