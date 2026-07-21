/// Relief-valve state + readiness dashboard for the supervisor: is the map
/// running dry (little left to capture), and who owns what.
class ReliefStatus {
  final bool active;
  final int totalPoles;

  /// Stakes still inside the (shrinking) endgame zone.
  final int inPlay;

  /// Stakes with a playable puzzlet still uncaptured.
  final int notFullyCaptured;

  /// In-zone AND not fully captured — the real "anything left to do" number.
  final int capturableInPlay;

  final List<ReliefLeaderboardEntry> leaderboard;

  ReliefStatus({
    required this.active,
    required this.totalPoles,
    required this.inPlay,
    required this.notFullyCaptured,
    required this.capturableInPlay,
    required this.leaderboard,
  });

  factory ReliefStatus.fromJson(Map<String, dynamic> json) => ReliefStatus(
        active: json['active'] == true,
        totalPoles: (json['total_poles'] as num?)?.toInt() ?? 0,
        inPlay: (json['in_play'] as num?)?.toInt() ?? 0,
        notFullyCaptured: (json['not_fully_captured'] as num?)?.toInt() ?? 0,
        capturableInPlay: (json['capturable_in_play'] as num?)?.toInt() ?? 0,
        leaderboard: (json['leaderboard'] as List?)
                ?.map((e) =>
                    ReliefLeaderboardEntry.fromJson(e as Map<String, dynamic>))
                .toList(growable: false) ??
            const [],
      );
}

class ReliefLeaderboardEntry {
  final String? teamId;
  final String? name;
  final int owned;

  ReliefLeaderboardEntry({this.teamId, this.name, required this.owned});

  factory ReliefLeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      ReliefLeaderboardEntry(
        teamId: json['team_id'] as String?,
        name: json['name'] as String?,
        owned: (json['owned'] as num?)?.toInt() ?? 0,
      );
}
