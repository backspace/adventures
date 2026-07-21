import 'package:flutter/material.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/relief_status.dart';

/// Supervisor "Relief" tab: the relief-valve toggle plus a readiness dashboard
/// (how much is still capturable, and an ownership leaderboard) so the
/// supervisor can judge whether the map is running dry and open the valve.
class ReliefTab extends StatefulWidget {
  final LandgrabApi api;
  const ReliefTab({super.key, required this.api});

  @override
  State<ReliefTab> createState() => _ReliefTabState();
}

class _ReliefTabState extends State<ReliefTab> {
  ReliefStatus? _relief;
  bool _reliefActive = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final relief = await widget.api.getReliefStatus();
      if (!mounted) return;
      setState(() {
        _relief = relief;
        _reliefActive = relief.active;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load relief status: $e');
    }
  }

  Future<void> _toggle(bool on) async {
    // Enabling messages every team, so confirm before the blast. (Disabling is
    // silent, so it needs no confirmation.)
    if (on) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Enable relief valve?'),
          content: const Text(
            'This re-opens stakes for per-team play and sends a message to '
            'every team that fully-captured zones can be revisited.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Enable & notify'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      final active = await widget.api.setReliefActive(on);
      if (!mounted) return;
      setState(() => _reliefActive = active);
      await _load(); // refresh the numbers for the new mode
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not change relief: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!),
            ),
          Card(
            child: SwitchListTile(
              value: _reliefActive,
              onChanged: _busy ? null : _toggle,
              title: const Text('Relief valve'),
              subtitle: const Text(
                'Re-open stakes so each team can solve puzzlets others already '
                'took. Use when the map is running dry.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_relief case final relief?) _dashboard(relief),
        ],
      ),
    );
  }

  // The readiness numbers + ownership leaderboard. `capturable` is the
  // headline: as it nears zero, the map's run dry and relief is worth it.
  Widget _dashboard(ReliefStatus relief) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${relief.capturableInPlay} of ${relief.totalPoles} stakes still capturable',
              style:
                  theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${relief.inPlay} in play · ${relief.notFullyCaptured} not fully captured',
              style: theme.textTheme.bodySmall,
            ),
            const Divider(height: 24),
            Text('Stakes owned', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            if (relief.leaderboard.isEmpty)
              Text('No stakes owned yet.', style: theme.textTheme.bodySmall)
            else
              for (final e in relief.leaderboard)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Expanded(
                      child: Text(e.name ?? '(unknown team)',
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text('${e.owned}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                ),
          ],
        ),
      ),
    );
  }
}
