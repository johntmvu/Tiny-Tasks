import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/task.dart';
import '../models/big_task.dart';
import '../models/tiny_task.dart';
import '../models/reminder.dart';
import '../models/calendar_event.dart';
import '../models/user_preferences.dart';

class SQLiteHelper {
  static final SQLiteHelper instance = SQLiteHelper._init();
  Database? _database;

  SQLiteHelper._init();

  // For testing: create a new instance with in-memory database
  static Future<SQLiteHelper> createInMemory() async {
    final helper = SQLiteHelper._init();
    helper._database = await helper._initDB(':memory:');
    return helper;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tinytasks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    String path;
    if (filePath == ':memory:') {
      path = filePath;
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, filePath);
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: (db) async {
        // Enable foreign key constraints
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const textTypeNullable = 'TEXT';
    const integerTypeNullable = 'INTEGER';

    // User table
    await db.execute('''
      CREATE TABLE User (
        User_ID $idType,
        Name $textType,
        Email $textType UNIQUE,
        Google_ID $textTypeNullable,
        Google_Token $textTypeNullable,
        Token_Expiry $textTypeNullable,
        Remember_Me $integerType DEFAULT 0,
        Created_At $textType
      )
    ''');

    // Task table
    await db.execute('''
      CREATE TABLE Task (
        Task_ID $idType,
        User_ID $integerType,
        Title $textType,
        Description $textTypeNullable,
        Due_Date $textTypeNullable,
        Start_Time $textTypeNullable,
        End_Time $textTypeNullable,
        Priority $textTypeNullable,
        Is_Completed $integerType DEFAULT 0,
        Is_Recurring $integerType DEFAULT 0,
        Recurrence_Pattern $textTypeNullable,
        Reminder_Time $textTypeNullable,
        Created_At $textType,
        FOREIGN KEY (User_ID) REFERENCES User (User_ID) ON DELETE CASCADE
      )
    ''');

    // BigTask table
    await db.execute('''
      CREATE TABLE BigTask (
        BigTask_ID $idType,
        User_ID $integerType,
        Title $textType,
        Description $textTypeNullable,
        Due_Date $textTypeNullable,
        Priority $textTypeNullable,
        Created_At $textType,
        FOREIGN KEY (User_ID) REFERENCES User (User_ID) ON DELETE CASCADE
      )
    ''');

    // TinyTask table
    await db.execute('''
      CREATE TABLE TinyTask (
        TinyTask_ID $idType,
        Parent_BigTask_ID $integerType,
        Title $textType,
        Is_Completed $integerType DEFAULT 0,
        Due_Time $textTypeNullable,
        Created_At $textType,
        FOREIGN KEY (Parent_BigTask_ID) REFERENCES BigTask (BigTask_ID) ON DELETE CASCADE
      )
    ''');

    // Reminder table
    await db.execute('''
      CREATE TABLE Reminder (
        Reminder_ID $idType,
        Task_ID $integerType,
        Reminder_Time $textType,
        Is_Active $integerType DEFAULT 1,
        FOREIGN KEY (Task_ID) REFERENCES Task (Task_ID) ON DELETE CASCADE
      )
    ''');

    // CalendarEvent table
    await db.execute('''
      CREATE TABLE CalendarEvent (
        Event_ID $idType,
        User_ID $integerType,
        Google_Event_ID $textTypeNullable UNIQUE,
        Title $textType,
        Start_Time $textType,
        End_Time $textType,
        Status $textTypeNullable,
        Last_Synced $textTypeNullable,
        FOREIGN KEY (User_ID) REFERENCES User (User_ID) ON DELETE CASCADE
      )
    ''');

    // UserPreferences table
    await db.execute('''
      CREATE TABLE UserPreferences (
        Preference_ID $idType,
        User_ID $integerType,
        Default_View $textType DEFAULT 'Today',
        Dark_Mode $integerType DEFAULT 0,
        Notifications_Enabled $integerType DEFAULT 1,
        Half_Day_Default $textType DEFAULT 'Morning',
        FOREIGN KEY (User_ID) REFERENCES User (User_ID) ON DELETE CASCADE
      )
    ''');
  }

  // ==================== USER CRUD ====================
  Future<int> insertUser(User user) async {
    final db = await database;
    return await db.insert('User', user.toMap());
  }

  Future<User?> getUser(int id) async {
    final db = await database;
    final maps = await db.query(
      'User',
      where: 'User_ID = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final maps = await db.query(
      'User',
      where: 'Email = ?',
      whereArgs: [email],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateUser(User user) async {
    final db = await database;
    return await db.update(
      'User',
      user.toMap(),
      where: 'User_ID = ?',
      whereArgs: [user.userId],
    );
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return await db.delete(
      'User',
      where: 'User_ID = ?',
      whereArgs: [id],
    );
  }

  // ==================== TASK CRUD ====================
  Future<int> insertTask(Task task) async {
    final db = await database;
    return await db.insert('Task', task.toMap());
  }

  Future<Task?> getTask(int id) async {
    final db = await database;
    final maps = await db.query(
      'Task',
      where: 'Task_ID = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Task.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Task>> getTasksByUser(int userId) async {
    final db = await database;
    final maps = await db.query(
      'Task',
      where: 'User_ID = ?',
      whereArgs: [userId],
      orderBy: 'Created_At DESC',
    );
    return maps.map((map) => Task.fromMap(map)).toList();
  }

  Future<List<Task>> getTodayTasks(int userId, DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final maps = await db.query(
      'Task',
      where: 'User_ID = ? AND Due_Date >= ? AND Due_Date < ?',
      whereArgs: [userId, startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'Start_Time ASC',
    );
    return maps.map((map) => Task.fromMap(map)).toList();
  }

  Future<int> updateTask(Task task) async {
    final db = await database;
    return await db.update(
      'Task',
      task.toMap(),
      where: 'Task_ID = ?',
      whereArgs: [task.taskId],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await database;
    return await db.delete(
      'Task',
      where: 'Task_ID = ?',
      whereArgs: [id],
    );
  }

  // ==================== BIGTASK CRUD ====================
  Future<int> insertBigTask(BigTask bigTask) async {
    final db = await database;
    return await db.insert('BigTask', bigTask.toMap());
  }

  Future<BigTask?> getBigTask(int id) async {
    final db = await database;
    final maps = await db.query(
      'BigTask',
      where: 'BigTask_ID = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return BigTask.fromMap(maps.first);
    }
    return null;
  }

  Future<List<BigTask>> getBigTasksByUser(int userId) async {
    final db = await database;
    final maps = await db.query(
      'BigTask',
      where: 'User_ID = ?',
      whereArgs: [userId],
      orderBy: 'Created_At DESC',
    );
    return maps.map((map) => BigTask.fromMap(map)).toList();
  }

  Future<int> updateBigTask(BigTask bigTask) async {
    final db = await database;
    return await db.update(
      'BigTask',
      bigTask.toMap(),
      where: 'BigTask_ID = ?',
      whereArgs: [bigTask.bigTaskId],
    );
  }

  Future<int> deleteBigTask(int id) async {
    final db = await database;
    return await db.delete(
      'BigTask',
      where: 'BigTask_ID = ?',
      whereArgs: [id],
    );
  }

  // ==================== TINYTASK CRUD ====================
  Future<int> insertTinyTask(TinyTask tinyTask) async {
    final db = await database;
    return await db.insert('TinyTask', tinyTask.toMap());
  }

  Future<TinyTask?> getTinyTask(int id) async {
    final db = await database;
    final maps = await db.query(
      'TinyTask',
      where: 'TinyTask_ID = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return TinyTask.fromMap(maps.first);
    }
    return null;
  }

  Future<List<TinyTask>> getTinyTasksByBigTask(int bigTaskId) async {
    final db = await database;
    final maps = await db.query(
      'TinyTask',
      where: 'Parent_BigTask_ID = ?',
      whereArgs: [bigTaskId],
      orderBy: 'Created_At ASC',
    );
    return maps.map((map) => TinyTask.fromMap(map)).toList();
  }

  Future<int> updateTinyTask(TinyTask tinyTask) async {
    final db = await database;
    return await db.update(
      'TinyTask',
      tinyTask.toMap(),
      where: 'TinyTask_ID = ?',
      whereArgs: [tinyTask.tinyTaskId],
    );
  }

  Future<int> deleteTinyTask(int id) async {
    final db = await database;
    return await db.delete(
      'TinyTask',
      where: 'TinyTask_ID = ?',
      whereArgs: [id],
    );
  }

  // ==================== REMINDER CRUD ====================
  Future<int> insertReminder(Reminder reminder) async {
    final db = await database;
    return await db.insert('Reminder', reminder.toMap());
  }

  Future<Reminder?> getReminder(int id) async {
    final db = await database;
    final maps = await db.query(
      'Reminder',
      where: 'Reminder_ID = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Reminder.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Reminder>> getRemindersByTask(int taskId) async {
    final db = await database;
    final maps = await db.query(
      'Reminder',
      where: 'Task_ID = ?',
      whereArgs: [taskId],
    );
    return maps.map((map) => Reminder.fromMap(map)).toList();
  }

  Future<int> updateReminder(Reminder reminder) async {
    final db = await database;
    return await db.update(
      'Reminder',
      reminder.toMap(),
      where: 'Reminder_ID = ?',
      whereArgs: [reminder.reminderId],
    );
  }

  Future<int> deleteReminder(int id) async {
    final db = await database;
    return await db.delete(
      'Reminder',
      where: 'Reminder_ID = ?',
      whereArgs: [id],
    );
  }

  // ==================== CALENDAR EVENT CRUD ====================
  Future<int> insertCalendarEvent(CalendarEvent event) async {
    final db = await database;
    return await db.insert('CalendarEvent', event.toMap());
  }

  Future<CalendarEvent?> getCalendarEvent(int id) async {
    final db = await database;
    final maps = await db.query(
      'CalendarEvent',
      where: 'Event_ID = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return CalendarEvent.fromMap(maps.first);
    }
    return null;
  }

  Future<List<CalendarEvent>> getCalendarEventsByUser(int userId) async {
    final db = await database;
    final maps = await db.query(
      'CalendarEvent',
      where: 'User_ID = ?',
      whereArgs: [userId],
      orderBy: 'Start_Time ASC',
    );
    return maps.map((map) => CalendarEvent.fromMap(map)).toList();
  }

  Future<List<CalendarEvent>> getTodayCalendarEvents(int userId, DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final maps = await db.query(
      'CalendarEvent',
      where: 'User_ID = ? AND Start_Time >= ? AND Start_Time < ?',
      whereArgs: [userId, startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'Start_Time ASC',
    );
    return maps.map((map) => CalendarEvent.fromMap(map)).toList();
  }

  Future<int> updateCalendarEvent(CalendarEvent event) async {
    final db = await database;
    return await db.update(
      'CalendarEvent',
      event.toMap(),
      where: 'Event_ID = ?',
      whereArgs: [event.eventId],
    );
  }

  Future<int> deleteCalendarEvent(int id) async {
    final db = await database;
    return await db.delete(
      'CalendarEvent',
      where: 'Event_ID = ?',
      whereArgs: [id],
    );
  }

  // ==================== USER PREFERENCES CRUD ====================
  Future<int> insertUserPreferences(UserPreferences prefs) async {
    final db = await database;
    return await db.insert('UserPreferences', prefs.toMap());
  }

  Future<UserPreferences?> getUserPreferences(int userId) async {
    final db = await database;
    final maps = await db.query(
      'UserPreferences',
      where: 'User_ID = ?',
      whereArgs: [userId],
    );
    if (maps.isNotEmpty) {
      return UserPreferences.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateUserPreferences(UserPreferences prefs) async {
    final db = await database;
    return await db.update(
      'UserPreferences',
      prefs.toMap(),
      where: 'Preference_ID = ?',
      whereArgs: [prefs.preferenceId],
    );
  }

  Future<int> deleteUserPreferences(int id) async {
    final db = await database;
    return await db.delete(
      'UserPreferences',
      where: 'Preference_ID = ?',
      whereArgs: [id],
    );
  }

  // ==================== UTILITY METHODS ====================
  Future<void> clearAllTables() async {
    final db = await database;
    await db.delete('UserPreferences');
    await db.delete('CalendarEvent');
    await db.delete('Reminder');
    await db.delete('TinyTask');
    await db.delete('BigTask');
    await db.delete('Task');
    await db.delete('User');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
