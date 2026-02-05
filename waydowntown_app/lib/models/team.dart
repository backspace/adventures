import 'package:waydowntown/models/team_member.dart';

class Team {
  final String id;
  final String name;
  final int? riskAversion;
  final String? notes;
  final List<TeamMember> members;

  Team({
    required this.id,
    required this.name,
    this.riskAversion,
    this.notes,
    this.members = const [],
  });

  factory Team.fromJson(Map<String, dynamic> json, List<dynamic> included) {
    final attributes = json['attributes'];
    final relationships = json['relationships'];

    List<TeamMember> members = [];
    if (relationships != null && relationships['members'] != null) {
      final membersData = relationships['members']['data'] as List<dynamic>?;
      if (membersData != null) {
        for (var memberRef in membersData) {
          final memberJson = included.firstWhere(
            (item) =>
                item['type'] == 'team-members' &&
                item['id'] == memberRef['id'],
            orElse: () => <String, Object>{},
          );
          if (memberJson.isNotEmpty) {
            members.add(TeamMember.fromJson(memberJson));
          }
        }
      }
    }

    return Team(
      id: json['id'],
      name: attributes['name'],
      riskAversion: attributes['risk_aversion'],
      notes: attributes['notes'],
      members: members,
    );
  }
}
