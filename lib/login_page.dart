import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/task_view.dart';
import 'repositories/user_repository.dart';
import 'repositories/task_repository.dart';
import 'repositories/big_task_repository.dart';
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
  final _bigTaskRepository = BigTaskRepository();
  final _googleAuthService = GoogleAuthService();

  String _errorMessage = "";
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      if (mounted) {
        setState(() {
          _isCheckingSession = false;
        });
      }
      return;
    }

    try {
      String? accessToken;
      final isGoogleUser = currentUser.providerData.any(
        (provider) => provider.providerId == 'google.com',
      );

      if (isGoogleUser) {
        accessToken = await _googleAuthService.getAccessTokenSilently();
      }

      await _completeSignIn(user: currentUser, accessToken: accessToken);
    } catch (e) {
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        setState(() {
          _errorMessage =
              "Couldn't restore your session. Please sign in again.";
          _isCheckingSession = false;
        });
      }
    }
  }

  Future<void> _completeSignIn({
    required User user,
    String? accessToken,
  }) async {
    final firebaseUid = user.uid;
    final email = user.email ?? "";

    final existingUser = await _userRepository.getUserByEmail(email);

    int userId;

    if (existingUser == null) {
      final newUser = user_models.User(
        name: user.displayName ?? email.split('@').first,
        email: email,
      );

      userId = await _userRepository.createUser(newUser);
    } else {
      userId = existingUser.userId!;
    }

    await _bigTaskRepository.syncFromFirestore(firebaseUid, userId);
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
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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
      await _completeSignIn(user: credential.user!);
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
      await _completeSignIn(user: FirebaseAuth.instance.currentUser!);
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
      _isGoogleLoading = true;
      _errorMessage = "";
    });

    try {
      final result = await _googleAuthService.signInWithGoogle();

      if (result == null) return;

      final user = result['user'] as User?;
      final accessToken = result['accessToken'] as String?;

      if (user == null) return;
      await _completeSignIn(user: user, accessToken: accessToken);
    } catch (e) {
      setState(() {
        _errorMessage =
            "Google sign-in succeeded, but app data sync failed: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration(
    BuildContext context,
    String label,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
      prefixIcon: Icon(icon, color: isDark ? Colors.white70 : Colors.black54),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF8ECFD8), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
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
                Text(
                  "Tiny Tasks",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Sign in to manage your day better",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: _inputDecoration(
                    context,
                    "Email",
                    Icons.email_outlined,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: _inputDecoration(
                    context,
                    "Password",
                    Icons.lock_outline,
                  ),
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
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isGoogleLoading ? null : _signInWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? const Color(0xFF1E1E2E)
                          : Colors.white,
                      foregroundColor: theme.colorScheme.onSurface,
                      elevation: 0,
                      side: BorderSide(
                        color: isDark
                            ? Colors.white24
                            : const Color(0xFFE2E8F0),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      "Sign in with Google",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF3A1B1B)
                          : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(
                        color: Colors.redAccent,
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
