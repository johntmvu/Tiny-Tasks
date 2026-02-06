import '../database/sqlite_helper.dart';
import '../models/big_task.dart';

class BigTaskRepository {
  final SQLiteHelper _dbHelper;

  BigTaskRepository({SQLiteHelper? dbHelper})
      : _dbHelper = dbHelper ?? SQLiteHelper.instance;

  Future<int> createBigTask(BigTask bigTask) async {
    return await _dbHelper.insertBigTask(bigTask);
  }

  Future<BigTask?> getBigTaskById(int id) async {
    return await _dbHelper.getBigTask(id);
  }

  Future<List<BigTask>> getBigTasksByUser(int userId) async {
    return await _dbHelper.getBigTasksByUser(userId);
  }

  Future<int> updateBigTask(BigTask bigTask) async {
    return await _dbHelper.updateBigTask(bigTask);
  }

  Future<int> deleteBigTask(int id) async {
    return await _dbHelper.deleteBigTask(id);
  }
}
