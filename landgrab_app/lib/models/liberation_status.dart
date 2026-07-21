/// The liberation rollout as the supervisor sees it: the configured window
/// (invitations trickle out across it) and how far it has got.
class LiberationStatus {
  final DateTime? startsAt;
  final DateTime? rolloutEndsAt;
  final int teamCount;
  final int invited;
  final int accepted;
  final int declined;

  LiberationStatus({
    this.startsAt,
    this.rolloutEndsAt,
    required this.teamCount,
    required this.invited,
    required this.accepted,
    required this.declined,
  });

  factory LiberationStatus.fromJson(Map<String, dynamic> json) =>
      LiberationStatus(
        startsAt: json['starts_at'] == null
            ? null
            : DateTime.tryParse('${json['starts_at']}'),
        rolloutEndsAt: json['rollout_ends_at'] == null
            ? null
            : DateTime.tryParse('${json['rollout_ends_at']}'),
        teamCount: (json['team_count'] as num?)?.toInt() ?? 0,
        invited: (json['invited'] as num?)?.toInt() ?? 0,
        accepted: (json['accepted'] as num?)?.toInt() ?? 0,
        declined: (json['declined'] as num?)?.toInt() ?? 0,
      );
}
