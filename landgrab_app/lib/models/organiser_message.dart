/// A storyline message from the organisers (Sabuk / Sabuk's
/// assistant) to all teams. Drafts have a null [sentAt]; sending is
/// one-shot and fans out per-team notifications server-side.
class OrganiserMessage {
  final String id;
  final String body;
  final String senderName;
  final DateTime? sentAt;
  final DateTime? insertedAt;

  OrganiserMessage({
    required this.id,
    required this.body,
    required this.senderName,
    this.sentAt,
    this.insertedAt,
  });

  bool get sent => sentAt != null;

  factory OrganiserMessage.fromJson(Map<String, dynamic> json) =>
      OrganiserMessage(
        id: json['id'] as String,
        body: json['body'] as String,
        senderName: json['sender_name'] as String,
        sentAt: _parseUtc(json['sent_at']),
        insertedAt: _parseUtc(json['inserted_at']),
      );

  static DateTime? _parseUtc(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    final withZone =
        value.endsWith('Z') || value.contains('+') ? value : '${value}Z';
    return DateTime.tryParse(withZone);
  }
}
