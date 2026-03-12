class Task {
  final String? id;
  final int userId;
  final String title;
  final String time;
  final String date; // stored as yyyy-MM-dd
  final bool isCompleted;
  final DateTime createdAt;

  Task({
    this.id,
    required this.userId,
    required this.title,
    required this.time,
    required this.date,
    this.isCompleted = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'Task_ID': id != null ? int.tryParse(id!) : null,
      'User_ID': userId,
      'Title': title,
      'Time': time,
      'Date': date,
      'Is_Completed': isCompleted ? 1 : 0,
      'Created_At': createdAt.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['Task_ID']?.toString(),
      userId: map['User_ID'] as int,
      title: map['Title'] as String,
      time: (map['Time'] as String?) ?? '',
      date: (map['Date'] as String?) ?? '',
      isCompleted: map['Is_Completed'] == 1,
      createdAt: DateTime.parse(map['Created_At'] as String),
    );
  }

  // Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'time': time,
      'date': date,
      'isCompleted': isCompleted,
      'createdAt': createdAt,
    };
  }

  factory Task.fromFirestore(String docId, Map<String, dynamic> data) {
    return Task(
      id: docId,
      userId: 0, // not needed for Firestore
      title: data['title'] ?? '',
      time: data['time'] ?? '',
      date: data['date'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      createdAt: (data['createdAt'] as dynamic).toDate(),
    );
  }

  Task copyWith({
    String? id,
    int? userId,
    String? title,
    String? time,
    String? date,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      time: time ?? this.time,
      date: date ?? this.date,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
