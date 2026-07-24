import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:landgrab/widgets/scroll_insets.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/draft.dart';
import 'package:landgrab/models/region.dart';
import 'package:landgrab/services/discard_changes.dart';
import 'package:landgrab/services/location_service.dart';
import 'package:landgrab/widgets/action_snackbar.dart';
import 'package:landgrab/widgets/attachments_section.dart';
import 'package:landgrab/widgets/landgrab_app_bar.dart';
import 'package:landgrab/widgets/location_card.dart';
import 'package:landgrab/widgets/puzzlet_form_fields.dart';
import 'package:landgrab/widgets/region_picker_field.dart';
import 'package:landgrab/widgets/record_timestamps.dart';

class EditPuzzletRoute extends StatefulWidget {
  final LandgrabApi api;
  final DraftPuzzlet puzzlet;

  /// When true the editor writes through the supervision endpoint (no approval,
  /// works at any status), hides the hard-delete, and shows photos view-only —
  /// the supervisor gets the author's exact form, just wired for their role.
  final bool asSupervisor;

  const EditPuzzletRoute({
    super.key,
    required this.api,
    required this.puzzlet,
    this.asSupervisor = false,
  });

  @override
  State<EditPuzzletRoute> createState() => _EditPuzzletRouteState();
}

class _EditPuzzletRouteState extends State<EditPuzzletRoute> {
  final _fields = GlobalKey<PuzzletFormFieldsState>();
  late bool _validatorOnly;
  Region? _region;
  bool _regionChanged = false;

  LocationFix? _newFix;
  String? _locationError;
  bool _gettingFix = false;
  bool _busy = false;
  bool _dirty = false;

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void initState() {
    super.initState();
    _validatorOnly = widget.puzzlet.validatorOnly;

    if (widget.puzzlet.regionId != null) {
      _loadRegion(widget.puzzlet.regionId!);
    }
  }

  Future<void> _loadRegion(String id) async {
    try {
      final region = await widget.api.getRegion(id);
      if (!mounted) return;
      setState(() => _region = region);
    } catch (_) {
      // Best-effort: leave _region null; the user can re-pick if needed.
    }
  }

