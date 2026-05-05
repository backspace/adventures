import 'package:flutter/material.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/draft.dart';
import 'package:poles/models/validation.dart';
import 'package:poles/routes/supervisor/pole_supervision_detail_route.dart';
import 'package:poles/routes/supervisor/puzzlet_supervision_detail_route.dart';
import 'package:poles/widgets/status_badge.dart';

class SupervisorRoute extends StatefulWidget {
  final PolesApi api;
  const SupervisorRoute({super.key, required this.api});

  @override
  State<SupervisorRoute> createState() => _SupervisorRouteState();
}

class _SupervisorRouteState extends State<SupervisorRoute> {
  DashboardCounts? _counts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final counts = await widget.api.supervisorDashboard();
      if (!mounted) return;
      setState(() => _counts = counts);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load dashboard: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Supervision'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Poles'),
            Tab(text: 'Puzzlets'),
          ]),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: TabBarView(children: [
          _Overview(counts: _counts, error: _error),
          _PolesTab(api: widget.api, onChanged: _load),
          _PuzzletsTab(api: widget.api, onChanged: _load),
        ]),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  final DashboardCounts? counts;
  final String? error;

  const _Overview({required this.counts, required this.error});

  @override
  Widget build(BuildContext context) {
    if (error != null) return Center(child: Text(error!));
    if (counts == null) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Section('Poles by status', counts!.poles),
        const SizedBox(height: 16),
        _Section('Puzzlets by status', counts!.puzzlets),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            title: const Text('Submitted validations'),
            subtitle: Text(
              '${counts!.poleValidationsSubmitted} pole · '
              '${counts!.puzzletValidationsSubmitted} puzzlet awaiting review',
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Map<String, int> counts;

  const _Section(this.title, this.counts);

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (entries.isEmpty) const Text('Nothing yet.'),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    StatusBadge(label: e.key, color: statusColorFor(e.key)),
                    const SizedBox(width: 12),
                    Text('${e.value}'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const _allPoleStatuses = ['draft', 'in_review', 'validated', 'retired'];

class _PolesTab extends StatefulWidget {
  final PolesApi api;
  final Future<void> Function() onChanged;

  const _PolesTab({required this.api, required this.onChanged});

  @override
  State<_PolesTab> createState() => _PolesTabState();
}

class _PolesTabState extends State<_PolesTab> {
  String _filter = 'draft';
  List<DraftPole>? _poles;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await widget.api.supervisionListPoles(status: _filter);
      if (!mounted) return;
      setState(() => _poles = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(8),
          child: Row(
            children: _allPoleStatuses
                .map((s) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(s),
                        selected: _filter == s,
                        onSelected: (_) {
                          setState(() => _filter = s);
                          _load();
                        },
                      ),
                    ))
                .toList(),
          ),
        ),
        Expanded(
          child: _error != null
              ? Center(child: Text(_error!))
              : _poles == null
                  ? const Center(child: CircularProgressIndicator())
                  : _poles!.isEmpty
                      ? const Center(child: Text('Nothing here.'))
                      : ListView.builder(
                          itemCount: _poles!.length,
                          itemBuilder: (_, i) {
                            final p = _poles![i];
                            return ListTile(
                              title: Row(
                                children: [
                                  Expanded(child: Text(p.label ?? p.barcode)),
                                  StatusBadge(
                                    label: p.status.name,
                                    color: statusColorFor(p.status.name),
                                  ),
                                ],
                              ),
                              subtitle: Text(p.barcode),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                final changed = await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => PoleSupervisionDetailRoute(
                                      api: widget.api,
                                      pole: p,
                                    ),
                                  ),
                                );
                                if (changed == true) {
                                  await _load();
                                  await widget.onChanged();
                                }
                              },
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

const _allPuzzletStatuses = ['draft', 'in_review', 'validated', 'retired'];

class _PuzzletsTab extends StatefulWidget {
  final PolesApi api;
  final Future<void> Function() onChanged;

  const _PuzzletsTab({required this.api, required this.onChanged});

  @override
  State<_PuzzletsTab> createState() => _PuzzletsTabState();
}

class _PuzzletsTabState extends State<_PuzzletsTab> {
  String _filter = 'draft';
  List<DraftPuzzlet>? _puzzlets;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await widget.api.supervisionListPuzzlets(status: _filter);
      if (!mounted) return;
      setState(() => _puzzlets = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(8),
          child: Row(
            children: _allPuzzletStatuses
                .map((s) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(s),
                        selected: _filter == s,
                        onSelected: (_) {
                          setState(() => _filter = s);
                          _load();
                        },
                      ),
                    ))
                .toList(),
          ),
        ),
        Expanded(
          child: _error != null
              ? Center(child: Text(_error!))
              : _puzzlets == null
                  ? const Center(child: CircularProgressIndicator())
                  : _puzzlets!.isEmpty
                      ? const Center(child: Text('Nothing here.'))
                      : ListView.builder(
                          itemCount: _puzzlets!.length,
                          itemBuilder: (_, i) {
                            final p = _puzzlets![i];
                            return ListTile(
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.instructions,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  StatusBadge(
                                    label: p.status.name,
                                    color: statusColorFor(p.status.name),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                'Difficulty ${p.difficulty} · Answer: ${p.answer}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                final changed = await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => PuzzletSupervisionDetailRoute(
                                      api: widget.api,
                                      puzzlet: p,
                                    ),
                                  ),
                                );
                                if (changed == true) {
                                  await _load();
                                  await widget.onChanged();
                                }
                              },
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
