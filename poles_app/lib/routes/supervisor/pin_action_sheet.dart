import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/draft.dart';
import 'package:poles/routes/supervisor/pole_supervision_detail_route.dart';
import 'package:poles/routes/supervisor/puzzlet_supervision_detail_route.dart';
import 'package:poles/routes/supervisor/validator_picker.dart';
import 'package:poles/widgets/status_badge.dart';

/// Returned to the map view: tells the parent whether to refresh.
enum PinActionResult { unchanged, changed }

Future<PinActionResult> showPolePinSheet(
  BuildContext context, {
  required PolesApi api,
  required DraftPole pole,
}) async {
  final result = await showModalBottomSheet<PinActionResult>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _PolePinSheet(api: api, pole: pole),
  );
  return result ?? PinActionResult.unchanged;
}

Future<PinActionResult> showPuzzletPinSheet(
  BuildContext context, {
  required PolesApi api,
  required DraftPuzzlet puzzlet,
}) async {
  final result = await showModalBottomSheet<PinActionResult>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _PuzzletPinSheet(api: api, puzzlet: puzzlet),
  );
  return result ?? PinActionResult.unchanged;
}

class _PolePinSheet extends StatefulWidget {
  final PolesApi api;
  final DraftPole pole;
  const _PolePinSheet({required this.api, required this.pole});

  @override
  State<_PolePinSheet> createState() => _PolePinSheetState();
}

class _PolePinSheetState extends State<_PolePinSheet> {
  bool _busy = false;

  Future<void> _quickAssign() async {
    final picked = await pickValidator(
      context,
      api: widget.api,
      excludeUserId: widget.pole.creatorId,
    );
    if (picked == null) return;

    setState(() => _busy = true);
    try {
      await widget.api.assignPoleValidation(widget.pole.id, picked.id);
      if (!mounted) return;
      Navigator.of(context).pop(PinActionResult.changed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Assigned to ${picked.name ?? picked.email}.')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final detail = e.response?.data?['error']?['detail'] ?? e.message;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Assign failed: $detail')));
    }
  }

  Future<void> _openDetail() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PoleSupervisionDetailRoute(api: widget.api, pole: widget.pole),
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop(
      changed == true ? PinActionResult.changed : PinActionResult.unchanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pole;
    final isDraft = p.status == DraftStatus.draft;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.label ?? p.barcode,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusBadge(label: p.status.name, color: statusColorFor(p.status.name)),
              ],
            ),
            const SizedBox(height: 4),
            Text(p.barcode, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(
              '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}'
              '${p.accuracyM != null ? ' · ±${p.accuracyM!.toStringAsFixed(0)} m' : ''}',
            ),
            if (p.notes != null) ...[
              const SizedBox(height: 8),
              Text(p.notes!),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (isDraft) ...[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _quickAssign,
                      icon: const Icon(Icons.assignment_ind),
                      label: const Text('Assign…'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _busy ? null : _openDetail,
                    child: const Text('Open'),
                  ),
                ] else
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _openDetail,
                      child: const Text('Open'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PuzzletPinSheet extends StatefulWidget {
  final PolesApi api;
  final DraftPuzzlet puzzlet;
  const _PuzzletPinSheet({required this.api, required this.puzzlet});

  @override
  State<_PuzzletPinSheet> createState() => _PuzzletPinSheetState();
}

class _PuzzletPinSheetState extends State<_PuzzletPinSheet> {
  bool _busy = false;

  Future<void> _quickAssign() async {
    final picked = await pickValidator(
      context,
      api: widget.api,
      excludeUserId: widget.puzzlet.creatorId,
    );
    if (picked == null) return;

    setState(() => _busy = true);
    try {
      await widget.api.assignPuzzletValidation(widget.puzzlet.id, picked.id);
      if (!mounted) return;
      Navigator.of(context).pop(PinActionResult.changed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Assigned to ${picked.name ?? picked.email}.')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final detail = e.response?.data?['error']?['detail'] ?? e.message;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Assign failed: $detail')));
    }
  }

  Future<void> _openDetail() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            PuzzletSupervisionDetailRoute(api: widget.api, puzzlet: widget.puzzlet),
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop(
      changed == true ? PinActionResult.changed : PinActionResult.unchanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.puzzlet;
    final isDraft = p.status == DraftStatus.draft;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.instructions,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(label: p.status.name, color: statusColorFor(p.status.name)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Answer: ${p.answer} · Difficulty ${p.difficulty}'),
            if (p.latitude != null && p.longitude != null) ...[
              const SizedBox(height: 4),
              Text(
                '${p.latitude!.toStringAsFixed(5)}, ${p.longitude!.toStringAsFixed(5)}'
                '${p.accuracyM != null ? ' · ±${p.accuracyM!.toStringAsFixed(0)} m' : ''}',
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (isDraft) ...[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _quickAssign,
                      icon: const Icon(Icons.assignment_ind),
                      label: const Text('Assign…'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _busy ? null : _openDetail,
                    child: const Text('Open'),
                  ),
                ] else
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _openDetail,
                      child: const Text('Open'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
