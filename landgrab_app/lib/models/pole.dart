import 'package:landgrab/models/region.dart';

class Pole {
  final String id;
  // Human display name (the author label, or a stable server-generated one).
  // The scannable barcode is deliberately never sent to players.
  final String name;
  final double latitude;
  final double longitude;
  final String? currentOwnerTeamId;
  final String? currentOwnerTeamName;
  // Stable per-team colour slot from the server (ordinal). Drives the
  // team's colour+pattern on the map. Null when unowned.
  final int? currentOwnerColorIndex;
  final bool locked;

  /// Every remaining puzzlet here conflicts with the viewing team's
  /// accessibility needs — nobody on the team can engage anything (they can
  /// still claim it). Per-viewer, set on the pole-list fetch; the map flags it.
  final bool prohibitive;

  Pole({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.currentOwnerTeamId,
    this.currentOwnerTeamName,
    this.currentOwnerColorIndex,
    required this.locked,
    this.prohibitive = false,
  });

  factory Pole.fromJson(Map<String, dynamic> json) => Pole(
        id: json['id'] as String,
        name: json['name'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        currentOwnerTeamId: json['current_owner_team_id'] as String?,
        currentOwnerTeamName: json['current_owner_team_name'] as String?,
        currentOwnerColorIndex: json['current_owner_color_index'] as int?,
        locked: json['locked'] as bool? ?? false,
        prohibitive: json['prohibitive'] as bool? ?? false,
      );
}

class Puzzlet {
  final String id;
  final String instructions;
  final int difficulty;
  final int attemptsRemaining;
  final List<String> previousWrongAnswers;
  final String answerType;
  final String? warning;

  /// The region this puzzlet sits in (with its ancestor chain), or null
  /// if it isn't part of one. Carries the description / accessibility
  /// notes the player should see on arrival.
  final PuzzletRegion? region;

  Puzzlet({
    required this.id,
    required this.instructions,
    required this.difficulty,
    required this.attemptsRemaining,
    required this.previousWrongAnswers,
    this.answerType = 'loose_text',
    this.warning,
    this.region,
  });

  factory Puzzlet.fromJson(Map<String, dynamic> json) => Puzzlet(
        id: json['id'] as String,
        instructions: json['instructions'] as String,
        difficulty: json['difficulty'] as int,
        attemptsRemaining: json['attempts_remaining'] as int? ?? 0,
        previousWrongAnswers: (json['previous_wrong_answers'] as List?)
                ?.map((e) => e as String)
                .toList(growable: false) ??
            const [],
        answerType: json['answer_type'] as String? ?? 'loose_text',
        warning: json['warning'] as String?,
        region: json['region'] == null
            ? null
            : PuzzletRegion.fromJson(json['region'] as Map<String, dynamic>),
      );
}

/// The region a scanned puzzlet belongs to, as shown to the player.
/// [breadcrumb] is the full "root > … > self" path; [stanzas] carries
/// each level's description / accessibility notes, ordered root → self
/// with empty rows already dropped by the server.
class PuzzletRegion {
  final String name;
  final String breadcrumb;
  final List<InheritedStanza> stanzas;

  PuzzletRegion({
    required this.name,
    required this.breadcrumb,
    this.stanzas = const [],
  });

  factory PuzzletRegion.fromJson(Map<String, dynamic> json) => PuzzletRegion(
        name: json['name'] as String,
        breadcrumb: json['breadcrumb'] as String? ?? json['name'] as String,
        stanzas: (json['stanzas'] as List?)
                ?.map((e) => InheritedStanza.fromJson(e as Map<String, dynamic>))
                .toList(growable: false) ??
            const [],
      );
}

class ScanResult {
  final Pole pole;
  final Puzzlet? activePuzzlet;

  /// How many *other* teams currently hold an active puzzlet on this
  /// pole — so the UI can warn that it's contested.
  final int contendingTeams;

  /// The team's accessibility needs the served puzzlet conflicts with (empty
  /// when none). Non-empty → offer "we've got it / not this one" before
  /// committing, rather than deciding for them.
  final List<String> conflictTags;

