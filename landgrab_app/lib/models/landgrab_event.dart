class LandgrabEvent {
  final String name;
  final DateTime? startTime;
  final bool started;

  const LandgrabEvent({
    required this.name,
    required this.startTime,
    required this.started,
  });

  factory LandgrabEvent.fromJson(Map<String, dynamic> json) => LandgrabEvent(
        name: json['name'] as String,
        startTime: json['start_time'] == null
            ? null
            : DateTime.parse(json['start_time'] as String),
        started: json['started'] as bool,
      );
}
