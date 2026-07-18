import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:landgrab/widgets/landgrab_app_bar.dart';

// Real-world chrome (an attribution list), not in-storyline — so the copy
// lives here rather than in player_strings.dart, like the Credits page.
const _appBarTitle = 'Server open-source licenses';
const _depsAsset = 'assets/licenses/server_deps.json';
const _textAssetDir = 'assets/licenses/texts';

const _unavailable = 'License information is unavailable.';

/// One server dependency, from the generated `server_deps.json` (see the
/// `mix landgrab.licenses` task in the registrations app).
class _Dep {
  final String name;
  final String? version;
  final List<String> licenses;
  _Dep(this.name, this.version, this.licenses);

  String get primaryLicense => licenses.isEmpty ? 'Unknown' : licenses.first;
  String get licenseLabel => licenses.isEmpty ? 'Unknown' : licenses.join(', ');
}

/// A separate, Flutter-independent counterpart to `showLicensePage()`: a
/// package-centric roll of the open-source software running the LANDGRAB
/// server, each crediting its authors, with the license a tap away.
class ServerLicensesRoute extends StatefulWidget {
  const ServerLicensesRoute({super.key});

  @override
  State<ServerLicensesRoute> createState() => _ServerLicensesRouteState();
}

class _ServerLicensesRouteState extends State<ServerLicensesRoute> {
  late final Future<List<_Dep>> _deps = _load();

  Future<List<_Dep>> _load() async {
    final raw = await rootBundle.loadString(_depsAsset);
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    final deps = list
        .map((m) => _Dep(
              m['name'] as String,
              m['version'] as String?,
              ((m['licenses'] as List?) ?? const []).cast<String>(),
            ))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return deps;
  }

  void _openLicense(String licenseId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _LicenseTextRoute(licenseId: licenseId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const LandgrabAppBar(title: _appBarTitle),
      body: FutureBuilder<List<_Dep>>(
        future: _deps,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final deps = snap.data;
          if (snap.hasError || deps == null || deps.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(_unavailable, textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: deps.length + 1,
            separatorBuilder: (context, i) =>
                i == 0 ? const SizedBox.shrink() : const Divider(height: 1),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Text(
                    'LANDGRAB’s server stands on ${deps.length} open-source '
                    'Elixir/Phoenix packages. Thanks to their authors. Tap any '
                    'one to read its license.',
                    style: theme.textTheme.bodySmall,
                  ),
                );
              }
              final d = deps[i - 1];
              return ListTile(
                title: Text(
                  d.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: d.version == null ? null : Text('v${d.version}'),
                trailing: Text(d.licenseLabel, style: theme.textTheme.labelSmall),
                onTap: () => _openLicense(d.primaryLicense),
              );
            },
          );
        },
      ),
    );
  }
}

class _LicenseTextRoute extends StatelessWidget {
  final String licenseId;
  const _LicenseTextRoute({required this.licenseId});

  Future<String> _load() async {
    try {
      return await rootBundle.loadString('$_textAssetDir/$licenseId.txt');
    } catch (_) {
      return 'The full text of the $licenseId license is not bundled. '
          'See https://spdx.org/licenses/ for the canonical text.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: LandgrabAppBar(title: licenseId),
      body: FutureBuilder<String>(
        future: _load(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              snap.data!,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.4,
              ),
            ),
          );
        },
      ),
    );
  }
}
