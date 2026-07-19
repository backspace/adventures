import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:landgrab/flavors.dart';
import 'package:landgrab/l10n/player_strings.dart';
import 'package:landgrab/services/discard_changes.dart';
import 'package:landgrab/services/env_service.dart';
import 'package:landgrab/services/env_switch_service.dart';
import 'package:landgrab/services/theme_service.dart';
import 'package:landgrab/services/user_service.dart';
import 'package:landgrab/widgets/landgrab_app_bar.dart';

Map<String, String> _knownEnvs() => {
      'Production': 'https://landgrab.chromatin.ca',
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
  bool _dirty = false;

  List<SavedAccount> _accounts = const [];
  String? _currentUserId;

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

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
    // Attach dirty listener after initial state is set so loading doesn't
    // mark the form dirty.
    _customController.addListener(_markDirty);
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await UserService.getSavedAccounts();
    final currentId = await UserService.getUserId();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _currentUserId = currentId;
    });
  }

  Future<void> _switchAccount(SavedAccount a) async {
    await UserService.switchToAccount(a.id);
    // Reboot the app subtree onto the newly-active session. This route is
    // torn down with the old MaterialApp, so no explicit pop is needed.
    EnvService.instance.restartSession();
  }

  Future<void> _removeAccount(SavedAccount a) async {
    await UserService.removeSavedAccount(a.id);
    await _loadAccounts();
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
    _dirty = false;
    Navigator.of(context).pop();
  }

  Future<void> _reset() async {
    await EnvService.instance.switchTo(null);
    if (!mounted) return;
    _dirty = false;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await confirmDiscardChanges(context);
        if (discard && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: LandgrabAppBar(title: 'Settings'),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _appearanceSection(context),
            // The environment + account switchers are dev affordances — shown
            // only once the 7-tap Credits easter egg unlocks them.
            if (EnvSwitchService.visible.value) ...[
              const SizedBox(height: 24),
              Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Flavor',
                        style: Theme.of(context).textTheme.labelSmall),
                    Text(F.title,
                        style: Theme.of(context).textTheme.titleMedium),
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
                _dirty = true;
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              const SizedBox(height: 32),
              _accountsSection(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _appearanceSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(SettingsStrings.appearance, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeService.mode,
          builder: (context, mode, _) => SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(SettingsStrings.themeSystem),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(SettingsStrings.themeLight),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text(SettingsStrings.themeDark),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (s) => ThemeService.set(s.first),
          ),
        ),
      ],
    );
  }

  Widget _accountsSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Accounts on this environment',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Auto-remembered as you sign in. Tap one to switch instantly.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (_accounts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No saved accounts yet on this environment.'),
          )
        else
          for (final a in _accounts) _accountTile(context, a),
      ],
    );
  }

  Widget _accountTile(BuildContext context, SavedAccount a) {
    final theme = Theme.of(context);
    final isCurrent = a.id == _currentUserId;
    final detail = [
      if (a.roles.isNotEmpty) a.roles.join(', '),
      if (a.teamName != null) 'team: ${a.teamName}',
    ].join(' · ');

    return Card(
      color: isCurrent
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
          : null,
      child: ListTile(
        leading: Icon(isCurrent ? Icons.person : Icons.person_outline,
            color: isCurrent ? theme.colorScheme.primary : null),
        title: Text(a.email,
            style: isCurrent
                ? TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary)
                : null),
        subtitle: detail.isEmpty ? null : Text(detail),
        trailing: isCurrent
            ? const Chip(
                label: Text('current'),
                visualDensity: VisualDensity.compact,
              )
            : IconButton(
                tooltip: 'Forget this account',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _removeAccount(a),
              ),
        onTap: isCurrent ? null : () => _switchAccount(a),
      ),
    );
  }
}
