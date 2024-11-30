class Participation {
  final String id;
  final String userId;
  final String userName;
  final String runId;
  final DateTime? readyAt;

  Participation({
    required this.id,
    required this.userId,
    required this.userName,
    required this.runId,
    this.readyAt,
  });

  factory Participation.fromJson(
      Map<String, dynamic> json, List<dynamic> included) {
    final userJson = included.firstWhere(
      (item) =>
          item['type'] == 'users' &&
          item['id'] == json['relationships']['user']['data']['id'],
      orElse: () => <String, Object>{},
    );

    return Participation(
      id: json['id'],
      userId: json['relationships']['user']['data']['id'],
      userName: userJson['attributes']['name'],
      runId: json['relationships']['run']['data']['id'],
      readyAt: json['attributes']['ready_at'] != null
          ? DateTime.parse(json['attributes']['ready_at'])
          : null,
    );
  }
}
