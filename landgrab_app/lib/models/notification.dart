/// A message-to-a-team persisted server-side. Arrives two ways with
/// the same shape: live over the socket ("notification_created" on
/// the map channel) and in bulk from GET /landgrab/notifications for
/// the history screen. Today's `type`s are "attack" and "pole_lost";
/// chat will follow with a `type` of its own.
class LandgrabNotification {
  final String id;
  final String type;
  final String recipientTeamId;
  final String? senderTeamId;
  final String body;
  final Map<String, dynamic> metadata;
  final DateTime? insertedAt;
  final DateTime? readAt;

  LandgrabNotification({
    required this.id,
    required this.type,
    required this.recipientTeamId,
    required this.senderTeamId,
    required this.body,
    required this.metadata,
    this.insertedAt,
    this.readAt,
  });

  factory LandgrabNotification.fromJson(Map<String, dynamic> json) =>
      LandgrabNotification(
        id: json['id'] as String,
        type: json['type'] as String,
        recipientTeamId: json['recipient_team_id'] as String,
        senderTeamId: json['sender_team_id'] as String?,
        body: json['body'] as String,
        metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
        insertedAt: _parseUtc(json['inserted_at']),
        readAt: _parseUtc(json['read_at']),
      );

  bool get unread => readAt == null;

  /// Server datetimes are UTC but serialize without a zone suffix
  /// (Elixir NaiveDateTime); treat suffixless values as UTC.
  static DateTime? _parseUtc(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    final withZone =
        value.endsWith('Z') || value.contains('+') ? value : '${value}Z';
    return DateTime.tryParse(withZone);
  }
}
