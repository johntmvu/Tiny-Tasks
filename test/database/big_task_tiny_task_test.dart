import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tinytasks/database/sqlite_helper.dart';
import 'package:tinytasks/models/user.dart';
import 'package:tinytasks/models/big_task.dart';
import 'package:tinytasks/models/tiny_task.dart';

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
        priority: 'High',
      );

      final id = await dbHelper.insertBigTask(bigTask);
      expect(id, greaterThan(0));
    });

    test('Get big tasks by user should return all big tasks', () async {
      final bigTask1 = BigTask(userId: testUserId, title: 'Big Task 1');
      final bigTask2 = BigTask(userId: testUserId, title: 'Big Task 2');

      await dbHelper.insertBigTask(bigTask1);
      await dbHelper.insertBigTask(bigTask2);

      final bigTasks = await dbHelper.getBigTasksByUser(testUserId);
      expect(bigTasks.length, equals(2));
    });

    test('Delete big task should cascade delete tiny tasks', () async {
      final bigTask = BigTask(userId: testUserId, title: 'Big Task');
      final bigTaskId = await dbHelper.insertBigTask(bigTask);

      final tinyTask1 = TinyTask(parentBigTaskId: bigTaskId, title: 'Tiny 1');
      final tinyTask2 = TinyTask(parentBigTaskId: bigTaskId, title: 'Tiny 2');
      await dbHelper.insertTinyTask(tinyTask1);
      await dbHelper.insertTinyTask(tinyTask2);

      await dbHelper.deleteBigTask(bigTaskId);

      final tinyTasks = await dbHelper.getTinyTasksByBigTask(bigTaskId);
      expect(tinyTasks.isEmpty, isTrue);
    });
  });

  group('TinyTask CRUD Operations', () {
    late int testBigTaskId;

    setUp(() async {
      final bigTask = BigTask(
        userId: testUserId,
        title: 'Test Big Task',
      );
      testBigTaskId = await dbHelper.insertBigTask(bigTask);
    });

    test('Insert tiny task should return valid ID', () async {
      final tinyTask = TinyTask(
        parentBigTaskId: testBigTaskId,
        title: 'Research topic',
      );

      final id = await dbHelper.insertTinyTask(tinyTask);
      expect(id, greaterThan(0));
    });

    test('Get tiny tasks by big task should return all related tiny tasks', () async {
      final tinyTask1 = TinyTask(parentBigTaskId: testBigTaskId, title: 'Step 1');
      final tinyTask2 = TinyTask(parentBigTaskId: testBigTaskId, title: 'Step 2');
      final tinyTask3 = TinyTask(parentBigTaskId: testBigTaskId, title: 'Step 3');

      await dbHelper.insertTinyTask(tinyTask1);
      await dbHelper.insertTinyTask(tinyTask2);
      await dbHelper.insertTinyTask(tinyTask3);

      final tinyTasks = await dbHelper.getTinyTasksByBigTask(testBigTaskId);
      expect(tinyTasks.length, equals(3));
    });

    test('Update tiny task completion status', () async {
      final tinyTask = TinyTask(
        parentBigTaskId: testBigTaskId,
        title: 'Complete reading',
        isCompleted: false,
      );

      final id = await dbHelper.insertTinyTask(tinyTask);
      final updatedTask = tinyTask.copyWith(
        tinyTaskId: id,
        isCompleted: true,
      );

      await dbHelper.updateTinyTask(updatedTask);
      final retrieved = await dbHelper.getTinyTask(id);

      expect(retrieved!.isCompleted, isTrue);
    });

    test('Delete tiny task should not affect big task', () async {
      final tinyTask = TinyTask(
        parentBigTaskId: testBigTaskId,
        title: 'Deletable task',
      );

      final id = await dbHelper.insertTinyTask(tinyTask);
      await dbHelper.deleteTinyTask(id);

      final bigTask = await dbHelper.getBigTask(testBigTaskId);
      expect(bigTask, isNotNull);
    });
  });
}
