import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:landgrab/widgets/scroll_insets.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/draft.dart';
import 'package:landgrab/services/discard_changes.dart';
import 'package:landgrab/widgets/action_snackbar.dart';
import 'package:landgrab/widgets/attachments_section.dart';
import 'package:landgrab/widgets/landgrab_app_bar.dart';
import 'package:landgrab/widgets/pole_form_fields.dart';
import 'package:landgrab/widgets/record_timestamps.dart';

class EditPoleRoute extends StatefulWidget {
  final LandgrabApi api;
  final DraftPole pole;

  /// When true the editor writes through the supervision endpoint (no approval,
  /// works at any status), hides the hard-delete, and shows photos view-only —
  /// the supervisor gets the author's exact form, just wired for their role.
  final bool asSupervisor;

  const EditPoleRoute({
    super.key,
    required this.api,
    required this.pole,
    this.asSupervisor = false,
  });

  @override
  State<EditPoleRoute> createState() => _EditPoleRouteState();
}

class _EditPoleRouteState extends State<EditPoleRoute> {
  final _fields = GlobalKey<PoleFormFieldsState>();
  bool _busy = false;
  bool _dirty = false;

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final data = _fields.currentState!.data;
      final changed = data.positionChanged;
      final updated = widget.asSupervisor
          ? await widget.api.supervisorEditPole(
              widget.pole.id,
              label: data.label,
              notes: data.notes,
              latitude: changed ? data.position.latitude : null,
              longitude: changed ? data.position.longitude : null,
              accuracyM: changed ? data.accuracyM : null,
              manualOffsetM: changed ? data.manualOffsetM : null,
              accessibilityTags: data.accessibilityTags,
              accessibilityNotes: data.accessibilityNotes,
            )
          : await widget.api.updateDraftPole(
              widget.pole.id,
              label: data.label,
              notes: data.notes,
              latitude: changed ? data.position.latitude : null,
              longitude: changed ? data.position.longitude : null,
              accuracyM: changed ? data.accuracyM : null,
              manualOffsetM: changed ? data.manualOffsetM : null,
              accessibilityTags: data.accessibilityTags,
              accessibilityNotes: data.accessibilityNotes,
            );
      if (!mounted) return;
      _dirty = false;
      final api = widget.api;
      final navigator = Navigator.of(context, rootNavigator: true);
      final messenger = ScaffoldMessenger.of(context);
      showActionSnackBar(messenger, SnackBar(
        content: Text(widget.asSupervisor ? 'Pole updated.' : 'Draft updated.'),
        action: SnackBarAction(
          label: 'Edit',
          onPressed: () {
            navigator.push(
              MaterialPageRoute(
                  builder: (_) => EditPoleRoute(
                      api: api,
                      pole: updated,
                      asSupervisor: widget.asSupervisor)),
            );
          },
        ),
      ));
      // Authors' callers await a bool ("did it change?"); the supervisor detail
      // route awaits the refreshed DraftPole to update its view in place. The
      // flag is set exactly when the caller expects the object, so this stays
      // type-safe.
      Navigator.of(context).pop(widget.asSupervisor ? updated : true);
    } on DioException catch (e) {
      _showError(e);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete draft?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await widget.api.deleteDraftPole(widget.pole.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Draft deleted.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  void _showError(DioException e) {
    if (!mounted) return;
    final detail = e.response?.data?['error']?['detail'] ??
        e.response?.data?['errors']?.toString() ??
        e.message;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Save failed: $detail')));
  }

  @override
  Widget build(BuildContext context) {
    final original = widget.pole;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await confirmDiscardChanges(context);
        if (discard && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: LandgrabAppBar(
          title: 'Edit pole',
        actions: [
          // Supervisors don't hard-delete — they retire ("Remove from game"),
          // which keeps the record. So the delete affordance is author-only.
          if (!widget.asSupervisor)
            IconButton(
              tooltip: 'Delete draft',
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: scrollInsets(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Barcode: ${original.barcode}',
                style: Theme.of(context).textTheme.titleMedium),
            RecordTimestamps(
              createdAt: original.insertedAt,
              updatedAt: original.updatedAt,
            ),
            const SizedBox(height: 16),
            PoleFormFields(
              key: _fields,
              initialLatitude: original.latitude,
              initialLongitude: original.longitude,
              initialAccuracyM: original.accuracyM,
              initialManualOffsetM: original.manualOffsetM,
              initialLabel: original.label,
              initialNotes: original.notes,
              initialAccessibilityTags: original.accessibilityTags,
              initialAccessibilityNotes: original.accessibilityNotes,
              onChanged: _markDirty,
            ),
            const SizedBox(height: 24),
            AttachmentsSection(
              api: widget.api,
              kind: AttachmentParentKind.pole,
              parentId: widget.pole.id,
              initialIds: widget.pole.attachmentIds,
              readOnly: widget.asSupervisor,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text('Save changes'),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
