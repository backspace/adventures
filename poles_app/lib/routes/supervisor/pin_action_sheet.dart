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
  Future<void> Function()? onUndone,
}) async {
  final result = await showModalBottomSheet<PinActionResult>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _PolePinSheet(api: api, pole: pole, onUndone: onUndone),
  );
  return result ?? PinActionResult.unchanged;
}

Future<PinActionResult> showPuzzletPinSheet(
  BuildContext context, {
  required PolesApi api,
  required DraftPuzzlet puzzlet,
  Future<void> Function()? onUndone,
}) async {
  final result = await showModalBottomSheet<PinActionResult>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) =>
        _PuzzletPinSheet(api: api, puzzlet: puzzlet, onUndone: onUndone),
  );
  return result ?? PinActionResult.unchanged;
}

class _PolePinSheet extends StatefulWidget {
  final PolesApi api;
  final DraftPole pole;
  final Future<void> Function()? onUndone;

  const _PolePinSheet({required this.api, required this.pole, this.onUndone});

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
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final validation =
          await widget.api.assignPoleValidation(widget.pole.id, picked.id);
      if (!mounted) return;
      // Capture before pop: the sheet's BuildContext won't be valid for
      // the snackbar action callback, but ScaffoldMessenger/Api/onUndone
      // references survive.
      final api = widget.api;
      final messenger = ScaffoldMessenger.of(context);
      final onUndone = widget.onUndone;
      Navigator.of(context).pop(PinActionResult.changed);
      messenger.showSnackBar(SnackBar(
        content: Text('Assigned to ${picked.name ?? picked.email}.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            try {
              await api.unassignPoleValidation(validation.id);
              await onUndone?.call();
            } on DioException catch (e) {
              final detail = e.response?.data?['error']?['detail'] ?? e.message;
              messenger.showSnackBar(
                  SnackBar(content: Text('Undo failed: $detail')));
            }
          },
        ),
      ));
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
        builder: (_) => PoleSupervisionDetailRoute(
          api: widget.api,
          pole: widget.pole,
          onChanged: widget.onUndone,
        ),
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
                StatusBadge(label: draftStatusLabel(p.status), color: statusColorFor(draftStatusLabel(p.status))),
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
  final Future<void> Function()? onUndone;

  const _PuzzletPinSheet({
    required this.api,
    required this.puzzlet,
    this.onUndone,
  });

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
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final validation =
          await widget.api.assignPuzzletValidation(widget.puzzlet.id, picked.id);
      if (!mounted) return;
      final api = widget.api;
      final messenger = ScaffoldMessenger.of(context);
      final onUndone = widget.onUndone;
      Navigator.of(context).pop(PinActionResult.changed);
      messenger.showSnackBar(SnackBar(
        content: Text('Assigned to ${picked.name ?? picked.email}.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            try {
              await api.unassignPuzzletValidation(validation.id);
              await onUndone?.call();
            } on DioException catch (e) {
              final detail = e.response?.data?['error']?['detail'] ?? e.message;
              messenger.showSnackBar(
                  SnackBar(content: Text('Undo failed: $detail')));
            }
          },
        ),
      ));
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
            PuzzletSupervisionDetailRoute(
          api: widget.api,
          puzzlet: widget.puzzlet,
          onChanged: widget.onUndone,
        ),
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
                StatusBadge(label: draftStatusLabel(p.status), color: statusColorFor(draftStatusLabel(p.status))),
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
