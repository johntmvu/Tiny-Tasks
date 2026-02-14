import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const TinyTasksApp());
}

class TinyTasksApp extends StatelessWidget {
  const TinyTasksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}