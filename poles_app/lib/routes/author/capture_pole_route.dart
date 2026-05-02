import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/services/location_service.dart';
import 'package:poles/widgets/location_card.dart';

class CapturePoleRoute extends StatefulWidget {
  final PolesApi api;
  const CapturePoleRoute({super.key, required this.api});

  @override
  State<CapturePoleRoute> createState() => _CapturePoleRouteState();
}

class _CapturePoleRouteState extends State<CapturePoleRoute> {
  final _scannerController = MobileScannerController();
  final _labelController = TextEditingController();
  final _notesController = TextEditingController();

  String? _barcode;
  LocationFix? _fix;
  String? _locationError;
  bool _gettingFix = false;
  bool _submitting = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_barcode != null) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null) return;
    await _scannerController.stop();
    setState(() => _barcode = value);
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
    final fix = _fix;
    final barcode = _barcode;
    if (fix == null || barcode == null) return;

    setState(() => _submitting = true);
    try {
      await widget.api.createDraftPole(
        barcode: barcode,
        latitude: fix.latitude,
        longitude: fix.longitude,
        accuracyM: fix.accuracyM,
        label: _labelController.text.trim().isEmpty ? null : _labelController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pole submitted as draft.')),
      );
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = e.response?.data?['error']?['detail'] ??
          e.response?.data?['errors']?.toString() ??
          e.message;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submit failed: $detail')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
    }
  }

  void _reset() {
    setState(() {
      _barcode = null;
      _fix = null;
      _locationError = null;
      _labelController.clear();
      _notesController.clear();
    });
    _scannerController.start();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _labelController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _barcode != null && (_fix?.isUsable ?? false) && !_submitting;
    return Scaffold(
      appBar: AppBar(title: const Text('Capture a pole')),
      body: _barcode == null ? _scanner() : _form(canSubmit),
    );
  }

  Widget _scanner() => MobileScanner(controller: _scannerController, onDetect: _onDetect);

  Widget _form(bool canSubmit) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('Barcode: $_barcode',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              TextButton(onPressed: _reset, child: const Text('Re-scan')),
            ],
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
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Label (optional)',
              hintText: 'e.g. Portage and Main',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes for validators (optional)',
              hintText: 'Anything tricky about finding it',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: canSubmit ? _submit : null,
            icon: _submitting
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload),
            label: const Text('Submit draft'),
          ),
        ],
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
