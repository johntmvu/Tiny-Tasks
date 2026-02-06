class BigTask {
  final int? bigTaskId;
  final int userId;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final String? priority;
  final DateTime createdAt;

  BigTask({
    this.bigTaskId,
    required this.userId,
    required this.title,
    this.description,
    this.dueDate,
    this.priority,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'BigTask_ID': bigTaskId,
      'User_ID': userId,
      'Title': title,
      'Description': description,
      'Due_Date': dueDate?.toIso8601String(),
      'Priority': priority,
      'Created_At': createdAt.toIso8601String(),
    };
  }

  factory BigTask.fromMap(Map<String, dynamic> map) {
    return BigTask(
      bigTaskId: map['BigTask_ID'] as int?,
      userId: map['User_ID'] as int,
      title: map['Title'] as String,
      description: map['Description'] as String?,
      dueDate: map['Due_Date'] != null
          ? DateTime.parse(map['Due_Date'] as String)
          : null,
      priority: map['Priority'] as String?,
      createdAt: DateTime.parse(map['Created_At'] as String),
    );
  }

  BigTask copyWith({
    int? bigTaskId,
    int? userId,
    String? title,
    String? description,
    DateTime? dueDate,
    String? priority,
    DateTime? createdAt,
  }) {
    return BigTask(
      bigTaskId: bigTaskId ?? this.bigTaskId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
