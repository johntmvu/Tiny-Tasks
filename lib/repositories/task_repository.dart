import '../database/sqlite_helper.dart';
import '../models/task.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TaskRepository {
  final SQLiteHelper _dbHelper;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  TaskRepository({SQLiteHelper? dbHelper})
    : _dbHelper = dbHelper ?? SQLiteHelper.instance;

  CollectionReference _tasksCollection(String firebaseUserId) =>
      _firestore.collection('users').doc(firebaseUserId).collection('tasks');

  // ==================== Combined CRUD (SQLite + Firestore) ====================

  /// Create task locally, then sync to Firestore.
  /// Returns the SQLite row ID.
  Future<int> createTask(Task task, {String? firebaseUserId}) async {
    final sqliteId = await _dbHelper.insertTask(task);

    if (firebaseUserId != null) {
      final taskWithId = task.copyWith(id: sqliteId.toString());
      await _tasksCollection(
        firebaseUserId,
      ).doc(sqliteId.toString()).set(taskWithId.toFirestore());
    }
    return sqliteId;
  }

  Future<Task?> getTaskById(int id) async {
    return await _dbHelper.getTask(id);
  }

  Future<List<Task>> getTasksByUser(int userId) async {
    return await _dbHelper.getTasksByUser(userId);
  }

  Future<List<Task>> getTasksByUserAndDate(int userId, String date) async {
    return await _dbHelper.getTasksByUserAndDate(userId, date);
  }

  /// Update task locally, then sync to Firestore.
  Future<int> updateTask(Task task, {String? firebaseUserId}) async {
    final result = await _dbHelper.updateTask(task);

    if (firebaseUserId != null && task.id != null) {
      await _tasksCollection(
        firebaseUserId,
      ).doc(task.id).update(task.toFirestore());
    }
    return result;
  }

  /// Delete task locally, then remove from Firestore.
  Future<int> deleteTask(int id, {String? firebaseUserId}) async {
    final result = await _dbHelper.deleteTask(id);

    if (firebaseUserId != null) {
      await _tasksCollection(firebaseUserId).doc(id.toString()).delete();
    }
    return result;
  }

  // ==================== Firestore-only methods ====================

  /// Real-time task stream from Firestore
  Stream<List<Task>> getTasksStream(String firebaseUserId) {
    return _tasksCollection(
      firebaseUserId,
    ).orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Task.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  /// Pull all tasks from Firestore and merge into SQLite.
  /// Existing local tasks (by ID) are skipped; new ones are inserted.
  Future<void> syncFromFirestore(String firebaseUserId, int localUserId) async {
    final snapshot = await _tasksCollection(firebaseUserId).get();

    for (final doc in snapshot.docs) {
      final firestoreId = int.tryParse(doc.id);
      if (firestoreId == null) continue;

      final existing = await _dbHelper.getTask(firestoreId);
      if (existing == null) {
        final data = doc.data() as Map<String, dynamic>;
        final task = Task(
          id: doc.id,
          userId: localUserId,
          title: data['title'] ?? '',
          time: data['time'] ?? '',
          date: data['date'] ?? '',
          isCompleted: data['isCompleted'] ?? false,
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
        await _dbHelper.insertTask(task);
      }
    }
  }
}
