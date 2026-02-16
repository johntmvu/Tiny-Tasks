import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tinytasks/repositories/user_repository.dart';
import 'package:tinytasks/repositories/task_repository.dart';
import 'package:tinytasks/repositories/big_task_repository.dart';
import 'package:tinytasks/repositories/tiny_task_repository.dart';
import 'package:tinytasks/database/sqlite_helper.dart';
import 'package:tinytasks/models/user.dart';
import 'package:tinytasks/models/task.dart';
import 'package:tinytasks/models/big_task.dart';
import 'package:tinytasks/models/tiny_task.dart';

void main() {
  late UserRepository userRepo;
  late TaskRepository taskRepo;
  late BigTaskRepository bigTaskRepo;
  late TinyTaskRepository tinyTaskRepo;
  late SQLiteHelper dbHelper;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbHelper = await SQLiteHelper.createInMemory();

    userRepo = UserRepository(dbHelper: dbHelper);
    taskRepo = TaskRepository(dbHelper: dbHelper);
    bigTaskRepo = BigTaskRepository(dbHelper: dbHelper);
    tinyTaskRepo = TinyTaskRepository(dbHelper: dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('Repository Integration Tests', () {
    test('Complete user workflow', () async {
      // Create user
      final user = User(name: 'John Doe', email: 'john@example.com');
      final userId = await userRepo.createUser(user);
      expect(userId, greaterThan(0));

      // Retrieve user
      final retrievedUser = await userRepo.getUserById(userId);
      expect(retrievedUser, isNotNull);
      expect(retrievedUser!.email, equals('john@example.com'));

      // Update user
      final updatedUser = retrievedUser.copyWith(name: 'John Smith');
      await userRepo.updateUser(updatedUser);

      final finalUser = await userRepo.getUserById(userId);
      expect(finalUser!.name, equals('John Smith'));
    });

    test('Complete task workflow', () async {
      // Create user first
      final user = User(name: 'Test User', email: 'test@example.com');
      final userId = await userRepo.createUser(user);

      // Create task
      final task = Task(
        userId: userId,
        title: 'Write report',
        priority: 'High',
      );
      final taskId = await taskRepo.createTask(task);
      expect(taskId, greaterThan(0));

      // Mark as completed using repository method
      await taskRepo.markTaskAsCompleted(taskId);

      final completedTask = await taskRepo.getTaskById(taskId);
      expect(completedTask!.isCompleted, isTrue);
    });

    test('Complete big task with tiny tasks workflow', () async {
      // Create user
      final user = User(name: 'Test User', email: 'test@example.com');
      final userId = await userRepo.createUser(user);

      // Create big task
      final bigTask = BigTask(
        userId: userId,
        title: 'Complete Capstone Project',
        description: 'Database implementation sprint',
      );
      final bigTaskId = await bigTaskRepo.createBigTask(bigTask);

      // Create tiny tasks
      final tinyTasks = [
        TinyTask(parentBigTaskId: bigTaskId, title: 'Setup database'),
        TinyTask(parentBigTaskId: bigTaskId, title: 'Create models'),
        TinyTask(parentBigTaskId: bigTaskId, title: 'Write tests'),
      ];

      for (var tinyTask in tinyTasks) {
        await tinyTaskRepo.createTinyTask(tinyTask);
      }

      // Verify all tiny tasks were created
      final retrievedTinyTasks = await tinyTaskRepo.getTinyTasksByBigTask(bigTaskId);
      expect(retrievedTinyTasks.length, equals(3));

      // Mark first tiny task as completed
      final firstTaskId = retrievedTinyTasks.first.tinyTaskId!;
      await tinyTaskRepo.markTinyTaskAsCompleted(firstTaskId);

      final completedTinyTask = await tinyTaskRepo.getTinyTaskById(firstTaskId);
      expect(completedTinyTask!.isCompleted, isTrue);
    });

    test('Get today tasks returns correct tasks', () async {
      final user = User(name: 'Test User', email: 'test@example.com');
      final userId = await userRepo.createUser(user);

      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));

      // Create tasks for today and tomorrow
      await taskRepo.createTask(Task(
        userId: userId,
        title: 'Today Task 1',
        dueDate: today,
      ));
      await taskRepo.createTask(Task(
        userId: userId,
        title: 'Today Task 2',
        dueDate: today,
      ));
      await taskRepo.createTask(Task(
        userId: userId,
        title: 'Tomorrow Task',
        dueDate: tomorrow,
      ));

      final todayTasks = await taskRepo.getTodayTasks(userId, today);
      expect(todayTasks.length, equals(2));
      expect(todayTasks.every((t) => t.title.contains('Today')), isTrue);
    });

    test('User deletion cascades to related entities', () async {
      final user = User(name: 'Test User', email: 'test@example.com');
      final userId = await userRepo.createUser(user);

      // Create task for user
      await taskRepo.createTask(Task(
        userId: userId,
        title: 'User Task',
      ));

      // Create big task for user
      await bigTaskRepo.createBigTask(BigTask(
        userId: userId,
        title: 'User Big Task',
      ));

      // Delete user
      await userRepo.deleteUser(userId);

      // Verify tasks are also deleted (cascade)
      final tasks = await taskRepo.getTasksByUser(userId);
      expect(tasks.isEmpty, isTrue);

      final bigTasks = await bigTaskRepo.getBigTasksByUser(userId);
      expect(bigTasks.isEmpty, isTrue);
    });
  });
}
