class TeamMember {
  final String id;
  final String email;
  final String? name;
  final int? riskAversion;
  final String? proposedTeamName;

  TeamMember({
    required this.id,
    required this.email,
    this.name,
    this.riskAversion,
    this.proposedTeamName,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'];

    return TeamMember(
      id: json['id'],
      email: attributes['email'],
      name: attributes['name'],
      riskAversion: attributes['risk_aversion'],
      proposedTeamName: attributes['proposed_team_name'],
    );
  }
}
