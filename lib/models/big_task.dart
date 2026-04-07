import 'package:cloud_firestore/cloud_firestore.dart';

class BigTask {
  final int? id;
  final int? userId;
  final String? firebaseUserId;
  final String title;
  final String? description;
  final String priority;
  final String dueDate;
  final String color;
  final DateTime createdAt;

  BigTask({
    this.id,
    this.userId,
    this.firebaseUserId,
    required this.title,
    this.description,
    this.priority = 'medium',
    required this.dueDate,
    this.color = 'blue',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  BigTask copyWith({
    int? id,
    int? userId,
    String? firebaseUserId,
    String? title,
    String? description,
    String? priority,
    String? dueDate,
    String? color,
    DateTime? createdAt,
  }) {
    return BigTask(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      firebaseUserId: firebaseUserId ?? this.firebaseUserId,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'BigTask_ID': id,
      'User_ID': userId,
      'FirebaseUserId': firebaseUserId,
      'Title': title,
      'Description': description,
      'Priority': priority,
      'Due_Date': dueDate,
      'Color': color,
      'Created_At': createdAt.toIso8601String(),
    };
  }

  factory BigTask.fromMap(Map<String, dynamic> map) {
    return BigTask(
      id: map['BigTask_ID'] as int?,
      userId: map['User_ID'] as int?,
      firebaseUserId: map['FirebaseUserId'] as String?,
      title: map['Title'] ?? '',
      description: map['Description'] as String?,
      priority: map['Priority'] ?? 'medium',
      dueDate: map['Due_Date'] ?? '',
      color: map['Color'] ?? 'blue',
      createdAt: map['Created_At'] != null
          ? DateTime.tryParse(map['Created_At'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'firebaseUserId': firebaseUserId,
      'title': title,
      'description': description,
      'priority': priority,
      'dueDate': dueDate,
      'color': color,
      'createdAt': createdAt,
    };
  }

  factory BigTask.fromFirestore(String id, Map<String, dynamic> map) {
    return BigTask(
      id: int.tryParse(id),
      userId: map['userId'] as int?,
      firebaseUserId: map['firebaseUserId']?.toString(),
      title: map['title'] ?? '',
      description: map['description'] as String?,
      priority: map['priority'] ?? 'medium',
      dueDate: map['dueDate'] ?? '',
      color: map['color'] ?? 'blue',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
