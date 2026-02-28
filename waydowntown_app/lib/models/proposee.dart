class Proposee {
  final String email;
  final bool invited;
  final bool registered;

  Proposee({
    required this.email,
    required this.invited,
    required this.registered,
  });

  factory Proposee.fromJson(Map<String, dynamic> json) {
    final attributes = json['attributes'];

    return Proposee(
      email: attributes['email'],
      invited: attributes['invited'] ?? false,
      registered: attributes['registered'] ?? false,
    );
  }
}
