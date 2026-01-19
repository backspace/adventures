class Submission {
  final String id;
  final String submission;
  final bool correct;
  final DateTime insertedAt;
  final String? creatorId;

  Submission({
    required this.id,
    required this.submission,
    required this.correct,
    required this.insertedAt,
    this.creatorId,
  });

  factory Submission.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String) {
      throw const FormatException('Submission must have an id');
    }

    final attributes = json['attributes'] as Map<String, dynamic>?;
    final relationships = json['relationships'] as Map<String, dynamic>?;
    final insertedAtRaw = attributes?['inserted_at'];
    final insertedAt = insertedAtRaw is String
        ? DateTime.parse(insertedAtRaw)
        : DateTime.fromMillisecondsSinceEpoch(0);

    return Submission(
      id: id,
      submission: attributes?['submission'] as String? ?? '',
      correct: attributes?['correct'] == true,
      insertedAt: insertedAt,
      creatorId: relationships?['creator']?['data']?['id'] as String?,
    );
  }
}
