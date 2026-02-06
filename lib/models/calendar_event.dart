class CalendarEvent {
  final int? eventId;
  final int userId;
  final String? googleEventId;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? status;
  final DateTime? lastSynced;

  CalendarEvent({
    this.eventId,
    required this.userId,
    this.googleEventId,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.status,
    this.lastSynced,
  });

  Map<String, dynamic> toMap() {
    return {
      'Event_ID': eventId,
      'User_ID': userId,
      'Google_Event_ID': googleEventId,
      'Title': title,
      'Start_Time': startTime.toIso8601String(),
      'End_Time': endTime.toIso8601String(),
      'Status': status,
      'Last_Synced': lastSynced?.toIso8601String(),
    };
  }

  factory CalendarEvent.fromMap(Map<String, dynamic> map) {
    return CalendarEvent(
      eventId: map['Event_ID'] as int?,
      userId: map['User_ID'] as int,
      googleEventId: map['Google_Event_ID'] as String?,
      title: map['Title'] as String,
      startTime: DateTime.parse(map['Start_Time'] as String),
      endTime: DateTime.parse(map['End_Time'] as String),
      status: map['Status'] as String?,
      lastSynced: map['Last_Synced'] != null
          ? DateTime.parse(map['Last_Synced'] as String)
          : null,
    );
  }

  CalendarEvent copyWith({
    int? eventId,
    int? userId,
    String? googleEventId,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    DateTime? lastSynced,
  }) {
    return CalendarEvent(
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      googleEventId: googleEventId ?? this.googleEventId,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      lastSynced: lastSynced ?? this.lastSynced,
    );
  }
}
