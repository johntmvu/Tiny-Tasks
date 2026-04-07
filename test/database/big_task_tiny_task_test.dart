import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tinytasks/database/sqlite_helper.dart';
import 'package:tinytasks/models/user.dart';
import 'package:tinytasks/models/big_task.dart';
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
    final user = User(name: 'Test User', email: 'test@example.com');
    testUserId = await dbHelper.insertUser(user);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('BigTask CRUD Operations', () {
    test('Insert big task should return valid ID', () async {
      final bigTask = BigTask(
        userId: testUserId,
        title: 'Complete Project',
        description: 'Final year capstone project',
        priority: 'high',
        dueDate: '2026-05-01',
        color: 'blue',
      );

      final id = await dbHelper.insertBigTask(bigTask);
      expect(id, greaterThan(0));
    });

    test('Get big task by ID should return correct big task', () async {
      final bigTask = BigTask(
        userId: testUserId,
        title: 'Launch Website',
        dueDate: '2026-05-15',
      );

      final id = await dbHelper.insertBigTask(bigTask);
      final retrieved = await dbHelper.getBigTask(id);

      expect(retrieved, isNotNull);
      expect(retrieved!.title, equals('Launch Website'));
      expect(retrieved.userId, equals(testUserId));
      expect(retrieved.dueDate, equals('2026-05-15'));
    });

    test('Get big tasks by user should return all big tasks ordered by due date', () async {
      await dbHelper.insertBigTask(BigTask(userId: testUserId, title: 'Task B', dueDate: '2026-06-01'));
      await dbHelper.insertBigTask(BigTask(userId: testUserId, title: 'Task A', dueDate: '2026-05-01'));

      final bigTasks = await dbHelper.getBigTasksByUser(testUserId);
      expect(bigTasks.length, equals(2));
      // Should be ordered by due date ASC
      expect(bigTasks.first.title, equals('Task A'));
      expect(bigTasks.last.title, equals('Task B'));
    });

    test('Update big task should modify existing big task', () async {
      final bigTask = BigTask(
        userId: testUserId,
        title: 'Original Title',
        dueDate: '2026-05-01',
        color: 'blue',
      );
      final id = await dbHelper.insertBigTask(bigTask);

      final updated = bigTask.copyWith(id: id, title: 'Updated Title', color: 'green');
      final rowsAffected = await dbHelper.updateBigTask(updated);
      expect(rowsAffected, equals(1));

      final retrieved = await dbHelper.getBigTask(id);
      expect(retrieved!.title, equals('Updated Title'));
      expect(retrieved.color, equals('green'));
    });

    test('Delete big task should remove it from database', () async {
      final bigTask = BigTask(userId: testUserId, title: 'To Delete', dueDate: '2026-05-01');
      final id = await dbHelper.insertBigTask(bigTask);

      final rowsAffected = await dbHelper.deleteBigTask(id);
      expect(rowsAffected, equals(1));

      final retrieved = await dbHelper.getBigTask(id);
      expect(retrieved, isNull);
    });

    test('BigTask default color is blue and priority is medium', () async {
      final bigTask = BigTask(userId: testUserId, title: 'Defaults Test', dueDate: '2026-05-01');
      final id = await dbHelper.insertBigTask(bigTask);
      final retrieved = await dbHelper.getBigTask(id);

      expect(retrieved!.color, equals('blue'));
      expect(retrieved.priority, equals('medium'));
    });
  });

  group('Tiny Task (Task with bigTaskId) Operations', () {
    late int testBigTaskId;

    setUp(() async {
      final bigTask = BigTask(
        userId: testUserId,
        title: 'Test Big Task',
        dueDate: '2026-05-01',
      );
      testBigTaskId = await dbHelper.insertBigTask(bigTask);
    });

    test('Insert tiny task with bigTaskId should return valid ID', () async {
      final task = Task(
        userId: testUserId,
        title: 'Research topic',
        date: '2026-04-10',
        bigTaskId: testBigTaskId,
      );

      final id = await dbHelper.insertTask(task);
      expect(id, greaterThan(0));

      final retrieved = await dbHelper.getTask(id);
      expect(retrieved!.bigTaskId, equals(testBigTaskId));
    });

    test('Get tasks by big task should return all linked tasks', () async {
      await dbHelper.insertTask(Task(userId: testUserId, title: 'Step 1', date: '2026-04-10', bigTaskId: testBigTaskId));
      await dbHelper.insertTask(Task(userId: testUserId, title: 'Step 2', date: '2026-04-11', bigTaskId: testBigTaskId));
      await dbHelper.insertTask(Task(userId: testUserId, title: 'Step 3', date: '2026-04-12', bigTaskId: testBigTaskId));
      // Standalone task (no bigTaskId) — should not be included
      await dbHelper.insertTask(Task(userId: testUserId, title: 'Standalone', date: '2026-04-10'));

      final tinyTasks = await dbHelper.getTasksByBigTask(testBigTaskId);
      expect(tinyTasks.length, equals(3));
      expect(tinyTasks.every((t) => t.bigTaskId == testBigTaskId), isTrue);
    });

    test('Get tasks by big task should be ordered by date ASC', () async {
      await dbHelper.insertTask(Task(userId: testUserId, title: 'Last', date: '2026-04-15', bigTaskId: testBigTaskId));
      await dbHelper.insertTask(Task(userId: testUserId, title: 'First', date: '2026-04-10', bigTaskId: testBigTaskId));
      await dbHelper.insertTask(Task(userId: testUserId, title: 'Middle', date: '2026-04-12', bigTaskId: testBigTaskId));

      final tasks = await dbHelper.getTasksByBigTask(testBigTaskId);
      expect(tasks[0].title, equals('First'));
      expect(tasks[1].title, equals('Middle'));
      expect(tasks[2].title, equals('Last'));
    });

    test('Update tiny task completion status', () async {
      final task = Task(
        userId: testUserId,
        title: 'Complete reading',
        date: '2026-04-10',
        isCompleted: false,
        bigTaskId: testBigTaskId,
      );

      final id = await dbHelper.insertTask(task);
      final updated = task.copyWith(id: id, isCompleted: true);
      await dbHelper.updateTask(updated);

      final retrieved = await dbHelper.getTask(id);
      expect(retrieved!.isCompleted, isTrue);
    });

    test('Delete big task sets bigTaskId to NULL on linked tasks (ON DELETE SET NULL)', () async {
      final taskId = await dbHelper.insertTask(Task(
        userId: testUserId,
        title: 'Linked task',
        date: '2026-04-10',
        bigTaskId: testBigTaskId,
      ));

      await dbHelper.deleteBigTask(testBigTaskId);

      final retrieved = await dbHelper.getTask(taskId);
      expect(retrieved, isNotNull);
      expect(retrieved!.bigTaskId, isNull);
    });
  });
}
