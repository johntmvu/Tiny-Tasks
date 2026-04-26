import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../login_page.dart';
import '../repositories/big_task_repository.dart';
import '../services/google_auth_service.dart';

class ProfileView extends StatefulWidget {
  final int? userId;
  final String? firebaseUserId;

  const ProfileView({super.key, this.userId, this.firebaseUserId});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _bigTaskRepository = BigTaskRepository();
  int _activeBigTaskCount = 0;
  static const int _bigTaskLimit = 3;

  @override
  void initState() {
    super.initState();
    _loadActiveBigTaskCount();
  }

  Future<void> _loadActiveBigTaskCount() async {
    if (widget.userId == null) return;
    final bigTasks = await _bigTaskRepository.getBigTasksByUser(widget.userId!);
    if (mounted) {
      setState(() {
        _activeBigTaskCount = bigTasks.where((t) => !t.isCompleted).length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final progressFraction = _activeBigTaskCount / _bigTaskLimit;

    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 45,
                child: Icon(Icons.person, size: 50),
              ),
              const SizedBox(height: 16),

              Text(
                user?.email ?? "No email",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                "UID: ${user?.uid ?? "N/A"}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 30),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Active Big Tasks',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$_activeBigTaskCount / $_bigTaskLimit',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _activeBigTaskCount >= _bigTaskLimit
                                ? Colors.orange
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progressFraction.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _activeBigTaskCount >= _bigTaskLimit
                              ? Colors.orange
                              : const Color(0xFF1E5A67),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _activeBigTaskCount >= _bigTaskLimit
                          ? 'Limit reached — complete a big task to add another.'
                          : '${_bigTaskLimit - _activeBigTaskCount} slot${_bigTaskLimit - _activeBigTaskCount == 1 ? '' : 's'} remaining.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text("Sign Out"),
                onPressed: () async {
                  await GoogleAuthService().signOut();
                  if (!context.mounted) return;

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
