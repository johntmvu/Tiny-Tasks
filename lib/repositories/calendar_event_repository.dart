import '../database/sqlite_helper.dart';
import '../models/calendar_event.dart';

class CalendarEventRepository {
  final SQLiteHelper _dbHelper;

  CalendarEventRepository({SQLiteHelper? dbHelper})
      : _dbHelper = dbHelper ?? SQLiteHelper.instance;

  Future<int> createCalendarEvent(CalendarEvent event) async {
    return await _dbHelper.insertCalendarEvent(event);
  }

  Future<CalendarEvent?> getCalendarEventById(int id) async {
    return await _dbHelper.getCalendarEvent(id);
  }

  Future<List<CalendarEvent>> getCalendarEventsByUser(int userId) async {
    return await _dbHelper.getCalendarEventsByUser(userId);
  }

  Future<List<CalendarEvent>> getTodayCalendarEvents(int userId, DateTime date) async {
    return await _dbHelper.getTodayCalendarEvents(userId, date);
  }

  Future<int> updateCalendarEvent(CalendarEvent event) async {
    return await _dbHelper.updateCalendarEvent(event);
  }

  Future<int> deleteCalendarEvent(int id) async {
    return await _dbHelper.deleteCalendarEvent(id);
  }
}