  Future<void> _reacquireLocation() async {
    setState(() {
      _gettingFix = true;
      _locationError = null;
    });
    try {
      final fix = await LocationService.getCurrent(context: context);
      if (!mounted) return;
      setState(() {
        _newFix = fix;
        _gettingFix = false;
        _dirty = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = e.toString();
        _gettingFix = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final data = _fields.currentState!.data;
      final updated = widget.asSupervisor
          ? await widget.api.supervisorEditPuzzlet(
              widget.puzzlet.id,
              instructions: data.instructions,
              answer: data.answer,
              answerType: data.answerType,
              difficulty: data.difficulty,
              latitude: _newFix?.latitude,
              longitude: _newFix?.longitude,
              accuracyM: _newFix?.accuracyM,
              accessibilityTags: data.accessibilityTags,
              accessibilityNotes: data.accessibilityNotes,
              regionId: _regionChanged ? _region?.id : null,
              clearRegion: _regionChanged && _region == null,
              warning: data.warning,
              validatorOnly: _validatorOnly,
            )
          : await widget.api.updateDraftPuzzlet(
              widget.puzzlet.id,
              instructions: data.instructions,
              answer: data.answer,
              answerType: data.answerType,
              difficulty: data.difficulty,
              latitude: _newFix?.latitude,
              longitude: _newFix?.longitude,
              accuracyM: _newFix?.accuracyM,
              accessibilityTags: data.accessibilityTags,
              accessibilityNotes: data.accessibilityNotes,
              regionId: _regionChanged ? _region?.id : null,
              clearRegion: _regionChanged && _region == null,
              warning: data.warning,
              validatorOnly: _validatorOnly,
            );
      if (!mounted) return;
      _dirty = false;
      final api = widget.api;
      final navigator = Navigator.of(context, rootNavigator: true);
      final messenger = ScaffoldMessenger.of(context);
      showActionSnackBar(messenger, SnackBar(
        content: Text(widget.asSupervisor ? 'Puzzlet updated.' : 'Draft updated.'),
        action: SnackBarAction(
          label: 'Edit',
          onPressed: () {
            navigator.push(
              MaterialPageRoute(
                  builder: (_) => EditPuzzletRoute(
                      api: api,
                      puzzlet: updated,
                      asSupervisor: widget.asSupervisor)),
            );
          },
        ),
      ));
      // Authors' callers await a bool ("did it change?"); the supervisor detail
      // route awaits the refreshed DraftPuzzlet to update its view in place. The
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
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
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
      await widget.api.deleteDraftPuzzlet(widget.puzzlet.id);
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
    final original = widget.puzzlet;
    LocationFix? fixForCard = _newFix;
    if (fixForCard == null && original.latitude != null && original.longitude != null) {
      fixForCard = LocationFix(
        latitude: original.latitude!,
        longitude: original.longitude!,
        accuracyM: original.accuracyM ?? 0,
        timestamp: DateTime.now(),
      );
    }

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
          title: 'Edit puzzlet',
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
            RecordTimestamps(
              createdAt: original.insertedAt,
              updatedAt: original.updatedAt,
            ),
            LocationCard(
              fix: fixForCard,
              error: _locationError,
              busy: _gettingFix,
              onRetry: _reacquireLocation,
            ),
            const SizedBox(height: 16),
            RegionPickerField(
              api: widget.api,
              selected: _region,
              // Region create/edit is author-only; supervisors pick from
              // existing regions.
              allowManage: !widget.asSupervisor,
              onChanged: (r) => setState(() {
                _region = r;
                _regionChanged = true;
                _dirty = true;
              }),
            ),
            const SizedBox(height: 8),
            // Validator-only flag. When set, the puzzlet is invisible
            // to players — it shows only on the author + validator
            // maps, tagged with a star, and doesn't count toward
            // pole locking. Ergonomically a SwitchListTile is more
            // "committed" than a Checkbox for a mode-toggling flag.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _validatorOnly,
              onChanged: (v) => setState(() {
                _validatorOnly = v;
                _dirty = true;
              }),
              title: const Text('For validators only'),
              subtitle: const Text(
                'Hide from players. Shown starred on author and validator maps.',
              ),
              secondary: const Icon(Icons.star_outline),
            ),
            const SizedBox(height: 12),
            PuzzletFormFields(
              key: _fields,
              initialInstructions: original.instructions,
              initialAnswer: original.answer,
              initialAnswerType: original.answerType,
              initialDifficulty: original.difficulty,
              initialWarning: original.warning,
              initialAccessibilityTags: original.accessibilityTags,
              initialAccessibilityNotes: original.accessibilityNotes,
              onChanged: _markDirty,
              accessibilityInheritedSection:
                  (original.inheritedStanzas.isNotEmpty ||
                          original.inheritedTags.isNotEmpty)
                      ? _InheritedAccessibilitySection(
                          tags: original.inheritedTags,
                          stanzas: original.inheritedStanzas,
                        )
                      : null,
            ),
            const SizedBox(height: 16),
            AttachmentsSection(
              api: widget.api,
              kind: AttachmentParentKind.puzzlet,
              parentId: widget.puzzlet.id,
              initialIds: widget.puzzlet.attachmentIds,
              readOnly: widget.asSupervisor,
            ),
            const SizedBox(height: 16),
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

/// Read-only display of accessibility content inherited from the puzzlet's
/// region chain. Shown above the puzzlet's own editable fields so the
/// author can see what's already covered and avoid duplicating it.
class _InheritedAccessibilitySection extends StatelessWidget {
  final List<String> tags;
  final List<InheritedStanza> stanzas;

  const _InheritedAccessibilitySection({
    required this.tags,
    required this.stanzas,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: theme.hintColor),
              const SizedBox(width: 6),
              Text('Inherited from region',
                  style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor)),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: tags
                  .map((t) => Chip(
                        label: Text(t),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
          for (final s in stanzas) ...[
            const SizedBox(height: 8),
            Text(s.source, style: theme.textTheme.labelSmall),
            if (s.notes != null && s.notes!.isNotEmpty)
              Text(s.notes!, style: theme.textTheme.bodySmall),
            if (s.entryInstructions != null && s.entryInstructions!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Entry: ${s.entryInstructions!}',
                    style: theme.textTheme.bodySmall),
              ),
          ],
        ],
      ),
    );
  }
}
