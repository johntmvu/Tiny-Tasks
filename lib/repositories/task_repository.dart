import '../database/sqlite_helper.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TaskRepository {
  final SQLiteHelper _dbHelper;
  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore get _firestore =>
      _firestoreInstance ??= FirebaseFirestore.instance;

  TaskRepository({SQLiteHelper? dbHelper})
    : _dbHelper = dbHelper ?? SQLiteHelper.instance;

  CollectionReference _tasksCollection(String firebaseUserId) =>
      _firestore.collection('users').doc(firebaseUserId).collection('tasks');

  


  Future<int> createTask(Task task, {String? firebaseUserId}) async {
    final sqliteId = await _dbHelper.insertTask(task);

    Task taskWithId = task.copyWith(id: sqliteId);

    if (taskWithId.reminderEnabled) {
      final notifId = await NotificationService.instance
          .scheduleTaskReminder(taskWithId);
      if (notifId != null) {
        taskWithId = taskWithId.copyWith(notificationId: notifId);
        await _dbHelper.updateTask(taskWithId);
      }
    }

    if (firebaseUserId != null) {
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
    // Cancel existing reminder before rescheduling
    if (task.notificationId != null) {
      await NotificationService.instance.cancelReminder(task.notificationId!);
    }

    Task updatedTask = task;
    if (task.reminderEnabled && !task.isCompleted) {
      final notifId =
          await NotificationService.instance.scheduleTaskReminder(task);
      updatedTask = task.copyWith(notificationId: notifId);
    } else {
      updatedTask = task.copyWith(notificationId: null);
    }

    final result = await _dbHelper.updateTask(updatedTask);

    if (firebaseUserId != null && updatedTask.id != null) {
      await _tasksCollection(
        firebaseUserId,
      ).doc(updatedTask.id.toString()).update(updatedTask.toFirestore());
    }

    return result;
  }

  
  Future<int> deleteTask(int id, {String? firebaseUserId}) async {
    final task = await _dbHelper.getTask(id);
    if (task?.notificationId != null) {
      await NotificationService.instance.cancelReminder(task!.notificationId!);
    }

    final result = await _dbHelper.deleteTask(id);

    if (firebaseUserId != null) {
      await _tasksCollection(firebaseUserId).doc(id.toString()).delete();
    }

    return result;
  }

  

  Stream<List<Task>> getTasksStream(String firebaseUserId) {
    return _tasksCollection(
      firebaseUserId,
    ).orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Task.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  Future<void> syncFromFirestore(String firebaseUserId, int localUserId) async {
    final snapshot = await _tasksCollection(firebaseUserId).get();

    for (final doc in snapshot.docs) {
      final firestoreId = int.tryParse(doc.id);
      if (firestoreId == null) continue;

      final existing = await _dbHelper.getTask(firestoreId);
      if (existing == null) {
        final data = doc.data() as Map<String, dynamic>;

        final task = Task(
          id: firestoreId,
          userId: localUserId,
          firebaseUserId: data['firebaseUserId']?.toString(),
          title: data['title'] ?? '',
          description: data['description'],
          time: data['time'] ?? '',
          date: data['date'] ?? '',
          isCompleted: data['isCompleted'] ?? false,
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          period: data['period'] ?? 'full',
        );

        await _dbHelper.insertTask(task);
      }
    }
  }
}