class Task {
  final int? taskId;
  final int userId;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? priority;
  final bool isCompleted;
  final bool isRecurring;
  final String? recurrencePattern;
  final DateTime? reminderTime;
  final DateTime createdAt;

  Task({
    this.taskId,
    required this.userId,
    required this.title,
    this.description,
    this.dueDate,
    this.startTime,
    this.endTime,
    this.priority,
    this.isCompleted = false,
    this.isRecurring = false,
    this.recurrencePattern,
    this.reminderTime,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'Task_ID': taskId,
      'User_ID': userId,
      'Title': title,
      'Description': description,
      'Due_Date': dueDate?.toIso8601String(),
      'Start_Time': startTime?.toIso8601String(),
      'End_Time': endTime?.toIso8601String(),
      'Priority': priority,
      'Is_Completed': isCompleted ? 1 : 0,
      'Is_Recurring': isRecurring ? 1 : 0,
      'Recurrence_Pattern': recurrencePattern,
      'Reminder_Time': reminderTime?.toIso8601String(),
      'Created_At': createdAt.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      taskId: map['Task_ID'] as int?,
      userId: map['User_ID'] as int,
      title: map['Title'] as String,
      description: map['Description'] as String?,
      dueDate: map['Due_Date'] != null
          ? DateTime.parse(map['Due_Date'] as String)
          : null,
      startTime: map['Start_Time'] != null
          ? DateTime.parse(map['Start_Time'] as String)
          : null,
      endTime: map['End_Time'] != null
          ? DateTime.parse(map['End_Time'] as String)
          : null,
      priority: map['Priority'] as String?,
      isCompleted: map['Is_Completed'] == 1,
      isRecurring: map['Is_Recurring'] == 1,
      recurrencePattern: map['Recurrence_Pattern'] as String?,
      reminderTime: map['Reminder_Time'] != null
          ? DateTime.parse(map['Reminder_Time'] as String)
          : null,
      createdAt: DateTime.parse(map['Created_At'] as String),
    );
  }

  Task copyWith({
    int? taskId,
    int? userId,
    String? title,
    String? description,
    DateTime? dueDate,
    DateTime? startTime,
    DateTime? endTime,
    String? priority,
    bool? isCompleted,
    bool? isRecurring,
    String? recurrencePattern,
    DateTime? reminderTime,
    DateTime? createdAt,
  }) {
    return Task(
      taskId: taskId ?? this.taskId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrencePattern: recurrencePattern ?? this.recurrencePattern,
      reminderTime: reminderTime ?? this.reminderTime,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
