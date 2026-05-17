class PolesEvent {
  final String name;
  final DateTime? startTime;
  final bool started;

  const PolesEvent({
    required this.name,
    required this.startTime,
    required this.started,
  });

  factory PolesEvent.fromJson(Map<String, dynamic> json) => PolesEvent(
        name: json['name'] as String,
        startTime: json['start_time'] == null
            ? null
            : DateTime.parse(json['start_time'] as String),
        started: json['started'] as bool,
      );
}
