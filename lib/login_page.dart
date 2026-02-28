import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/task_view.dart';
import 'repositories/user_repository.dart';
import 'models/user.dart' as user_models;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _errorMessage = "";
  final _userRepository = UserRepository();

  Future<void> signUp() async {
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      // Create user record in SQLite
      final newUser = user_models.User(
        name: _emailController.text.trim().split('@')[0], // Use email prefix as name
        email: _emailController.text.trim(),
      );
      final userId = await _userRepository.createUser(newUser);
      
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TaskView(userId: userId),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? "Signup failed";
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error: $e";
      });
    }
  }

  Future<void> signIn() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      // Get user from SQLite by email
      final user = await _userRepository.getUserByEmail(_emailController.text.trim());
      if (user == null) {
        // User doesn't exist in SQLite, create it
        final newUser = user_models.User(
          name: _emailController.text.trim().split('@')[0],
          email: _emailController.text.trim(),
        );
        final userId = await _userRepository.createUser(newUser);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TaskView(userId: userId),
          ),
        );
      } else {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TaskView(userId: user.userId!),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? "Login failed";
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Sign In",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              //Sign in button
              ElevatedButton(
                onPressed: signIn,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text("Sign In"),
              ),
              //Create account button
              TextButton(
                onPressed: signUp,
                child: const Text("Create Account"),
              ),

              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}