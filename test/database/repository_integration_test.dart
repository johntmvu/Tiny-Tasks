import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tinytasks/repositories/task_repository.dart';
import 'package:tinytasks/repositories/big_task_repository.dart';
import 'package:tinytasks/database/sqlite_helper.dart';
import 'package:tinytasks/models/user.dart';
import 'package:tinytasks/models/task.dart';
import 'package:tinytasks/models/big_task.dart';

void main() {
  late TaskRepository taskRepo;
  late BigTaskRepository bigTaskRepo;
  late SQLiteHelper dbHelper;
  late int testUserId;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbHelper = await SQLiteHelper.createInMemory();
    taskRepo = TaskRepository(dbHelper: dbHelper);
    bigTaskRepo = BigTaskRepository(dbHelper: dbHelper);

    final user = User(name: 'Test User', email: 'test@example.com');
    testUserId = await dbHelper.insertUser(user);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('Repository Integration Tests', () {
    test('Complete task workflow', () async {
      final task = Task(userId: testUserId, title: 'Write report', date: '2026-04-10');
      // No firebaseUserId → Firestore writes are skipped
      final taskId = await taskRepo.createTask(task);
      expect(taskId, greaterThan(0));

      final retrieved = await taskRepo.getTaskById(taskId);
      expect(retrieved, isNotNull);
      expect(retrieved!.title, equals('Write report'));

      final completed = retrieved.copyWith(isCompleted: true);
      await taskRepo.updateTask(completed);

      final updated = await taskRepo.getTaskById(taskId);
      expect(updated!.isCompleted, isTrue);
    });

    test('Get tasks by user and date filters correctly', () async {
      await taskRepo.createTask(Task(userId: testUserId, title: 'Today 1', date: '2026-04-10'));
      await taskRepo.createTask(Task(userId: testUserId, title: 'Today 2', date: '2026-04-10'));
      await taskRepo.createTask(Task(userId: testUserId, title: 'Tomorrow', date: '2026-04-11'));

      final todayTasks = await taskRepo.getTasksByUserAndDate(testUserId, '2026-04-10');
      expect(todayTasks.length, equals(2));
      expect(todayTasks.every((t) => t.date == '2026-04-10'), isTrue);
    });

    test('Delete task removes it', () async {
      final taskId = await taskRepo.createTask(
        Task(userId: testUserId, title: 'Delete me', date: '2026-04-10'),
      );

      await taskRepo.deleteTask(taskId);
      final retrieved = await taskRepo.getTaskById(taskId);
      expect(retrieved, isNull);
    });

    test('Complete big task + tiny tasks workflow', () async {
      // Create big task
      final bigTask = BigTask(
        userId: testUserId,
        title: 'Complete Capstone Project',
        description: 'Database implementation sprint',
        dueDate: '2026-05-01',
        color: 'purple',
      );
      final bigTaskId = await bigTaskRepo.createBigTask(bigTask);
      expect(bigTaskId, greaterThan(0));

      // Create tiny tasks linked to the big task
      final subtaskTitles = ['Setup database', 'Create models', 'Write tests'];
      final subtaskDates = ['2026-04-10', '2026-04-12', '2026-04-14'];
      for (int i = 0; i < subtaskTitles.length; i++) {
        await taskRepo.createTask(Task(
          userId: testUserId,
          title: subtaskTitles[i],
          date: subtaskDates[i],
          bigTaskId: bigTaskId,
        ));
      }

      // Verify tiny tasks via repository
      final tinyTasks = await bigTaskRepo.getTinyTasksForBigTask(bigTaskId);
      expect(tinyTasks.length, equals(3));
      expect(tinyTasks.every((t) => t.bigTaskId == bigTaskId), isTrue);

      // Mark one complete
      final first = tinyTasks.first;
      await taskRepo.updateTask(first.copyWith(isCompleted: true));
      final updatedFirst = await taskRepo.getTaskById(first.id!);
      expect(updatedFirst!.isCompleted, isTrue);
    });

    test('User deletion cascades to tasks and big tasks', () async {
      // Insert a second user to avoid affecting testUserId data
      final user2 = User(name: 'User 2', email: 'user2@example.com');
      final userId2 = await dbHelper.insertUser(user2);

      await taskRepo.createTask(Task(userId: userId2, title: 'User Task', date: '2026-04-10'));
      await bigTaskRepo.createBigTask(BigTask(
        userId: userId2,
        title: 'User Big Task',
        dueDate: '2026-05-01',
      ));

      await dbHelper.deleteUser(userId2);

      final tasks = await taskRepo.getTasksByUser(userId2);
      expect(tasks.isEmpty, isTrue);

      final bigTasks = await bigTaskRepo.getBigTasksByUser(userId2);
      expect(bigTasks.isEmpty, isTrue);
    });

    test('Delete big task also deletes linked tiny tasks', () async {
      final bigTaskId = await bigTaskRepo.createBigTask(BigTask(
        userId: testUserId,
        title: 'Big Task',
        dueDate: '2026-05-01',
      ));

      final taskId = await taskRepo.createTask(Task(
        userId: testUserId,
        title: 'Tiny task',
        date: '2026-04-10',
        bigTaskId: bigTaskId,
      ));

      await bigTaskRepo.deleteBigTask(bigTaskId);

      final retrieved = await taskRepo.getTaskById(taskId);
      expect(retrieved, isNull);
    });
  });
}
