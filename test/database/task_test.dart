import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tinytasks/database/sqlite_helper.dart';
import 'package:tinytasks/models/user.dart';
import 'package:tinytasks/models/task.dart';
import 'package:tinytasks/models/big_task.dart';

void main() {
  late SQLiteHelper dbHelper;
  late int testUserId;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbHelper = await SQLiteHelper.createInMemory();
    final user = User(name: 'Test User', email: 'test@example.com');
    testUserId = await dbHelper.insertUser(user);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('Task CRUD Operations', () {
    test('Insert task should return valid ID', () async {
      final task = Task(
        userId: testUserId,
        title: 'Complete homework',
        description: 'Math assignment',
        date: '2026-04-10',
      );

      final id = await dbHelper.insertTask(task);
      expect(id, greaterThan(0));
    });

    test('Get task by ID should return correct task', () async {
      final task = Task(
        userId: testUserId,
        title: 'Study for exam',
        date: '2026-04-12',
      );

      final id = await dbHelper.insertTask(task);
      final retrieved = await dbHelper.getTask(id);

      expect(retrieved, isNotNull);
      expect(retrieved!.title, equals('Study for exam'));
      expect(retrieved.userId, equals(testUserId));
    });

    test('Get tasks by user should return all user tasks', () async {
      await dbHelper.insertTask(Task(userId: testUserId, title: 'Task 1', date: '2026-04-10'));
      await dbHelper.insertTask(Task(userId: testUserId, title: 'Task 2', date: '2026-04-10'));
      await dbHelper.insertTask(Task(userId: testUserId, title: 'Task 3', date: '2026-04-11'));

      final tasks = await dbHelper.getTasksByUser(testUserId);
      expect(tasks.length, equals(3));
    });

    test('Get tasks by user and date should filter correctly', () async {
      await dbHelper.insertTask(Task(userId: testUserId, title: 'Today Task 1', date: '2026-04-10'));
      await dbHelper.insertTask(Task(userId: testUserId, title: 'Today Task 2', date: '2026-04-10'));
      await dbHelper.insertTask(Task(userId: testUserId, title: 'Tomorrow Task', date: '2026-04-11'));

      final todayTasks = await dbHelper.getTasksByUserAndDate(testUserId, '2026-04-10');
      expect(todayTasks.length, equals(2));
      expect(todayTasks.every((t) => t.date == '2026-04-10'), isTrue);
    });

    test('Update task should modify existing task', () async {
      final task = Task(userId: testUserId, title: 'Original Title', date: '2026-04-10');
      final id = await dbHelper.insertTask(task);

      final updated = task.copyWith(id: id, title: 'Updated Title', isCompleted: true);
      final rowsAffected = await dbHelper.updateTask(updated);
      expect(rowsAffected, equals(1));

      final retrieved = await dbHelper.getTask(id);
      expect(retrieved!.title, equals('Updated Title'));
      expect(retrieved.isCompleted, isTrue);
    });

    test('Delete task should remove task from database', () async {
      final task = Task(userId: testUserId, title: 'Task to delete', date: '2026-04-10');
      final id = await dbHelper.insertTask(task);

      final rowsAffected = await dbHelper.deleteTask(id);
      expect(rowsAffected, equals(1));

      final retrieved = await dbHelper.getTask(id);
      expect(retrieved, isNull);
    });

    test('Task period field is persisted correctly', () async {
      final amTask = Task(userId: testUserId, title: 'AM Task', date: '2026-04-10', period: 'am');
      final id = await dbHelper.insertTask(amTask);
      final retrieved = await dbHelper.getTask(id);
      expect(retrieved!.period, equals('am'));
    });

    test('Task bigTaskId field is persisted correctly', () async {
      final bigTaskId = await dbHelper.insertBigTask(
        BigTask(userId: testUserId, title: 'Parent', dueDate: '2026-05-01'),
      );
      final task = Task(
        userId: testUserId,
        title: 'Tiny task',
        date: '2026-04-10',
        bigTaskId: bigTaskId,
      );
      final id = await dbHelper.insertTask(task);
      final retrieved = await dbHelper.getTask(id);
      expect(retrieved!.bigTaskId, equals(bigTaskId));
    });
  });
}
