import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'screens/task_view.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
=======
import 'screens/login_screen.dart';

void main() {
  runApp(const TinyTasksApp());
}

class TinyTasksApp extends StatelessWidget {
  const TinyTasksApp({super.key});
>>>>>>> 134572b (Sprint 1: login screen + basic task add UI)

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
<<<<<<< HEAD
      title: 'Tiny Tasks',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 255, 255, 255),
        ),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      //home: const TaskView(),
      home: LoginPage(),

=======
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
>>>>>>> 134572b (Sprint 1: login screen + basic task add UI)
    );
  }
}