import 'package:flutter/material.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/liberation_status.dart';

/// Supervisor "Liberation" tab: schedule the rollout window across which
/// Bedab's invitations trickle out team-by-team, and watch the progress
/// (invitations sent, answers in). The announcer polls every minute, so
/// schedule edits take effect without a restart — but invitations already
/// sent are never recalled.
class LiberationTab extends StatefulWidget {
  final LandgrabApi api;
  const LiberationTab({super.key, required this.api});

  @override
  State<LiberationTab> createState() => _LiberationTabState();
}

class _LiberationTabState extends State<LiberationTab> {
  LiberationStatus? _status;
  String? _error;
  bool _saving = false;

  // Form state (local edits; _status holds what the server has).
  DateTime? _startsAt;
  DateTime? _rolloutEndsAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final status = await widget.api.getLiberationStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _error = null;
        _startsAt = status.startsAt?.toLocal();
        _rolloutEndsAt = status.rolloutEndsAt?.toLocal();
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load liberation: $e');
    }
  }

  Future<void> _save({bool clear = false}) async {
    setState(() => _saving = true);
    try {
      final status = await widget.api.updateLiberationSchedule(
        startsAt: clear ? null : _startsAt,
        rolloutEndsAt: clear ? null : _rolloutEndsAt,
      );
      if (!mounted) return;
      setState(() {
        _status = status;
        _startsAt = status.startsAt?.toLocal();
        _rolloutEndsAt = status.rolloutEndsAt?.toLocal();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDateTime({required bool start}) async {
    final existing = (start ? _startsAt : _rolloutEndsAt) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: existing,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(existing),
    );
    if (time == null || !mounted) return;
    final combined =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (start) {
        _startsAt = combined;
      } else {
        _rolloutEndsAt = combined;
      }
    });
  }

  String _format(DateTime? value) {
    if (value == null) return 'not set';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Center(child: Text(_error!));
    final status = _status;
    if (status == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invitations', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    '${status.invited} of ${status.teamCount} teams invited',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${status.accepted} accepted · ${status.declined} declined · '
                    '${status.invited - status.accepted - status.declined} undecided',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Rollout schedule', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Invitations go out from Bedab, one team at a time, spread '
                    'across this window. No end time sends every invitation at '
                    'the start. Already-sent invitations are never recalled.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Invitations begin'),
                    subtitle: Text(_format(_startsAt)),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: _saving ? null : () => _pickDateTime(start: true),
                  ),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Rollout ends (optional)'),
                    subtitle: Text(_format(_rolloutEndsAt)),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: _saving ? null : () => _pickDateTime(start: false),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (status.startsAt != null) ...[
                        OutlinedButton(
                          onPressed: _saving ? null : () => _save(clear: true),
                          child: const Text('Cancel rollout'),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: FilledButton.icon(
                          onPressed:
                              _saving || _startsAt == null ? null : _save,
                          icon: const Icon(Icons.save),
                          label: const Text('Save schedule'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
