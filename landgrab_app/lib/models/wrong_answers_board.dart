/// A single wrong guess a team made at a puzzlet, for the supervisor's
/// wrong-answers dashboard.
class WrongAttempt {
  final String answerGiven;
  final String? teamId;
  final String? teamName;
  final DateTime? at;

  WrongAttempt({
    required this.answerGiven,
    this.teamId,
    this.teamName,
    this.at,
  });

  String get teamDisplay {
    final n = teamName?.trim();
    return (n != null && n.isNotEmpty) ? n : 'Unknown team';
  }

  factory WrongAttempt.fromJson(Map<String, dynamic> json) => WrongAttempt(
        answerGiven: '${json['answer_given'] ?? ''}',
        teamId: json['team_id'] as String?,
        teamName: json['team_name'] as String?,
        at: json['at'] == null ? null : DateTime.tryParse('${json['at']}'),
      );
}

/// A puzzlet that has drawn wrong guesses: its correct answer for reference,
/// plus every wrong attempt against it.
class WrongAnswerPuzzlet {
  final String puzzletId;
  final int? difficulty;
  final String? instructions;
  final String? answer;
  final String? poleLabel;
  final String? poleBarcode;
  final int wrongCount;
  final List<WrongAttempt> attempts;

  WrongAnswerPuzzlet({
    required this.puzzletId,
    this.difficulty,
    this.instructions,
    this.answer,
    this.poleLabel,
    this.poleBarcode,
    this.wrongCount = 0,
    this.attempts = const [],
  });

  /// The stake's label, else its barcode.
  String get poleDisplay {
    final l = poleLabel?.trim();
    if (l != null && l.isNotEmpty) return l;
    final b = poleBarcode?.trim();
    if (b != null && b.isNotEmpty) return b;
    return 'unattached';
  }

  factory WrongAnswerPuzzlet.fromJson(Map<String, dynamic> json) {
    final pole = (json['pole'] as Map?)?.cast<String, dynamic>();
    return WrongAnswerPuzzlet(
      puzzletId: '${json['puzzlet_id']}',
      difficulty: (json['difficulty'] as num?)?.toInt(),
      instructions: json['instructions'] as String?,
      answer: json['answer'] as String?,
      poleLabel: pole?['label'] as String?,
      poleBarcode: pole?['barcode'] as String?,
      wrongCount: (json['wrong_count'] as num?)?.toInt() ?? 0,
      attempts: ((json['attempts'] as List?) ?? const [])
          .map((a) => WrongAttempt.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// The supervisor wrong-answers dashboard: puzzlets that have been missed,
/// most-recently-failed first (server-ordered).
class WrongAnswersBoard {
  final List<WrongAnswerPuzzlet> puzzlets;

  WrongAnswersBoard({this.puzzlets = const []});

  factory WrongAnswersBoard.fromJson(Map<String, dynamic> json) =>
      WrongAnswersBoard(
        puzzlets: ((json['puzzlets'] as List?) ?? const [])
            .map((p) => WrongAnswerPuzzlet.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}
