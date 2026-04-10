

class Task {
  final int? id;
  final int? userId;
  final String? firebaseUserId;
  final String title;
  final String? description;
  final String date;
  final String time;
  final bool isCompleted;
  final DateTime createdAt;
  final String period;
  final int? bigTaskId;
  final bool isRescheduled;
  final bool reminderEnabled;
  final int? notificationId;

  Task({
    this.id,
    this.userId,
    this.firebaseUserId,
    required this.title,
    this.description,
    required this.date,
    this.time = '',
    this.isCompleted = false,
    DateTime? createdAt,
    this.period = 'full',
    this.bigTaskId,
    this.isRescheduled = false,
    this.reminderEnabled = false,
    this.notificationId,
  }) : createdAt = createdAt ?? DateTime.now();

  Task copyWith({
    int? id,
    int? userId,
    String? firebaseUserId,
    String? title,
    String? description,
    String? date,
    String? time,
    bool? isCompleted,
    DateTime? createdAt,
    String? period,
    int? bigTaskId,
    bool? isRescheduled,
    bool? reminderEnabled,
    int? notificationId,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      firebaseUserId: firebaseUserId ?? this.firebaseUserId,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      time: time ?? this.time,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      period: period ?? this.period,
      bigTaskId: bigTaskId ?? this.bigTaskId,
      isRescheduled: isRescheduled ?? this.isRescheduled,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      notificationId: notificationId ?? this.notificationId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'Task_ID': id,
      'User_ID': userId,
      'Title': title,
      'Time': time,
      'Date': date,
      'Is_Completed': isCompleted ? 1 : 0,
      'Created_At': createdAt.toIso8601String(),
      'Description': description,
      'FirebaseUserId': firebaseUserId,
      'Period': period,
      'BigTask_ID': bigTaskId,
      'Is_Rescheduled': isRescheduled ? 1 : 0,
      'Reminder_Enabled': reminderEnabled ? 1 : 0,
      'Notification_ID': notificationId,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['Task_ID'],
      userId: map['User_ID'],
      title: map['Title'] ?? '',
      time: map['Time'] ?? '',
      date: map['Date'] ?? '',
      isCompleted:
          (map['Is_Completed'] ?? 0) == 1 || map['Is_Completed'] == true,
      createdAt: map['Created_At'] != null
          ? DateTime.tryParse(map['Created_At']) ?? DateTime.now()
          : DateTime.now(),
      description: map['Description'],
      firebaseUserId: map['FirebaseUserId'],
      period: map['Period'] ?? 'full',
      bigTaskId: map['BigTask_ID'] as int?,
      isRescheduled: (map['Is_Rescheduled'] ?? 0) == 1,
      reminderEnabled: (map['Reminder_Enabled'] ?? 0) == 1,
      notificationId: map['Notification_ID'] as int?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'firebaseUserId': firebaseUserId,
      'title': title,
      'description': description,
      'date': date,
      'time': time,
      'isCompleted': isCompleted,
      'createdAt': createdAt,
      'period': period,
      'bigTaskId': bigTaskId,
      'isRescheduled': isRescheduled,
      'reminderEnabled': reminderEnabled,
      'notificationId': notificationId,
    };
  }

  factory Task.fromFirestore(String id, Map<String, dynamic> map) {
    return Task(
      id: int.tryParse(id),
      userId: map['userId'],
      firebaseUserId: map['firebaseUserId']?.toString(),
      title: map['title'] ?? '',
      description: map['description'],
      date: map['date'] ?? '',
      time: map['time'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      createdAt: map['createdAt'] != null
          ? map['createdAt'].toDate()
          : DateTime.now(),
      period: map['period'] ?? 'full',
      bigTaskId: map['bigTaskId'] as int?,
      isRescheduled: map['isRescheduled'] ?? false,
      reminderEnabled: map['reminderEnabled'] ?? false,
      notificationId: map['notificationId'] as int?,
    );
  }
}