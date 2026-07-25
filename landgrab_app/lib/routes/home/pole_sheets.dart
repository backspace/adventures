import 'package:flutter/material.dart';
import 'package:landgrab/l10n/player_strings.dart';
import 'package:landgrab/models/pole.dart';
import 'package:landgrab/models/validator_only_puzzlet.dart';
import 'package:landgrab/routes/home/map_markers.dart';
import 'package:landgrab/widgets/accent_colors.dart';
import 'package:landgrab/widgets/accessibility_tags_view.dart';
import 'package:landgrab/widgets/region_context_card.dart';
import 'package:landgrab/widgets/team_style.dart';

/// Tap-a-pole detail surfaces for the gameplay map. Kept out of HomeRoute so a
/// change to what a pole tap shows lands here, not in the route's state class.
/// HomeRoute owns the map state and just calls these with the tapped pole.

/// The swatch beside the tap-a-zone text. An owned stake shows its owner's
/// team identity — colour + pattern, as a square so it doesn't read as a
/// (round) pole pin, matching the header and the zone fill. An unowned stake
/// has no team, so it falls back to the plain pole pin.
Widget _ownerSwatch(Pole pole, bool isMine, double size) {
  final idx = pole.currentOwnerColorIndex;
  final owned = pole.currentOwnerTeamId != null && idx != null;

  // Owned: the team-identity swatch — its white backing carries the map's
  // translucent fill, so the colour reads the same pale tint here (on the dark
  // snackbar) as it does over the light basemap. Unowned has no team, so the
  // plain pole pin.
  if (owned) return TeamSwatch(colorIndex: idx, isMine: isMine, size: size);
  return SizedBox(
    width: size,
    height: size,
    child: PoleDot(
      isMine: isMine,
      prohibitive: pole.prohibitive,
      locked: pole.locked,
      dimension: size,
    ),
  );
}

/// Show who holds the tapped stake (and its lock / under-attack / prohibitive
/// state). A stake carrying accessibility info gets a bottom sheet (room for
/// the tags/notes); everything else gets a compact snackbar. [underAttack] and
/// [teamId] come from HomeRoute's live state.
void showPoleOwner(
  BuildContext context, {
  required Pole pole,
  required String? teamId,
  required bool underAttack,
  bool lostContact = false,
}) {
  // A stake the shrinking boundary has swept out of play: its ground stays
  // painted, but the stake itself is gone. Report the lost contact (and who
  // last held it) rather than live owner / lock / attack state.
  if (lostContact) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: Row(children: [
          const Icon(Icons.sensors_off, color: Colors.white70),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
                GameplayStrings.zoneLostContact(pole.currentOwnerTeamName)),
          ),
        ]),
      ));
    return;
  }

  final idx = pole.currentOwnerColorIndex;
  final owned = pole.currentOwnerTeamId != null && idx != null;
  final isMine = pole.currentOwnerTeamId == teamId;
  final name = pole.currentOwnerTeamName;

  final owner = !owned
      ? (pole.liberated
          ? GameplayStrings.zoneLiberated
          : GameplayStrings.zoneUnclaimed)
      : isMine
          ? GameplayStrings.zoneOwnerYou(name)
          : GameplayStrings.zoneOwnerOther(name);
  // The name is the author's label or a stable generated handle — never the
  // barcode (withheld server-side so reading it off the map can't let someone
  // claim a stake without being there).
  //
  // Explain every distinct map icon: the owner line always, then a line per
  // marker state so a tap says what the icon means (lock, under-attack ring,
  // accessibility-blocked glyph). Locked and prohibitive are mutually exclusive
  // (a locked stake has no puzzlets left to conflict).
  final lines = <String>['${pole.name} — $owner'];
  if (pole.locked) {
    // "Fully captured" only fits an owned stake; an unclaimed (liberated) one
    // that's out of relics shouldn't claim to be captured.
    lines.add(pole.liberated
        ? GameplayStrings.zoneLockedUnclaimed
        : GameplayStrings.zoneLocked);
  }
  if (underAttack) lines.add(GameplayStrings.zoneUnderAttack);
  if (pole.prohibitive) lines.add(GameplayStrings.zoneProhibitive);
  final message = lines.join('\n');

  // A stake with accessibility notes/tags (flagged by the map's info badge)
  // gets a sheet instead of a snackbar, so there's room to lay the tags out as
  // chips and show the free-text notes.
  if (pole.hasAccessibilityInfo) {
    _showAccessibilitySheet(context, pole, isMine, message);
    return;
  }

  // Tapping a zone is a deliberate "what am I looking at?" — it must win over
  // any backlog of gameplay toasts, not wait behind them. clearSnackBars drops
  // the whole queue (not just the current one, which removeCurrentSnackBar did
  // — that still left the owner popup stuck behind the backlog) so it appears
  // at once.
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      content: Row(children: [
        // Owner identity beside the words: the team's colour + pattern (square)
        // for a claimed stake, or the plain pin for an unclaimed one.
        _ownerSwatch(pole, isMine, 24),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
      ]),
    ));
}

/// Sheet for a stake that carries accessibility info: the same glyph +
/// owner/state summary as the snackbar, followed by the tags (as chips, each
/// explaining itself on tap) and any free-text notes.
void _showAccessibilitySheet(
    BuildContext context, Pole pole, bool isMine, String message) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _ownerSwatch(pole, isMine, 28),
              const SizedBox(width: 12),
              Expanded(
                child:
                    Text(message, style: Theme.of(ctx).textTheme.bodyLarge),
              ),
            ]),
            const SizedBox(height: 20),
            AccessibilityTagsView(
              tags: pole.accessibilityTags,
              notes: pole.accessibilityNotes,
              title: GameplayStrings.zoneAccessibilityTitle,
              // Players get plain labels — the (i) explanation is author-facing.
              explainable: false,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Detail sheet for a validator-only puzzlet star (helpers only; players
/// never see these markers).
void showValidatorOnlySheet(BuildContext context, ValidatorOnlyPuzzlet p) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final amber = AccentColors.forBrightness(theme.brightness, Colors.amber);
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const ValidatorOnlyStar(size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Puzzlet · difficulty ${p.difficulty}',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              Text('Reserved for helpers · status: ${p.status}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
              if (p.region != null) ...[
                const SizedBox(height: 16),
                RegionContextCard(
                  breadcrumb: p.region!.breadcrumb,
                  stanzas: p.region!.stanzas,
                ),
              ],
              const SizedBox(height: 16),
              Text(p.instructions, style: theme.textTheme.bodyLarge),
              if (p.warning != null && p.warning!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: amber.fill,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: amber.border),
                  ),
                  child: Row(children: [
                    Icon(Icons.warning_amber_outlined,
                        size: 20, color: amber.ink),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(p.warning!,
                          style: TextStyle(color: amber.ink)),
                    ),
                  ]),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
