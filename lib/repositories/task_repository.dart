import '../database/sqlite_helper.dart';
import '../models/task.dart';

class TaskRepository {
  final SQLiteHelper _dbHelper;

  TaskRepository({SQLiteHelper? dbHelper})
      : _dbHelper = dbHelper ?? SQLiteHelper.instance;

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
}
