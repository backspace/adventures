import 'package:flutter/material.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/draft.dart';
import 'package:landgrab/models/validation.dart';
import 'package:landgrab/routes/supervisor/content_tab.dart';
import 'package:landgrab/routes/supervisor/endgame_tab.dart';
import 'package:landgrab/routes/supervisor/organiser_messages_tab.dart';
import 'package:landgrab/widgets/landgrab_app_bar.dart';
import 'package:landgrab/widgets/status_badge.dart';

class SupervisorRoute extends StatefulWidget {
  final LandgrabApi api;
  const SupervisorRoute({super.key, required this.api});

  @override
  State<SupervisorRoute> createState() => _SupervisorRouteState();
}

class _SupervisorRouteState extends State<SupervisorRoute> {
  // Tab order — the Messages tab's index is the default landing spot
  // once the event is underway (that's mostly what a supervisor does
  // then); before the event they land on Overview for validation
  // triage.
  static const _overviewTab = 0;
  static const _messagesTab = 2;

  DashboardCounts? _counts;
  String? _error;
  // Null until the event's started state is known; gates the initial
  // tab so we pick the landing tab before the tabs first render (no
  // visible jump). See `_landingTab`.
  bool? _eventStarted;
  // While the Content tab is in draw-to-assign mode, freeze tab
  // swiping so the loop-drawing drag isn't stolen by the pager.
  bool _contentDrawing = false;

  @override
  void initState() {
    super.initState();
    _loadEvent();
    _load();
  }

  // Fetched once, before the tabs render, so `_landingTab` can pick
  // the initial tab without a jump. A failure defaults to Overview.
  Future<void> _loadEvent() async {
    try {
      final event = await widget.api.getEvent();
      if (mounted) setState(() => _eventStarted = event.started);
    } catch (_) {
      if (mounted) setState(() => _eventStarted = false);
    }
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
    // Wait for the event's started state so the first render lands on
    // the right tab (Messages once underway) rather than flashing
    // Overview first. It's a quick fetch.
    if (_eventStarted == null) {
      return Scaffold(
        appBar: LandgrabAppBar(title: 'Supervision'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 4,
      initialIndex: _eventStarted! ? _messagesTab : _overviewTab,
      child: Scaffold(
        appBar: LandgrabAppBar(
          title: 'Supervision',
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Content'),
              Tab(text: 'Messages'),
              Tab(text: 'Endgame'),
            ],
          ),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: TabBarView(
          physics: _contentDrawing
              ? const NeverScrollableScrollPhysics()
              : null,
          children: [
            _Overview(counts: _counts, error: _error),
            ContentTab(
              api: widget.api,
              counts: _counts,
              onChanged: _load,
              onDrawingChanged: (drawing) =>
                  setState(() => _contentDrawing = drawing),
            ),
            OrganiserMessagesTab(api: widget.api),
            EndgameTab(api: widget.api),
          ],
        ),
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

    final submittedTotal =
        counts!.poleValidationsSubmitted + counts!.puzzletValidationsSubmitted;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (submittedTotal > 0)
          Card(
            color: Colors.purple.shade50,
            child: ListTile(
              leading:
                  const Icon(Icons.assignment_turned_in, color: Colors.purple),
              title: Text(
                '$submittedTotal awaiting your review',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${counts!.poleValidationsSubmitted} pole · '
                '${counts!.puzzletValidationsSubmitted} puzzlet',
              ),
            ),
          ),
        if (submittedTotal > 0) const SizedBox(height: 16),
        _Section('Puzzlets by status', counts!.puzzlets),
        const SizedBox(height: 16),
        _Section('Poles by status', counts!.poles),
        const SizedBox(height: 16),
        _Section('Puzzlet validations', counts!.puzzletValidations),
        const SizedBox(height: 16),
        _Section('Pole validations', counts!.poleValidations),
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
    final entries = counts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
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
                    StatusBadge(
                        label: prettifyStatus(e.key),
                        color: statusColorFor(e.key)),
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
