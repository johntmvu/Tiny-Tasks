import '../database/sqlite_helper.dart';
import '../models/tiny_task.dart';

class TinyTaskRepository {
  final SQLiteHelper _dbHelper;

  TinyTaskRepository({SQLiteHelper? dbHelper})
      : _dbHelper = dbHelper ?? SQLiteHelper.instance;

  Future<int> createTinyTask(TinyTask tinyTask) async {
    return await _dbHelper.insertTinyTask(tinyTask);
  }

  Future<TinyTask?> getTinyTaskById(int id) async {
    return await _dbHelper.getTinyTask(id);
  }

  Future<List<TinyTask>> getTinyTasksByBigTask(int bigTaskId) async {
    return await _dbHelper.getTinyTasksByBigTask(bigTaskId);
  }

  Future<int> updateTinyTask(TinyTask tinyTask) async {
    return await _dbHelper.updateTinyTask(tinyTask);
  }

  Future<int> deleteTinyTask(int id) async {
    return await _dbHelper.deleteTinyTask(id);
  }

  Future<int> markTinyTaskAsCompleted(int tinyTaskId) async {
    final tinyTask = await getTinyTaskById(tinyTaskId);
    if (tinyTask != null) {
      final updatedTask = tinyTask.copyWith(isCompleted: true);
      return await updateTinyTask(updatedTask);
    }
    return 0;
  }
}
