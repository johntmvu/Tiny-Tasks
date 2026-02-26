import '../database/sqlite_helper.dart';
import '../models/user.dart';

class UserRepository {
  final SQLiteHelper _dbHelper;

  UserRepository({SQLiteHelper? dbHelper})
      : _dbHelper = dbHelper ?? SQLiteHelper.instance;

  Future<int> createUser(User user) async {
    return await _dbHelper.insertUser(user);
  }

  Future<User?> getUserById(int id) async {
    return await _dbHelper.getUser(id);
  }

  Future<User?> getUserByEmail(String email) async {
    return await _dbHelper.getUserByEmail(email);
  }

  Future<int> updateUser(User user) async {
    return await _dbHelper.updateUser(user);
  }

  Future<int> deleteUser(int id) async {
    return await _dbHelper.deleteUser(id);
  }
}
