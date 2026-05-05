import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/draft.dart';

class SupervisorEditPuzzletRoute extends StatefulWidget {
  final PolesApi api;
  final DraftPuzzlet puzzlet;

  const SupervisorEditPuzzletRoute({
    super.key,
    required this.api,
    required this.puzzlet,
  });

  @override
  State<SupervisorEditPuzzletRoute> createState() =>
      _SupervisorEditPuzzletRouteState();
}

class _SupervisorEditPuzzletRouteState
    extends State<SupervisorEditPuzzletRoute> {
  late final TextEditingController _instructions;
  late final TextEditingController _answer;
  late int _difficulty;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _instructions = TextEditingController(text: widget.puzzlet.instructions);
    _answer = TextEditingController(text: widget.puzzlet.answer);
    _difficulty = widget.puzzlet.difficulty;
  }

  @override
  void dispose() {
    _instructions.dispose();
    _answer.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_instructions.text.trim().isEmpty || _answer.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Instructions and answer are required.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final updated = await widget.api.supervisorEditPuzzlet(
        widget.puzzlet.id,
        instructions: _instructions.text.trim(),
        answer: _answer.text.trim(),
        difficulty: _difficulty,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Puzzlet updated.')),
      );
      Navigator.of(context).pop(updated);
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = e.response?.data?['error']?['detail'] ??
          e.response?.data?['errors']?.toString() ??
          e.message;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save failed: $detail')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit puzzlet')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _instructions,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Instructions',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _answer,
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
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