  ScanResult({
    required this.pole,
    required this.activePuzzlet,
    this.contendingTeams = 0,
    this.conflictTags = const [],
  });

  bool get hasConflict => conflictTags.isNotEmpty;

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
        pole: Pole.fromJson(json['pole'] as Map<String, dynamic>),
        activePuzzlet: json['active_puzzlet'] == null
            ? null
            : Puzzlet.fromJson(json['active_puzzlet'] as Map<String, dynamic>),
        contendingTeams: (json['contending_teams'] as num?)?.toInt() ?? 0,
        conflictTags: (json['conflict_tags'] as List?)
                ?.map((e) => e as String)
                .toList(growable: false) ??
            const [],
      );
}

sealed class AttemptOutcome {
  const AttemptOutcome();
}

class AttemptCorrect extends AttemptOutcome {
  final String captureTeamId;
  final bool poleLocked;

  /// The capturing team's stable colour index, so the celebration can flood
  /// in the team's own colour. Null if the server didn't supply it (older
  /// build), in which case the celebration falls back to a default colour.
  final int? captureColorIndex;

  const AttemptCorrect({
    required this.captureTeamId,
    required this.poleLocked,
    this.captureColorIndex,
  });
}

class AttemptIncorrect extends AttemptOutcome {
  final int attemptsRemaining;
  final List<String> previousWrongAnswers;
  const AttemptIncorrect({
    required this.attemptsRemaining,
    required this.previousWrongAnswers,
  });
}

class AttemptLockedOut extends AttemptOutcome {
  const AttemptLockedOut();
}

class AttemptAlreadyCaptured extends AttemptOutcome {
  const AttemptAlreadyCaptured();
}

/// The puzzlet was withdrawn from the game (supervisor action) while the
/// team was working it — there's nothing to answer anymore.
class AttemptWithdrawn extends AttemptOutcome {
  const AttemptWithdrawn();
}

class AttemptAlreadyOwner extends AttemptOutcome {
  const AttemptAlreadyOwner();
}

/// The game is over (its endgame window has closed). Stakes can still
/// be scanned and relics viewed, but no relic can be captured — a
/// terminal state for the puzzlet screen, not a retryable failure.
class AttemptGameOver extends AttemptOutcome {
  const AttemptGameOver();
}

/// Catch-all for submissions the server rejected in a way the app
/// doesn't specifically model (e.g. 403 no_team) or that never
/// reached the server (network failure). Carries a display message
/// so the puzzlet screen can show it instead of hanging on a
/// spinner; the user can retry.
class AttemptFailed extends AttemptOutcome {
  final String message;
  const AttemptFailed(this.message);
}

sealed class ScanOutcome {
  const ScanOutcome();
}

class ScanFound extends ScanOutcome {
  final ScanResult result;
  const ScanFound(this.result);
}

class ScanUnknownBarcode extends ScanOutcome {
  const ScanUnknownBarcode();
}

class ScanAlreadyOwner extends ScanOutcome {
  final Pole pole;
  const ScanAlreadyOwner(this.pole);
}

class ScanTeamLockedOut extends ScanOutcome {
  final Pole pole;
  const ScanTeamLockedOut(this.pole);
}

/// The scanner authored this pole (or its puzzlet) — creators can't
/// capture their own content.
class ScanOwnCreation extends ScanOutcome {
  final Pole pole;
  const ScanOwnCreation(this.pole);
}

/// The endgame boundary has shrunk past this pole — it's out of play
/// for the rest of the event.
class ScanOutsideZone extends ScanOutcome {
  final Pole pole;
  const ScanOutsideZone(this.pole);
}

/// The simulation hasn't started yet — the server refuses scans until
/// its start time, even if the app somehow reaches the scanner early.
class ScanNotStarted extends ScanOutcome {
  const ScanNotStarted();
}

/// The team is already at its active-puzzlet limit; they must finish
/// or give up what they're on before picking up this one. Carries the
/// puzzlet(s) they currently hold so the dialog can name them.
class ScanAtCapacity extends ScanOutcome {
  final List<ScanResult> active;
  const ScanAtCapacity(this.active);
}
