import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tinytasks/database/sqlite_helper.dart';
import 'package:tinytasks/models/user.dart';

void main() {
  late SQLiteHelper dbHelper;

  setUpAll(() {
    // Initialize FFI for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbHelper = await SQLiteHelper.createInMemory();
  });

  tearDown(() async {
    await dbHelper.close();
  });

  group('User CRUD Operations', () {
    test('Insert user should return valid ID', () async {
      final user = User(
        name: 'John Doe',
        email: 'john@example.com',
        googleId: 'google123',
      );

      final id = await dbHelper.insertUser(user);
      expect(id, greaterThan(0));
    });

    test('Get user by ID should return correct user', () async {
      final user = User(
        name: 'Jane Smith',
        email: 'jane@example.com',
      );

      final id = await dbHelper.insertUser(user);
      final retrievedUser = await dbHelper.getUser(id);

      expect(retrievedUser, isNotNull);
      expect(retrievedUser!.name, equals('Jane Smith'));
      expect(retrievedUser.email, equals('jane@example.com'));
    });

    test('Get user by email should return correct user', () async {
      final user = User(
        name: 'Bob Johnson',
        email: 'bob@example.com',
      );

      await dbHelper.insertUser(user);
      final retrievedUser = await dbHelper.getUserByEmail('bob@example.com');

      expect(retrievedUser, isNotNull);
      expect(retrievedUser!.name, equals('Bob Johnson'));
    });

    test('Update user should modify existing user', () async {
      final user = User(
        name: 'Alice Brown',
        email: 'alice@example.com',
      );

      final id = await dbHelper.insertUser(user);
      final updatedUser = user.copyWith(
        userId: id,
        name: 'Alice Green',
      );

      final rowsAffected = await dbHelper.updateUser(updatedUser);
      expect(rowsAffected, equals(1));

      final retrievedUser = await dbHelper.getUser(id);
      expect(retrievedUser!.name, equals('Alice Green'));
    });

    test('Delete user should remove user from database', () async {
      final user = User(
        name: 'Tom Wilson',
        email: 'tom@example.com',
      );

      final id = await dbHelper.insertUser(user);
      final rowsAffected = await dbHelper.deleteUser(id);
      expect(rowsAffected, equals(1));

      final retrievedUser = await dbHelper.getUser(id);
      expect(retrievedUser, isNull);
    });

    test('Insert duplicate email should fail', () async {
      final user1 = User(
        name: 'User One',
        email: 'duplicate@example.com',
      );
      final user2 = User(
        name: 'User Two',
        email: 'duplicate@example.com',
      );

      await dbHelper.insertUser(user1);
      
      expect(
        () async => await dbHelper.insertUser(user2),
        throwsException,
      );
    });
  });
}
