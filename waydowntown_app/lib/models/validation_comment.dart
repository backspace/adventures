class ValidationComment {
  final String id;
  final String? answerId;
  final String? field;
  final String? comment;
  final String? suggestedValue;

  const ValidationComment({
    required this.id,
    this.answerId,
    this.field,
    this.comment,
    this.suggestedValue,
  });

  factory ValidationComment.fromJson(
      Map<String, dynamic> json, List<dynamic> included) {
    final attributes = json['attributes'] as Map<String, dynamic>?;
    final relationships = json['relationships'] as Map<String, dynamic>?;

    String? answerId;
    if (relationships != null &&
        relationships['answer'] != null &&
        relationships['answer']['data'] != null) {
      answerId = relationships['answer']['data']['id'];
    }

    return ValidationComment(
      id: json['id'],
      answerId: answerId,
      field: attributes?['field'],
      comment: attributes?['comment'],
      suggestedValue: attributes?['suggested_value'],
    );
  }
}
