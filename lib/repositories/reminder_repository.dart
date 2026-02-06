import '../database/sqlite_helper.dart';
import '../models/reminder.dart';

class ReminderRepository {
  final SQLiteHelper _dbHelper;

  ReminderRepository({SQLiteHelper? dbHelper})
      : _dbHelper = dbHelper ?? SQLiteHelper.instance;

  Future<int> createReminder(Reminder reminder) async {
    return await _dbHelper.insertReminder(reminder);
  }

  Future<Reminder?> getReminderById(int id) async {
    return await _dbHelper.getReminder(id);
  }

  Future<List<Reminder>> getRemindersByTask(int taskId) async {
    return await _dbHelper.getRemindersByTask(taskId);
  }

  Future<int> updateReminder(Reminder reminder) async {
    return await _dbHelper.updateReminder(reminder);
  }

  Future<int> deleteReminder(int id) async {
    return await _dbHelper.deleteReminder(id);
  }

  Future<int> deactivateReminder(int reminderId) async {
    final reminder = await getReminderById(reminderId);
    if (reminder != null) {
      final updatedReminder = reminder.copyWith(isActive: false);
      return await updateReminder(updatedReminder);
    }
    return 0;
  }
}
