import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/team_board.dart';
import 'package:landgrab/widgets/landgrab_tile_layer.dart';
import 'package:landgrab/widgets/region_context_card.dart';
import 'package:landgrab/widgets/team_style.dart';

/// Supervisor overview of who's working what, on one map. Every team is a dot
/// tethered to a stake: an active team orbits the stake it's working (in its
/// colour); an idle team is stranded, greyed, on the last stake it claimed.
/// Teams with no active work and nothing ever claimed can't be placed, so they
/// live behind a "no activity" button. Tap any team for its roster + status.
///
/// Teams have no real position, so markers orbit their stake and repel each
/// other (a light force relaxation) rather than stacking. Long names clip at
/// [_maxNameLen].
class TeamsTab extends StatefulWidget {
  final LandgrabApi api;
  const TeamsTab({super.key, required this.api});

  @override
  State<TeamsTab> createState() => _TeamsTabState();
}

const int _maxNameLen = 30;
String _clip(String s, [int max = _maxNameLen]) =>
    s.length <= max ? s : '${s.substring(0, max - 1).trimRight()}…';

// Orbit geometry, in metres of local ground distance. Labels are wider than
// dots, so give them more room to keep names legible.
const double _orbitRadiusM = 20;
const double _minSeparationM = 24;

class _TeamsTabState extends State<TeamsTab> {
  TeamBoard? _board;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final board = await widget.api.getSupervisionTeamBoard();
      if (!mounted) return;
      setState(() => _board = board);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load teams: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _centered(
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: const Text('Try again')),
        ]),
      );
    }
    final board = _board;
    if (board == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (board.teams.isEmpty) {
      return _centered(const Text('No teams yet.'));
    }

    // Build placements: one dot per (team, anchor stake).
    final placements = <_Placement>[];
    final noActivity = <BoardTeam>[];
    for (var i = 0; i < board.teams.length; i++) {
      final t = board.teams[i];
      if (t.active.isNotEmpty) {
        // A team can work several stakes at once — a dot on each.
        final seen = <String>{};
        for (final w in t.active) {
          final id = w.poleId;
          final pos = w.polePosition;
          if (id == null || pos == null || !seen.add(id)) continue;
          placements.add(_Placement(
              team: t, colorIndex: i, poleId: id, poleLabel: w.poleDisplay,
              polePos: pos, stale: false));
        }
      } else if (t.lastClaimed?.position != null) {
        placements.add(_Placement(
            team: t, colorIndex: i, poleId: t.lastClaimed!.id,
            poleLabel: t.lastClaimed!.display, polePos: t.lastClaimed!.position!,
            stale: true));
      } else {
        noActivity.add(t);
      }
    }

    if (placements.isEmpty) {
      return _centered(
        Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('No team activity to map yet.', textAlign: TextAlign.center),
          if (noActivity.isNotEmpty) ...[
            const SizedBox(height: 12),
            _noActivityButton(noActivity),
          ],
        ]),
      );
    }

    _layout(placements);

    final anchorPoles = <String, LatLng>{};
    for (final p in placements) {
      anchorPoles[p.poleId] = p.polePos;
    }

    final allPoints = <LatLng>[
      ...anchorPoles.values,
      for (final p in placements) p.pos,
    ];

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            // Match the other maps: allow everything but rotation, which is
            // too easy to trigger by accident with two fingers.
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            initialCameraFit: CameraFit.coordinates(
              coordinates: allPoints,
              padding: const EdgeInsets.all(48),
              maxZoom: 17,
            ),
          ),
          children: [
            landgrabTileLayer(context),
            PolylineLayer(polylines: [
              for (final p in placements)
                Polyline(
                  points: [p.polePos, p.pos],
                  strokeWidth: 1.3,
                  color: (p.stale
                          ? Colors.grey
                          : TeamStyle.forIndex(p.colorIndex).color)
                      .withValues(alpha: 0.45),
                ),
            ]),
            MarkerLayer(markers: [
              for (final entry in anchorPoles.entries)
                Marker(
                  point: entry.value,
                  width: 20,
                  height: 20,
                  child: _PoleDot(onTap: () => _showPoleTeams(entry.key, placements)),
                ),
            ]),
            // Idle chips first so active (current work) chips draw on top.
            MarkerLayer(markers: [
              for (final p in [...placements]
                ..sort((a, b) => (a.stale ? 0 : 1) - (b.stale ? 0 : 1)))
                Marker(
                  point: p.pos,
                  width: 200,
                  height: 34,
                  child: _TeamChip(
                    name: _clip(p.team.name),
                    color: TeamStyle.forIndex(p.colorIndex).color,
                    stale: p.stale,
                    onTap: () => _showTeamMembers(p.team),
                  ),
                ),
            ]),
          ],
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _mapButton(
                icon: Icons.refresh,
                label: 'Refresh',
                onPressed: _load,
              ),
              if (noActivity.isNotEmpty) ...[
                const SizedBox(height: 8),
                _noActivityButton(noActivity),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _noActivityButton(List<BoardTeam> teams) => _mapButton(
        icon: Icons.group_off_outlined,
        label: '${teams.length} idle · no activity',
        onPressed: () => _showTeamList(
          'Idle · no recorded activity',
          teams,
        ),
      );

  Widget _mapButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
          ]),
        ),
      ),
    );
  }

  Widget _centered(Widget child) =>
      Center(child: Padding(padding: const EdgeInsets.all(24), child: child));

  // Place each team dot around its stake, then relax so nearby dots (same or
  // neighbouring stakes) don't overlap. Works in a local metres projection so
  // the maths is plain Euclidean.
  void _layout(List<_Placement> placements) {
    final refLat = placements.map((p) => p.polePos.latitude).reduce((a, b) => a + b) /
        placements.length;
    final refLng = placements.map((p) => p.polePos.longitude).reduce((a, b) => a + b) /
        placements.length;
    const mPerLat = 111320.0;
    final mPerLng = 111320.0 * cos(refLat * pi / 180);
    double toX(LatLng p) => (p.longitude - refLng) * mPerLng;
    double toY(LatLng p) => (p.latitude - refLat) * mPerLat;
    LatLng fromXY(double x, double y) =>
        LatLng(refLat + y / mPerLat, refLng + x / mPerLng);

    final byPole = <String, List<_Placement>>{};
    for (final p in placements) {
      byPole.putIfAbsent(p.poleId, () => []).add(p);
    }

    final xs = <_Placement, double>{};
    final ys = <_Placement, double>{};
    byPole.forEach((poleId, group) {
      final cx = toX(group.first.polePos);
      final cy = toY(group.first.polePos);
      final k = group.length;
      // Grow the ring so a busy stake's dots still clear the min separation.
      final r = max(_orbitRadiusM, k * _minSeparationM / (2 * pi) + _orbitRadiusM * 0.5);
      final phase = (poleId.hashCode % 360) * pi / 180;
      for (var i = 0; i < k; i++) {
        final a = phase + 2 * pi * i / k;
        xs[group[i]] = cx + r * cos(a);
        ys[group[i]] = cy + r * sin(a);
      }
    });

    for (var iter = 0; iter < 80; iter++) {
      // Repel any two dots closer than the minimum separation.
      for (var i = 0; i < placements.length; i++) {
        for (var j = i + 1; j < placements.length; j++) {
          final a = placements[i], b = placements[j];
          var dx = xs[a]! - xs[b]!, dy = ys[a]! - ys[b]!;
          var d = sqrt(dx * dx + dy * dy);
          if (d < 1e-6) {
            dx = cos(i.toDouble());
            dy = sin(i.toDouble());
            d = 1;
          }
          if (d < _minSeparationM) {
            final push = (_minSeparationM - d) / 2;
            xs[a] = xs[a]! + dx / d * push;
            ys[a] = ys[a]! + dy / d * push;
            xs[b] = xs[b]! - dx / d * push;
            ys[b] = ys[b]! - dy / d * push;
          }
        }
      }
      // Spring each dot back toward its own stake's ring.
      for (final p in placements) {
        final cx = toX(p.polePos), cy = toY(p.polePos);
        var dx = xs[p]! - cx, dy = ys[p]! - cy;
        var d = sqrt(dx * dx + dy * dy);
        if (d < 1e-6) {
          dx = 1;
          dy = 0;
          d = 1;
        }
        final diff = (_orbitRadiusM - d) * 0.15;
        xs[p] = xs[p]! + dx / d * diff;
        ys[p] = ys[p]! + dy / d * diff;
      }
    }

    for (final p in placements) {
      p.pos = fromXY(xs[p]!, ys[p]!);
    }
  }

  // Sheet listing the teams anchored to a tapped stake.
  void _showPoleTeams(String poleId, List<_Placement> placements) {
    final here = placements.where((p) => p.poleId == poleId).toList();
    if (here.isEmpty) return;
    final label = here.first.poleLabel;
    final teams = here.map((p) => p.team).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    _showTeamList(_clip(label), teams);
  }

  void _showTeamList(String title, List<BoardTeam> teams) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final maxHeight = MediaQuery.of(ctx).size.height * 0.7;
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
                  Text(title, style: Theme.of(ctx).textTheme.titleLarge),
                  Text('${teams.length} team${teams.length == 1 ? '' : 's'}',
                      style: Theme.of(ctx).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  for (final t in teams)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.group),
                      title: Text(_clip(t.name)),
                      subtitle: Text(_statusLine(t)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _showTeamMembers(t);
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // One-line status: working (with stakes), idle-on-last-claim, or idle-blank.
  String _statusLine(BoardTeam t) {
    if (t.active.isNotEmpty) {
      final stakes = <String>[];
      for (final w in t.active) {
        if (!stakes.contains(w.poleDisplay)) stakes.add(w.poleDisplay);
      }
      final n = t.active.length;
      return 'Working $n puzzlet${n == 1 ? '' : 's'} · ${stakes.join(', ')}';
    }
    if (t.lastClaimed != null) {
      return 'Idle · last claimed ${t.lastClaimed!.display}';
    }
    return 'Idle · no recorded activity';
  }

  // Bottom sheet: the tapped team's status and roster.
  void _showTeamMembers(BoardTeam team) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final maxHeight = MediaQuery.of(ctx).size.height * 0.7;
        final n = team.members.length;
        final idleOnClaim = team.active.isEmpty && team.lastClaimed != null;
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
                  Text(_clip(team.name), style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(_statusLine(team), style: theme.textTheme.bodyMedium),
                  if (idleOnClaim)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Shown greyed on its last-claimed pole — it has no '
                        'puzzlet in progress right now.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (team.active.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Puzzlets in progress', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    for (final w in team.active)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: OutlinedButton.icon(
                          onPressed: () => _showPuzzlet(w),
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          label: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${w.poleDisplay} · difficulty ${w.puzzletDifficulty ?? '?'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            minimumSize: const Size.fromHeight(44),
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  Text('$n member${n == 1 ? '' : 's'}',
                      style: theme.textTheme.labelLarge),
                  if (team.members.isEmpty)
                    const Text('No members.')
                  else
                    for (final m in team.members)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(Icons.person_outline),
                        title: Text(m.display),
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

  // Detail sheet for one active puzzlet: instructions, answer, and region.
  void _showPuzzlet(ActiveWork w) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final maxHeight = MediaQuery.of(ctx).size.height * 0.85;
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
                  Text(_clip(w.poleDisplay), style: theme.textTheme.titleLarge),
                  Text('Difficulty ${w.puzzletDifficulty ?? '?'}',
                      style: theme.textTheme.bodySmall),
                  if (w.region != null) ...[
                    const SizedBox(height: 12),
                    RegionContextCard(
                      breadcrumb: w.region!.breadcrumb,
                      stanzas: w.region!.stanzas,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text('Instructions', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(w.puzzletInstructions ?? '(none)',
                      style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Answer',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                            )),
                        const SizedBox(height: 2),
                        SelectableText(
                          w.puzzletAnswer ?? '(none)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A stake anchor and where one team's dot orbiting it ended up.
class _Placement {
  final BoardTeam team;
  final int colorIndex;
  final String poleId;
  final String poleLabel;
  final LatLng polePos;
  final bool stale;
  LatLng pos;

  _Placement({
    required this.team,
    required this.colorIndex,
    required this.poleId,
    required this.poleLabel,
    required this.polePos,
    required this.stale,
  }) : pos = polePos;
}

/// The stake anchor marker — a small dark ring the team dots tether to.
class _PoleDot extends StatelessWidget {
  final VoidCallback onTap;
  const _PoleDot({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: scheme.onSurface,
            shape: BoxShape.circle,
            border: Border.all(color: scheme.surface, width: 2),
          ),
        ),
      ),
    );
  }
}

/// A team label on the map — a colour dot + the team's (clipped) name on a
/// legible pill, so you can find people at a glance. Active teams show in
/// their colour; idle teams are greyed and muted with a history glyph.
class _TeamChip extends StatelessWidget {
  final String name;
  final Color color;
  final bool stale;
  final VoidCallback onTap;
  const _TeamChip({
    required this.name,
    required this.color,
    required this.stale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = stale ? Colors.grey : color;
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Container(
          padding: const EdgeInsets.fromLTRB(5, 3, 8, 3),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: accent, width: 1.5),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 2, offset: Offset(0, 1)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (stale)
                Icon(Icons.history, size: 12, color: accent)
              else
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                ),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 165),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: stale ? FontStyle.italic : FontStyle.normal,
                    color: stale
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
