import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/task_view.dart';
import 'repositories/user_repository.dart';
import 'repositories/task_repository.dart';
import 'models/user.dart' as user_models;
import 'services/google_auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _userRepository = UserRepository();
  final _taskRepository = TaskRepository();

  String _errorMessage = "";
  bool _isLoading = false;

  Future<void> signUp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      final newUser = user_models.User(
        name: _emailController.text.trim().split('@')[0],
        email: _emailController.text.trim(),
      );

      final userId = await _userRepository.createUser(newUser);

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TaskView(
            userId: userId,
            firebaseUserId: credential.user!.uid,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
        setState(() {
          _errorMessage = "FirebaseAuthException: ${e.code} | ${e.message}";
      });
      debugPrint("FirebaseAuthException: ${e.code} | ${e.message}");
    } catch (e) {
      setState(() {
        _errorMessage = "Error: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> signIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final firebaseUid = FirebaseAuth.instance.currentUser!.uid;

      final user = await _userRepository.getUserByEmail(
        _emailController.text.trim(),
      );

      if (user == null) {
        final newUser = user_models.User(
          name: _emailController.text.trim().split('@')[0],
          email: _emailController.text.trim(),
        );

        final userId = await _userRepository.createUser(newUser);

        await _taskRepository.syncFromFirestore(firebaseUid, userId);

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TaskView(
              userId: userId,
              firebaseUserId: firebaseUid,
            ),
          ),
        );
      } else {
        await _taskRepository.syncFromFirestore(firebaseUid, user.userId!);

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TaskView(
              userId: user.userId!,
              firebaseUserId: firebaseUid,
            ),
          ),
        );
      }
  } on FirebaseAuthException catch (e) {
    setState(() {
      _errorMessage = "FirebaseAuthException: ${e.code} | ${e.message}";
    });
    debugPrint("FirebaseAuthException: ${e.code} | ${e.message}");
  } catch (e) {
      setState(() {
        _errorMessage = "Error: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
  setState(() {
    _isLoading = true;
    _errorMessage = "";
  });

  try {
    final result = await GoogleAuthService().signInWithGoogle();

    if (result == null) return;

    final user = result['user'];
    final accessToken = result['accessToken'];

    if (user == null) return;

    final firebaseUid = user.uid;

    final existingUser = await _userRepository.getUserByEmail(
      user.email ?? "",
    );

    int userId;

    if (existingUser == null) {
      final newUser = user_models.User(
        name: user.displayName ?? "User",
        email: user.email ?? "",
      );

      userId = await _userRepository.createUser(newUser);
    } else {
      userId = existingUser.userId!;
    }

    await _taskRepository.syncFromFirestore(firebaseUid, userId);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TaskView(
          userId: userId,
          firebaseUserId: firebaseUid,
          accessToken: accessToken,
        ),
      ),
    );
  } catch (e) {
    setState(() {
      _errorMessage = "Google Sign-In failed: $e";
    });
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF8ECFD8), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFDFEFE),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7EEF2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.checklist_rounded,
                    size: 36,
                    color: Color(0xFF1E5A67),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  "Tiny Tasks",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Sign in to manage your day better",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration("Email", Icons.email_outlined),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: _inputDecoration("Password", Icons.lock_outline),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : signIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD7EEF2),
                      foregroundColor: const Color(0xFF1E5A67),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            "Sign In",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _isLoading ? null : signUp,
                  child: const Text(
                    "Create Account",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      "Sign in with Google",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}