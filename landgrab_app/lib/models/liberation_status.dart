/// A member of a team, for the supervisor's team-roster popover.
class LiberationMember {
  final String id;
  final String? name;
  final String email;

  LiberationMember({required this.id, this.name, required this.email});

  /// Name if set, otherwise the local part of the email.
  String get display => (name != null && name!.trim().isNotEmpty)
      ? name!.trim()
      : email.split('@').first;

  factory LiberationMember.fromJson(Map<String, dynamic> json) =>
      LiberationMember(
        id: '${json['id']}',
        name: json['name'] as String?,
        email: '${json['email']}',
      );
}

/// A team's place in the liberation rollout, for the supervisor breakdown.
/// [status] is one of accepted / declined / invited (undecided) / uninvited.
class LiberationTeam {
  final String id;
  final String name;
  final String status;
  final List<LiberationMember> members;

  LiberationTeam({
    required this.id,
    required this.name,
    required this.status,
    required this.members,
  });

  factory LiberationTeam.fromJson(Map<String, dynamic> json) => LiberationTeam(
        id: '${json['id']}',
        name: '${json['name']}',
        status: '${json['status']}',
        members: ((json['members'] as List?) ?? const [])
            .map((m) => LiberationMember.fromJson(m as Map<String, dynamic>))
            .toList(),
      );
}

/// The liberation rollout as the supervisor sees it: the configured window
/// (invitations trickle out across it), how far it has got, and the per-team
/// breakdown ([teams]) behind the counts.
class LiberationStatus {
  final DateTime? startsAt;
  final DateTime? rolloutEndsAt;
  final int teamCount;
  final int invited;
  final int accepted;
  final int declined;
  final List<LiberationTeam> teams;
  // Takver's scheduled one-off "accounting" message (after the invite rollout,
  // before the endgame). [accountingSentAt] is non-null once it has gone out,
  // so the UI can lock editing.
  final DateTime? accountingAt;
  final String? accountingBody;
  final DateTime? accountingSentAt;

  LiberationStatus({
    this.startsAt,
    this.rolloutEndsAt,
    required this.teamCount,
    required this.invited,
    required this.accepted,
    required this.declined,
    this.teams = const [],
    this.accountingAt,
    this.accountingBody,
    this.accountingSentAt,
  });

  bool get accountingSent => accountingSentAt != null;

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
        teams: ((json['teams'] as List?) ?? const [])
            .map((t) => LiberationTeam.fromJson(t as Map<String, dynamic>))
            .toList(),
        accountingAt: json['accounting_at'] == null
            ? null
            : DateTime.tryParse('${json['accounting_at']}'),
        accountingBody: json['accounting_body'] as String?,
        accountingSentAt: json['accounting_sent_at'] == null
            ? null
            : DateTime.tryParse('${json['accounting_sent_at']}'),
      );

  /// Teams with the given rollout [status], in name order (already sorted by
  /// the server).
  List<LiberationTeam> teamsWithStatus(String status) =>
      teams.where((t) => t.status == status).toList();
}
