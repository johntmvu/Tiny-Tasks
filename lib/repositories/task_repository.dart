import '../database/sqlite_helper.dart';
import '../models/task.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 

class TaskRepository {
  final SQLiteHelper _dbHelper;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  TaskRepository({SQLiteHelper? dbHelper})
      : _dbHelper = dbHelper ?? SQLiteHelper.instance;

  // SQLite Methods
  Future<int> createTask(Task task) async {
    return await _dbHelper.insertTask(task);
  }

  Future<Task?> getTaskById(int id) async {
    return await _dbHelper.getTask(id);
  }

  Future<List<Task>> getTasksByUser(int userId) async {
    return await _dbHelper.getTasksByUser(userId);
  }

  Future<int> updateTask(Task task) async {
    return await _dbHelper.updateTask(task);
  }

  Future<int> deleteTask(int id) async {
    return await _dbHelper.deleteTask(id);
  }


// Firestore Methods
/// Create task in Firestore
  Future<void> createTaskFirestore(Task task, String firebaseUserId) async {
    await _firestore
        .collection('users')
        .doc(firebaseUserId)
        .collection('tasks')
        .add({
      'title': task.title,
      'time': task.time,
      'isCompleted': task.isCompleted,
      'createdAt': Timestamp.now(),
    });
  }

  /// Real-time task stream
  Stream<List<Task>> getTasksStream(String firebaseUserId) {
    return _firestore
        .collection('users')
        .doc(firebaseUserId)
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Task(
          id: doc.id, // Firestore string ID → int fallback
          title: doc['title'],
          time: doc['time'],
          isCompleted: doc['isCompleted'],
          userId: 0, // not needed for Firestore
        );
      }).toList();
    });
  }

  /// Update Firestore task
  Future<void> updateTaskFirestore(Task task, String firebaseUserId) async {
    await _firestore
        .collection('users')
        .doc(firebaseUserId)
        .collection('tasks')
        .doc(task.id)
        .update({
      'isCompleted': task.isCompleted,
      'title': task.title,
      'time': task.time,
    });
  }

  /// Delete Firestore task
  Future<void> deleteTaskFirestore(String taskId, String firebaseUserId) async {
    await _firestore
        .collection('users')
        .doc(firebaseUserId)
        .collection('tasks')
        .doc(taskId)
        .delete();
  }
}