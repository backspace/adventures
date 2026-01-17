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
    final attributes = json['attributes'] as Map<String, dynamic>?;
    return Answer(
      id: json['id'],
      label: attributes?['label'],
      order: attributes?['order'],
      hint: attributes?['hint'],
      hasHint: attributes?['has_hint'] == true,
    );
  }
}
