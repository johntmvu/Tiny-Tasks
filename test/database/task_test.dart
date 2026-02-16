import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tinytasks/database/sqlite_helper.dart';
import 'package:tinytasks/models/user.dart';
import 'package:tinytasks/models/task.dart';

void main() {
  late SQLiteHelper dbHelper;
  late int testUserId;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbHelper = await SQLiteHelper.createInMemory();

    // Create a test user
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
        priority: 'High',
      );

      final id = await dbHelper.insertTask(task);
      expect(id, greaterThan(0));
    });

    test('Get task by ID should return correct task', () async {
      final task = Task(
        userId: testUserId,
        title: 'Study for exam',
        dueDate: DateTime.now().add(const Duration(days: 2)),
      );

      final id = await dbHelper.insertTask(task);
      final retrievedTask = await dbHelper.getTask(id);

      expect(retrievedTask, isNotNull);
      expect(retrievedTask!.title, equals('Study for exam'));
      expect(retrievedTask.userId, equals(testUserId));
    });

    test('Get tasks by user should return all user tasks', () async {
      final task1 = Task(userId: testUserId, title: 'Task 1');
      final task2 = Task(userId: testUserId, title: 'Task 2');
      final task3 = Task(userId: testUserId, title: 'Task 3');

      await dbHelper.insertTask(task1);
      await dbHelper.insertTask(task2);
      await dbHelper.insertTask(task3);

      final tasks = await dbHelper.getTasksByUser(testUserId);
      expect(tasks.length, equals(3));
    });

    test('Get today tasks should return only tasks for today', () async {
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));

      final todayTask = Task(
        userId: testUserId,
        title: 'Today Task',
        dueDate: today,
      );
      final tomorrowTask = Task(
        userId: testUserId,
        title: 'Tomorrow Task',
        dueDate: tomorrow,
      );

      await dbHelper.insertTask(todayTask);
      await dbHelper.insertTask(tomorrowTask);

      final todayTasks = await dbHelper.getTodayTasks(testUserId, today);
      expect(todayTasks.length, equals(1));
      expect(todayTasks.first.title, equals('Today Task'));
    });

    test('Update task should modify existing task', () async {
      final task = Task(
        userId: testUserId,
        title: 'Original Title',
        isCompleted: false,
      );

      final id = await dbHelper.insertTask(task);
      final updatedTask = task.copyWith(
        taskId: id,
        title: 'Updated Title',
        isCompleted: true,
      );

      final rowsAffected = await dbHelper.updateTask(updatedTask);
      expect(rowsAffected, equals(1));

      final retrievedTask = await dbHelper.getTask(id);
      expect(retrievedTask!.title, equals('Updated Title'));
      expect(retrievedTask.isCompleted, isTrue);
    });

    test('Delete task should remove task from database', () async {
      final task = Task(userId: testUserId, title: 'Task to delete');

      final id = await dbHelper.insertTask(task);
      final rowsAffected = await dbHelper.deleteTask(id);
      expect(rowsAffected, equals(1));

      final retrievedTask = await dbHelper.getTask(id);
      expect(retrievedTask, isNull);
    });

    test('Task with recurring pattern should be stored correctly', () async {
      final recurringTask = Task(
        userId: testUserId,
        title: 'Daily Exercise',
        isRecurring: true,
        recurrencePattern: 'DAILY',
      );

      final id = await dbHelper.insertTask(recurringTask);
      final retrievedTask = await dbHelper.getTask(id);

      expect(retrievedTask!.isRecurring, isTrue);
      expect(retrievedTask.recurrencePattern, equals('DAILY'));
    });
  });
}
