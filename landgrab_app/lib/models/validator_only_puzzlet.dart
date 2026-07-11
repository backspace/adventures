/// Lightweight read model for puzzlets flagged validator-only.
/// Returned by `GET /landgrab/validation/validator-only-puzzlets` for
/// display on the gameplay map — answers are DELIBERATELY not
/// included in the API response so a validator's own map can't
/// spoil them either.
class ValidatorOnlyPuzzlet {
  final String id;
  final String instructions;
  final int difficulty;
  final double latitude;
  final double longitude;
  final String? warning;
  final String status;

  const ValidatorOnlyPuzzlet({
    required this.id,
    required this.instructions,
    required this.difficulty,
    required this.latitude,
    required this.longitude,
    required this.warning,
    required this.status,
  });

  factory ValidatorOnlyPuzzlet.fromJson(Map<String, dynamic> json) =>
      ValidatorOnlyPuzzlet(
        id: json['id'] as String,
        instructions: json['instructions'] as String,
        difficulty: json['difficulty'] as int,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        warning: json['warning'] as String?,
        status: json['status'] as String? ?? 'draft',
      );
}
