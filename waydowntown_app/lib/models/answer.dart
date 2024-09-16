class Answer {
  final String id;
  final String? label;
  final int? order;

  const Answer({required this.id, required this.label, this.order});

  factory Answer.fromJson(Map<String, dynamic> json) {
    return Answer(
      id: json['id'],
      label: json['attributes']['label'],
      order: json['attributes']['order'],
    );
  }
}
