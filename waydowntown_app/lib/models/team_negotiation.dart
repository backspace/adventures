import 'package:waydowntown/models/proposee.dart';
import 'package:waydowntown/models/team.dart';
import 'package:waydowntown/models/team_member.dart';

class TeamNegotiation {
  final String id;
  final String? teamEmails;
  final String? proposedTeamName;
  final int? riskAversion;
  final bool isEmpty;
  final bool onlyMutuals;
  final Team? team;
  final List<TeamMember> mutuals;
  final List<TeamMember> proposers;
  final List<Proposee> proposees;
  final List<String> invalids;

  TeamNegotiation({
    required this.id,
    this.teamEmails,
    this.proposedTeamName,
    this.riskAversion,
    required this.isEmpty,
    required this.onlyMutuals,
    this.team,
    this.mutuals = const [],
    this.proposers = const [],
    this.proposees = const [],
    this.invalids = const [],
  });

  factory TeamNegotiation.fromJson(Map<String, dynamic> apiResponse) {
    final data = apiResponse['data'];
    final attributes = data['attributes'];
    final relationships = data['relationships'];
    final List<dynamic> included = apiResponse['included'] ?? [];

    // Parse team if present
    Team? team;
    if (relationships != null && relationships['team'] != null) {
      final teamData = relationships['team']['data'];
      if (teamData != null) {
        final teamJson = included.firstWhere(
          (item) => item['type'] == 'teams' && item['id'] == teamData['id'],
          orElse: () => <String, Object>{},
        );
        if (teamJson.isNotEmpty) {
          team = Team.fromJson(teamJson, included);
        }
      }
    }

    // Parse mutuals
    List<TeamMember> mutuals = _parseMembers(relationships, 'mutuals', included);

    // Parse proposers
    List<TeamMember> proposers = _parseMembers(relationships, 'proposers', included);

    // Parse proposees
    List<Proposee> proposees = [];
    if (relationships != null && relationships['proposees'] != null) {
      final proposeesData =
          relationships['proposees']['data'] as List<dynamic>?;
      if (proposeesData != null) {
        for (var proposeeRef in proposeesData) {
          final proposeeJson = included.firstWhere(
            (item) =>
                item['type'] == 'proposees' && item['id'] == proposeeRef['id'],
            orElse: () => <String, Object>{},
          );
          if (proposeeJson.isNotEmpty) {
            proposees.add(Proposee.fromJson(proposeeJson));
          }
        }
      }
    }

    // Parse invalids
    List<String> invalids = [];
    if (relationships != null && relationships['invalids'] != null) {
      final invalidsData = relationships['invalids']['data'] as List<dynamic>?;
      if (invalidsData != null) {
        for (var invalidRef in invalidsData) {
          final invalidJson = included.firstWhere(
            (item) =>
                item['type'] == 'invalids' && item['id'] == invalidRef['id'],
            orElse: () => <String, Object>{},
          );
          if (invalidJson.isNotEmpty) {
            invalids.add(invalidJson['attributes']['value']);
          }
        }
      }
    }

    return TeamNegotiation(
      id: data['id'],
      teamEmails: attributes['team_emails'],
      proposedTeamName: attributes['proposed_team_name'],
      riskAversion: attributes['risk_aversion'],
      isEmpty: attributes['empty'] ?? false,
      onlyMutuals: attributes['only_mutuals'] ?? false,
      team: team,
      mutuals: mutuals,
      proposers: proposers,
      proposees: proposees,
      invalids: invalids,
    );
  }

  static List<TeamMember> _parseMembers(
    Map<String, dynamic>? relationships,
    String key,
    List<dynamic> included,
  ) {
    List<TeamMember> members = [];
    if (relationships != null && relationships[key] != null) {
      final membersData = relationships[key]['data'] as List<dynamic>?;
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
    return members;
  }
}
