class Task {
  final int? id;
  final int userId;
  final String title;
  final String time;
  final bool isCompleted;
  final DateTime createdAt;

  Task({
    this.id,
    required this.userId,
    required this.title,
    required this.time,
    this.isCompleted = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'Task_ID': id,
      'User_ID': userId,
      'Title': title,
      'Time': time,
      'Is_Completed': isCompleted ? 1 : 0,
      'Created_At': createdAt.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['Task_ID'] as int?,
      userId: map['User_ID'] as int,
      title: map['Title'] as String,
      time: map['Time'] as String,
      isCompleted: map['Is_Completed'] == 1,
      createdAt: DateTime.parse(map['Created_At'] as String),
    );
  }

  Task copyWith({
    int? id,
    int? userId,
    String? title,
    String? time,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      time: time ?? this.time,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
