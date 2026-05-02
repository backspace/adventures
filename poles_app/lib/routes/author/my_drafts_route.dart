import 'package:flutter/material.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/draft.dart';

class MyDraftsRoute extends StatefulWidget {
  final PolesApi api;
  const MyDraftsRoute({super.key, required this.api});

  @override
  State<MyDraftsRoute> createState() => _MyDraftsRouteState();
}

class _MyDraftsRouteState extends State<MyDraftsRoute> {
  MyDrafts? _drafts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final drafts = await widget.api.listMyDrafts();
      if (!mounted) return;
      setState(() => _drafts = drafts);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load drafts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final drafts = _drafts;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My drafts'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : drafts == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    if (drafts.poles.isEmpty && drafts.puzzlets.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('Nothing yet. Capture a pole or puzzlet.')),
                      ),
                    if (drafts.poles.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text('Poles', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ...drafts.poles.map((p) => _PoleTile(pole: p)),
                    if (drafts.puzzlets.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text('Puzzlets', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ...drafts.puzzlets.map((p) => _PuzzletTile(puzzlet: p)),
                  ],
                ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final DraftStatus status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      DraftStatus.draft => ('draft', Colors.orange.shade700),
      DraftStatus.validated => ('validated', Colors.green.shade700),
      DraftStatus.retired => ('retired', Colors.grey.shade700),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

class _PoleTile extends StatelessWidget {
  final DraftPole pole;
  const _PoleTile({required this.pole});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Row(
        children: [
          Expanded(child: Text(pole.label ?? pole.barcode)),
          _StatusBadge(pole.status),
        ],
      ),
      subtitle: Text(
        '${pole.barcode}\n'
        '${pole.latitude.toStringAsFixed(5)}, ${pole.longitude.toStringAsFixed(5)}'
        '${pole.accuracyM != null ? ' · ±${pole.accuracyM!.toStringAsFixed(0)} m' : ''}',
      ),
      isThreeLine: true,
    );
  }
}

class _PuzzletTile extends StatelessWidget {
  final DraftPuzzlet puzzlet;
  const _PuzzletTile({required this.puzzlet});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Row(
        children: [
          Expanded(
            child: Text(
              puzzlet.instructions,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _StatusBadge(puzzlet.status),
        ],
      ),
      subtitle: Text(
        'Answer: ${puzzlet.answer} · Difficulty ${puzzlet.difficulty}'
        '${puzzlet.poleId == null ? ' · unassigned' : ''}',
      ),
    );
  }
}
