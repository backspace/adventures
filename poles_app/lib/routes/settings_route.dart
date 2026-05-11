import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:poles/flavors.dart';
import 'package:poles/services/env_service.dart';
import 'package:poles/services/user_service.dart';

Map<String, String> _knownEnvs() => {
  'Production': 'https://poles.chromatin.ca',
  'Staging': 'https://poles-staging.chromatin.ca',
  'Local': dotenv.maybeGet('LOCAL_API_ROOT') ?? 'http://localhost:4000',
};

class SettingsRoute extends StatefulWidget {
  const SettingsRoute({super.key});

  @override
  State<SettingsRoute> createState() => _SettingsRouteState();
}

class _SettingsRouteState extends State<SettingsRoute> {
  String? _currentOverride;
  String? _selected;
  final _customController = TextEditingController();
  bool _useCustom = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final override = await UserService.getApiRootOverride();
    if (!mounted) return;
    setState(() {
      _currentOverride = override;
      if (override != null) {
        final known = _knownEnvs().entries.firstWhere(
          (e) => e.value == override,
          orElse: () => const MapEntry('', ''),
        );
        if (known.key.isNotEmpty) {
          _selected = known.key;
        } else {
          _useCustom = true;
          _customController.text = override;
        }
      }
    });
  }

  Future<void> _save() async {
    final String? newRoot;
    if (_useCustom) {
      final url = _customController.text.trim();
      if (url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Custom URL is empty.')),
        );
        return;
      }
      newRoot = url;
    } else if (_selected != null) {
      newRoot = _knownEnvs()[_selected];
    } else {
      newRoot = null;
    }

    await EnvService.instance.switchTo(newRoot);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _reset() async {
    await EnvService.instance.switchTo(null);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Flavor', style: Theme.of(context).textTheme.labelSmall),
                  Text(F.title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Current override',
                      style: Theme.of(context).textTheme.labelSmall),
                  Text(_currentOverride ?? '(none — using build default)'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Switch environment',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _useCustom ? '__custom__' : _selected,
            onChanged: (v) => setState(() {
              if (v == '__custom__') {
                _useCustom = true;
                _selected = null;
              } else {
                _useCustom = false;
                _selected = v;
              }
            }),
            child: Column(
              children: [
                for (final entry in _knownEnvs().entries)
                  RadioListTile<String>(
                    title: Text(entry.key),
                    subtitle: Text(entry.value),
                    value: entry.key,
                  ),
                const RadioListTile<String>(
                  title: Text('Custom'),
                  value: '__custom__',
                ),
              ],
            ),
          ),
          if (_useCustom)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _customController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'API root URL',
                  hintText: 'https://...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (_currentOverride != null) ...[
                OutlinedButton(onPressed: _reset, child: const Text('Reset')),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
