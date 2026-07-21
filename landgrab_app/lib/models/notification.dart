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

  /// Interactive notifications only (the liberation invite): the team's
  /// recorded answer ("accepted"/"declined"), null until someone answers.
  /// The first answer binds the whole team.
  final String? response;
  final DateTime? respondedAt;

  LandgrabNotification({
    required this.id,
    required this.type,
    required this.recipientTeamId,
    required this.senderTeamId,
    required this.body,
    required this.metadata,
    this.insertedAt,
    this.readAt,
    this.response,
    this.respondedAt,
  });

  factory LandgrabNotification.fromJson(Map<String, dynamic> json) =>
      LandgrabNotification(
        id: json['id'] as String,
        type: json['type'] as String,
        recipientTeamId: json['recipient_team_id'] as String,
        senderTeamId: json['sender_team_id'] as String?,
        body: json['body'] as String,
        metadata:
            (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
        insertedAt: _parseUtc(json['inserted_at']),
        readAt: _parseUtc(json['read_at']),
        response: json['response'] as String?,
        respondedAt: _parseUtc(json['responded_at']),
      );

  bool get unread => readAt == null;

  /// Copy with a new read state — `read: true` stamps [readAt] now,
  /// `false` clears it. Used for optimistic swipe-to-toggle.
  LandgrabNotification withRead(bool read) => LandgrabNotification(
        id: id,
        type: type,
        recipientTeamId: recipientTeamId,
        senderTeamId: senderTeamId,
        body: body,
        metadata: metadata,
        insertedAt: insertedAt,
        readAt: read ? (readAt ?? DateTime.now().toUtc()) : null,
        response: response,
        respondedAt: respondedAt,
      );

  /// Copy with the team's answer recorded — after a successful respond
  /// call (or a 409 telling us a teammate beat us to it).
  LandgrabNotification withResponse(String newResponse) =>
      LandgrabNotification(
        id: id,
        type: type,
        recipientTeamId: recipientTeamId,
        senderTeamId: senderTeamId,
        body: body,
        metadata: metadata,
        insertedAt: insertedAt,
        readAt: readAt,
        response: newResponse,
        respondedAt: respondedAt ?? DateTime.now().toUtc(),
      );

  /// Server datetimes are UTC but serialize without a zone suffix
  /// (Elixir NaiveDateTime); treat suffixless values as UTC.
  static DateTime? _parseUtc(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    final withZone =
        value.endsWith('Z') || value.contains('+') ? value : '${value}Z';
    return DateTime.tryParse(withZone);
  }
}
