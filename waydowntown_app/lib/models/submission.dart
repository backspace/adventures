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
    print('submission json');
    print(json);
    return Submission(
      id: json['id'],
      submission: json['attributes']['submission'],
      correct: json['attributes']['correct'],
      insertedAt: DateTime.parse(json['attributes']['inserted_at']),
      creatorId: json['relationships']['creator']['data']['id'],
    );
  }
}
