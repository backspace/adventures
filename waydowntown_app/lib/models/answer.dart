class Answer {
  final String id;
  final String? label;
  final int? order;

  final String? hint;
  final bool hasHint;

  const Answer({
    required this.id,
    required this.label,
    this.order,
    this.hint,
    this.hasHint = false,
  });

  factory Answer.fromJson(Map<String, dynamic> json) {
    return Answer(
      id: json['id'],
      label: json['attributes']['label'],
      order: json['attributes']['order'],
      hint: json['attributes']['hint'],
      hasHint: json['attributes']['has_hint'],
    );
  }
}
