class TestSession {
  final String id;
  final String? name;
  final DateTime? endedAt;
  final DateTime? insertedAt;

  const TestSession({
    required this.id,
    required this.name,
    required this.endedAt,
    required this.insertedAt,
  });

  bool get isActive => endedAt == null;

  factory TestSession.fromJson(Map<String, dynamic> json) => TestSession(
        id: json['id'] as String,
        name: json['name'] as String?,
        endedAt: json['ended_at'] == null
            ? null
            : DateTime.tryParse(json['ended_at'] as String),
        insertedAt: json['inserted_at'] == null
            ? null
            : DateTime.tryParse(json['inserted_at'] as String),
      );
}
