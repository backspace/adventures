import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/draft.dart';

class SupervisorEditPoleRoute extends StatefulWidget {
  final PolesApi api;
  final DraftPole pole;

  const SupervisorEditPoleRoute({
    super.key,
    required this.api,
    required this.pole,
  });

  @override
  State<SupervisorEditPoleRoute> createState() => _SupervisorEditPoleRouteState();
}

class _SupervisorEditPoleRouteState extends State<SupervisorEditPoleRoute> {
  late final TextEditingController _barcode;
  late final TextEditingController _label;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _notes;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _barcode = TextEditingController(text: widget.pole.barcode);
    _label = TextEditingController(text: widget.pole.label ?? '');
    _latitude = TextEditingController(text: widget.pole.latitude.toString());
    _longitude = TextEditingController(text: widget.pole.longitude.toString());
    _notes = TextEditingController(text: widget.pole.notes ?? '');
  }

  @override
  void dispose() {
    _barcode.dispose();
    _label.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final lat = double.tryParse(_latitude.text.trim());
    final lng = double.tryParse(_longitude.text.trim());

    if (_barcode.text.trim().isEmpty || lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barcode and valid coordinates are required.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final updated = await widget.api.supervisorEditPole(
        widget.pole.id,
        barcode: _barcode.text.trim(),
        label: _label.text.trim(),
        notes: _notes.text.trim(),
        latitude: lat,
        longitude: lng,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pole updated.')),
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
      appBar: AppBar(title: const Text('Edit pole')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _barcode,
              decoration: const InputDecoration(
                labelText: 'Barcode',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _label,
              decoration: const InputDecoration(
                labelText: 'Label',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latitude,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true, decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _longitude,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true, decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
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
