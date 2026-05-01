class Pole {
  final String id;
  final String barcode;
  final String? label;
  final double latitude;
  final double longitude;
  final String? currentOwnerTeamId;
  final bool locked;

  Pole({
    required this.id,
    required this.barcode,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.currentOwnerTeamId,
    required this.locked,
  });

  factory Pole.fromJson(Map<String, dynamic> json) => Pole(
        id: json['id'] as String,
        barcode: json['barcode'] as String,
        label: json['label'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        currentOwnerTeamId: json['current_owner_team_id'] as String?,
        locked: json['locked'] as bool? ?? false,
      );
}

class Puzzlet {
  final String id;
  final String instructions;
  final int difficulty;
  final int attemptsRemaining;

  Puzzlet({
    required this.id,
    required this.instructions,
    required this.difficulty,
    required this.attemptsRemaining,
  });

  factory Puzzlet.fromJson(Map<String, dynamic> json) => Puzzlet(
        id: json['id'] as String,
        instructions: json['instructions'] as String,
        difficulty: json['difficulty'] as int,
        attemptsRemaining: json['attempts_remaining'] as int? ?? 0,
      );
}

class ScanResult {
  final Pole pole;
  final Puzzlet? activePuzzlet;

  ScanResult({required this.pole, required this.activePuzzlet});

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
        pole: Pole.fromJson(json['pole'] as Map<String, dynamic>),
        activePuzzlet: json['active_puzzlet'] == null
            ? null
            : Puzzlet.fromJson(json['active_puzzlet'] as Map<String, dynamic>),
      );
}

sealed class AttemptOutcome {
  const AttemptOutcome();
}

class AttemptCorrect extends AttemptOutcome {
  final String captureTeamId;
  final bool poleLocked;
  const AttemptCorrect({required this.captureTeamId, required this.poleLocked});
}

class AttemptIncorrect extends AttemptOutcome {
  final int attemptsRemaining;
  const AttemptIncorrect(this.attemptsRemaining);
}

class AttemptLockedOut extends AttemptOutcome {
  const AttemptLockedOut();
}

class AttemptAlreadyCaptured extends AttemptOutcome {
  const AttemptAlreadyCaptured();
}

class AttemptAlreadyOwner extends AttemptOutcome {
  const AttemptAlreadyOwner();
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
