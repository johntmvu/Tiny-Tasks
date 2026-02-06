import '../database/sqlite_helper.dart';
import '../models/user_preferences.dart';

class UserPreferencesRepository {
  final SQLiteHelper _dbHelper;

  UserPreferencesRepository({SQLiteHelper? dbHelper})
      : _dbHelper = dbHelper ?? SQLiteHelper.instance;

  Future<int> createUserPreferences(UserPreferences prefs) async {
    return await _dbHelper.insertUserPreferences(prefs);
  }

  Future<UserPreferences?> getUserPreferences(int userId) async {
    return await _dbHelper.getUserPreferences(userId);
  }

  Future<int> updateUserPreferences(UserPreferences prefs) async {
    return await _dbHelper.updateUserPreferences(prefs);
  }

  Future<int> deleteUserPreferences(int id) async {
    return await _dbHelper.deleteUserPreferences(id);
  }

  Future<UserPreferences> getOrCreateDefaultPreferences(int userId) async {
    var prefs = await getUserPreferences(userId);
    if (prefs == null) {
      prefs = UserPreferences(userId: userId);
      await createUserPreferences(prefs);
      prefs = await getUserPreferences(userId);
    }
    return prefs!;
  }
}
