import 'package:flutter/material.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/l10n/player_strings.dart';
import 'package:landgrab/routes/barcode_scanner_route.dart';
import 'package:landgrab/widgets/landgrab_app_bar.dart';

/// Lets a player join their team by scanning the team card's QR code or
/// typing the join code. Replaces the fiddly pre-event flow where every
/// teammate had to enter everyone else's exact email address. Pops
/// `true` on success so the caller can refresh.
class JoinTeamRoute extends StatefulWidget {
  final LandgrabApi api;
  const JoinTeamRoute({super.key, required this.api});

  @override
  State<JoinTeamRoute> createState() => _JoinTeamRouteState();
}

class _JoinTeamRouteState extends State<JoinTeamRoute> {
  final _codeController = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _scan() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerRoute(title: JoinTeamStrings.scanButton),
      ),
    );
    if (scanned == null || scanned.isEmpty || !mounted) return;
    _codeController.text = scanned;
    await _join(scanned);
  }

  Future<void> _join(String code) async {
    if (code.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final outcome = await widget.api.joinTeam(code);
    if (!mounted) return;
    if (outcome == JoinTeamOutcome.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(JoinTeamStrings.success)),
      );
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = outcome == JoinTeamOutcome.notFound
            ? JoinTeamStrings.notFound
            : JoinTeamStrings.failed;
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const LandgrabAppBar(title: JoinTeamStrings.appBarTitle),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(JoinTeamStrings.intro, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _scan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text(JoinTeamStrings.scanButton),
            ),
            const SizedBox(height: 20),
            Row(children: const [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(JoinTeamStrings.orDivider),
              ),
              Expanded(child: Divider()),
            ]),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onSubmitted: (v) => _join(v),
              decoration: const InputDecoration(
                labelText: JoinTeamStrings.codeLabel,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            FilledButton(
              onPressed: _busy ? null : () => _join(_codeController.text),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(JoinTeamStrings.joinButton),
            ),
          ],
        ),
      ),
    );
  }
}
