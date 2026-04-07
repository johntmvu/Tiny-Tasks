

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/task.dart';
import '../models/big_task.dart';

class SQLiteHelper {
  static final SQLiteHelper instance = SQLiteHelper._init();
  Database? _database;

  SQLiteHelper._init();

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
      version: 6,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE User (
        User_ID $idType,
        Name $textType,
        Email $textType UNIQUE,
        Google_ID TEXT,
        Google_Token TEXT,
        Token_Expiry TEXT,
        Remember_Me INTEGER DEFAULT 0,
        Created_At $textType
      )
    ''');

    await db.execute('''
      CREATE TABLE BigTask (
        BigTask_ID $idType,
        User_ID $integerType,
        Title $textType,
        Description TEXT,
        Priority TEXT NOT NULL DEFAULT 'medium',
        Due_Date $textType,
        Color TEXT NOT NULL DEFAULT 'blue',
        Created_At $textType,
        FirebaseUserId TEXT,
        FOREIGN KEY (User_ID) REFERENCES User (User_ID) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE Task (
        Task_ID $idType,
        User_ID $integerType,
        Title $textType,
        Time TEXT NOT NULL DEFAULT '',
        Date TEXT NOT NULL DEFAULT '',
        Is_Completed INTEGER NOT NULL DEFAULT 0,
        Created_At TEXT NOT NULL,
        Description TEXT,
        FirebaseUserId TEXT,
        Period TEXT NOT NULL DEFAULT 'full',
        BigTask_ID INTEGER REFERENCES BigTask (BigTask_ID) ON DELETE SET NULL,
        FOREIGN KEY (User_ID) REFERENCES User (User_ID) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 5) {
      await db.execute('DROP TABLE IF EXISTS Task');
      const textType = 'TEXT NOT NULL';
      const integerType = 'INTEGER NOT NULL';
      await db.execute('''
        CREATE TABLE Task (
          Task_ID INTEGER PRIMARY KEY AUTOINCREMENT,
          User_ID $integerType,
          Title $textType,
          Time TEXT NOT NULL DEFAULT '',
          Date TEXT NOT NULL DEFAULT '',
          Is_Completed INTEGER NOT NULL DEFAULT 0,
          Created_At TEXT NOT NULL,
          Description TEXT,
          FirebaseUserId TEXT,
          Period TEXT NOT NULL DEFAULT 'full',
          FOREIGN KEY (User_ID) REFERENCES User (User_ID) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS BigTask (
          BigTask_ID INTEGER PRIMARY KEY AUTOINCREMENT,
          User_ID INTEGER NOT NULL,
          Title TEXT NOT NULL,
          Description TEXT,
          Priority TEXT NOT NULL DEFAULT 'medium',
          Due_Date TEXT NOT NULL,
          Color TEXT NOT NULL DEFAULT 'blue',
          Created_At TEXT NOT NULL,
          FirebaseUserId TEXT,
          FOREIGN KEY (User_ID) REFERENCES User (User_ID) ON DELETE CASCADE
        )
      ''');
      await db.execute(
        'ALTER TABLE Task ADD COLUMN BigTask_ID INTEGER REFERENCES BigTask (BigTask_ID) ON DELETE SET NULL',
      );
    }
  }

  Future<int> insertUser(User user) async {
    final db = await database;
    return await db.insert('User', user.toMap());
  }

  Future<User?> getUser(int id) async {
    final db = await database;
    final maps = await db.query('User', where: 'User_ID = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final maps = await db.query('User', where: 'Email = ?', whereArgs: [email]);
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
    return await db.delete('User', where: 'User_ID = ?', whereArgs: [id]);
  }

  Future<int> insertTask(Task task) async {
    final db = await database;
    final data = task.toMap();
    data.remove('Task_ID');
    return await db.insert('Task', data);
  }

  Future<Task?> getTask(int id) async {
    final db = await database;
    final maps = await db.query('Task', where: 'Task_ID = ?', whereArgs: [id]);
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

  Future<List<Task>> getTasksByUserAndDate(int userId, String date) async {
    final db = await database;
    final maps = await db.query(
      'Task',
      where: 'User_ID = ? AND Date = ?',
      whereArgs: [userId, date],
      orderBy: 'Time ASC',
    );
    return maps.map((map) => Task.fromMap(map)).toList();
  }

  Future<int> updateTask(Task task) async {
    final db = await database;
    final data = task.toMap();
    data.remove('Task_ID');
    return await db.update(
      'Task',
      data,
      where: 'Task_ID = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await database;
    return await db.delete('Task', where: 'Task_ID = ?', whereArgs: [id]);
  }

  Future<List<Task>> getTasksByBigTask(int bigTaskId) async {
    final db = await database;
    final maps = await db.query(
      'Task',
      where: 'BigTask_ID = ?',
      whereArgs: [bigTaskId],
      orderBy: 'Date ASC',
    );
    return maps.map((map) => Task.fromMap(map)).toList();
  }

  Future<int> insertBigTask(BigTask bigTask) async {
    final db = await database;
    final data = bigTask.toMap();
    data.remove('BigTask_ID');
    return await db.insert('BigTask', data);
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
      orderBy: 'Due_Date ASC',
    );
    return maps.map((map) => BigTask.fromMap(map)).toList();
  }

  Future<int> updateBigTask(BigTask bigTask) async {
    final db = await database;
    final data = bigTask.toMap();
    data.remove('BigTask_ID');
    return await db.update(
      'BigTask',
      data,
      where: 'BigTask_ID = ?',
      whereArgs: [bigTask.id],
    );
  }

  Future<int> deleteBigTask(int id) async {
    final db = await database;
    return await db.delete('BigTask', where: 'BigTask_ID = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
