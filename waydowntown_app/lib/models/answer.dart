class Answer {
  final String id;
  final String label;

  const Answer({required this.id, required this.label});

  factory Answer.fromJson(Map<String, dynamic> json) {
    return Answer(
      id: json['id'],
      label: json['attributes']['label'],
    );
  }
}
