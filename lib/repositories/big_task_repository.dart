import 'package:cloud_firestore/cloud_firestore.dart';
import '../database/sqlite_helper.dart';
import '../models/big_task.dart';
import '../models/task.dart';

class BigTaskRepository {
  final SQLiteHelper _dbHelper;
  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore get _firestore =>
      _firestoreInstance ??= FirebaseFirestore.instance;

  BigTaskRepository({SQLiteHelper? dbHelper})
      : _dbHelper = dbHelper ?? SQLiteHelper.instance;

  CollectionReference _bigTasksCollection(String firebaseUserId) =>
      _firestore.collection('users').doc(firebaseUserId).collection('bigTasks');

  Future<int> createBigTask(BigTask bigTask, {String? firebaseUserId}) async {
    final sqliteId = await _dbHelper.insertBigTask(bigTask);

    if (firebaseUserId != null) {
      final bigTaskWithId = bigTask.copyWith(id: sqliteId);
      await _bigTasksCollection(firebaseUserId)
          .doc(sqliteId.toString())
          .set(bigTaskWithId.toFirestore());
    }

    return sqliteId;
  }

  Future<BigTask?> getBigTaskById(int id) async {
    return await _dbHelper.getBigTask(id);
  }

  Future<List<BigTask>> getBigTasksByUser(int userId) async {
    return await _dbHelper.getBigTasksByUser(userId);
  }

  Future<int> updateBigTask(BigTask bigTask, {String? firebaseUserId}) async {
    final result = await _dbHelper.updateBigTask(bigTask);

    if (firebaseUserId != null && bigTask.id != null) {
      await _bigTasksCollection(firebaseUserId)
          .doc(bigTask.id.toString())
          .update(bigTask.toFirestore());
    }

    return result;
  }

  Future<int> deleteBigTask(int id, {String? firebaseUserId}) async {
    final result = await _dbHelper.deleteBigTask(id);

    if (firebaseUserId != null) {
      await _bigTasksCollection(firebaseUserId).doc(id.toString()).delete();
    }

    return result;
  }

  Future<List<Task>> getTinyTasksForBigTask(int bigTaskId) async {
    return await _dbHelper.getTasksByBigTask(bigTaskId);
  }
}
