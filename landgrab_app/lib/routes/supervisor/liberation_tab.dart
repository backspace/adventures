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

  // Invitations summary + an expandable per-team breakdown. Collapsed it
  // shows the counts; expanded it groups every team by rollout stage into
  // tappable chips (tap → the team's members).
  Widget _invitationsCard(ThemeData theme, LiberationStatus status) {
    final undecided = status.invited - status.accepted - status.declined;
    return Card(
      child: Theme(
        // Drop the ExpansionTile's default divider lines for a cleaner card.
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text('Invitations', style: theme.textTheme.titleMedium),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${status.invited} of ${status.teamCount} invited · '
              '${status.accepted} accepted · ${status.declined} declined · '
              '$undecided undecided',
              style: theme.textTheme.bodySmall,
            ),
          ),
          children: [
            _teamGroup(theme, status, 'accepted', 'Accepted', Colors.green),
            _teamGroup(
                theme, status, 'declined', 'Declined', theme.colorScheme.error),
            _teamGroup(theme, status, 'invited', 'Invited — undecided',
                Colors.orange.shade800),
            _teamGroup(theme, status, 'uninvited', 'Not yet invited',
                theme.colorScheme.outline),
            if (status.teams.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('No teams yet.', style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }

  // One status group: a coloured heading and a wrap of team chips, or nothing
  // when no team is in this stage.
  Widget _teamGroup(ThemeData theme, LiberationStatus status, String key,
      String label, Color color) {
    final teams = status.teamsWithStatus(key);
    if (teams.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label (${teams.length})',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in teams)
                ActionChip(
                  avatar: Icon(Icons.group, size: 16, color: color),
                  label: Text(t.name),
                  onPressed: () => _showTeamMembers(t),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // Bottom sheet listing who's on the tapped team.
  void _showTeamMembers(LiberationTeam team) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final maxHeight = MediaQuery.of(ctx).size.height * 0.7;
        final n = team.members.length;
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(team.name, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text('$n member${n == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall),
                  const SizedBox(height: 12),
                  if (team.members.isEmpty)
                    const Text('No members.')
                  else
                    for (final m in team.members)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(Icons.person_outline),
                        title: Text(m.display),
                        // Only show the email as a subtitle when it isn't
                        // already the displayed handle.
                        subtitle: m.display == m.email ? null : Text(m.email),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
          _invitationsCard(theme, status),
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
