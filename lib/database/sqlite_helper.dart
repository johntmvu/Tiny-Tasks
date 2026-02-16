import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/task.dart';

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

    // User table
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

    // Task table 
    await db.execute('''
      CREATE TABLE Task (
        Task_ID $idType,
        User_ID $integerType,
        Title $textType,
        Time $textType,
        Is_Completed $integerType DEFAULT 0,
        Created_At $textType,
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

  Future<int> updateTask(Task task) async {
    final db = await database;
    return await db.update(
      'Task',
      task.toMap(),
      where: 'Task_ID = ?',
      whereArgs: [task.id],
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

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
