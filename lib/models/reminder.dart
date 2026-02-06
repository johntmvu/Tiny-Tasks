class Reminder {
  final int? reminderId;
  final int taskId;
  final DateTime reminderTime;
  final bool isActive;

  Reminder({
    this.reminderId,
    required this.taskId,
    required this.reminderTime,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'Reminder_ID': reminderId,
      'Task_ID': taskId,
      'Reminder_Time': reminderTime.toIso8601String(),
      'Is_Active': isActive ? 1 : 0,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      reminderId: map['Reminder_ID'] as int?,
      taskId: map['Task_ID'] as int,
      reminderTime: DateTime.parse(map['Reminder_Time'] as String),
      isActive: map['Is_Active'] == 1,
    );
  }

  Reminder copyWith({
    int? reminderId,
    int? taskId,
    DateTime? reminderTime,
    bool? isActive,
  }) {
    return Reminder(
      reminderId: reminderId ?? this.reminderId,
      taskId: taskId ?? this.taskId,
      reminderTime: reminderTime ?? this.reminderTime,
      isActive: isActive ?? this.isActive,
    );
  }
}
