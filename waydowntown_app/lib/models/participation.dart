class Participation {
  final String id;
  final String userId;
  final String runId;
  final DateTime? readyAt;

  Participation({
    required this.id,
    required this.userId,
    required this.runId,
    this.readyAt,
  });

  factory Participation.fromJson(Map<String, dynamic> json) {
    return Participation(
      id: json['id'],
      userId: json['relationships']['user']['data']['id'],
      runId: json['relationships']['run']['data']['id'],
      readyAt: json['attributes']['ready_at'] != null
          ? DateTime.parse(json['attributes']['ready_at'])
          : null,
    );
  }
}
