class TinyTask {
  final int? tinyTaskId;
  final int parentBigTaskId;
  final String title;
  final bool isCompleted;
  final DateTime? dueTime;
  final DateTime createdAt;

  TinyTask({
    this.tinyTaskId,
    required this.parentBigTaskId,
    required this.title,
    this.isCompleted = false,
    this.dueTime,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'TinyTask_ID': tinyTaskId,
      'Parent_BigTask_ID': parentBigTaskId,
      'Title': title,
      'Is_Completed': isCompleted ? 1 : 0,
      'Due_Time': dueTime?.toIso8601String(),
      'Created_At': createdAt.toIso8601String(),
    };
  }

  factory TinyTask.fromMap(Map<String, dynamic> map) {
    return TinyTask(
      tinyTaskId: map['TinyTask_ID'] as int?,
      parentBigTaskId: map['Parent_BigTask_ID'] as int,
      title: map['Title'] as String,
      isCompleted: map['Is_Completed'] == 1,
      dueTime: map['Due_Time'] != null
          ? DateTime.parse(map['Due_Time'] as String)
          : null,
      createdAt: DateTime.parse(map['Created_At'] as String),
    );
  }

  TinyTask copyWith({
    int? tinyTaskId,
    int? parentBigTaskId,
    String? title,
    bool? isCompleted,
    DateTime? dueTime,
    DateTime? createdAt,
  }) {
    return TinyTask(
      tinyTaskId: tinyTaskId ?? this.tinyTaskId,
      parentBigTaskId: parentBigTaskId ?? this.parentBigTaskId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      dueTime: dueTime ?? this.dueTime,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
