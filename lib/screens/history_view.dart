import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/sqlite_helper.dart';
import '../repositories/task_repository.dart';
import '../models/task.dart';

class HistoryView extends StatefulWidget {
  final int userId;
  final String? firebaseUserId;

  const HistoryView({super.key, required this.userId, this.firebaseUserId});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  final TaskRepository _taskRepository = TaskRepository();
  List<String> _sortedDates = [];
  Map<String, List<Task>> _tasksByDate = {};
  String _userInitial = '?';
  bool _isLoading = true;
  final Set<int> _recentlyUnchecked = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = SQLiteHelper.instance;

    final user = await db.getUser(widget.userId);
    final allTasks = await db.getTasksByUser(widget.userId);
    final completed = allTasks.where((t) => t.isCompleted).toList();

    final grouped = <String, List<Task>>{};
    for (final task in completed) {
      grouped.putIfAbsent(task.date, () => []).add(task);
    }

    final sorted = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    setState(() {
      _userInitial =
          (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : '?';
      _tasksByDate = grouped;
      _sortedDates = sorted;
      _isLoading = false;
    });
  }

  Future<void> _uncheckTask(Task task) async {
    try {
      await _taskRepository.updateTask(
        task.copyWith(isCompleted: false),
        firebaseUserId: widget.firebaseUserId,
      );
      if (task.id != null) {
        setState(() => _recentlyUnchecked.add(task.id!));
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _recentlyUnchecked.remove(task.id!);
              for (final key in _tasksByDate.keys) {
                _tasksByDate[key]!.removeWhere((t) => t.id == task.id);
              }
              _sortedDates.removeWhere((d) => _tasksByDate[d]!.isEmpty);
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error unchecking task: $e');
    }
  }

  Future<void> _redoTask(Task task) async {
    try {
      await _taskRepository.updateTask(
        task.copyWith(isCompleted: true),
        firebaseUserId: widget.firebaseUserId,
      );
      if (task.id != null) {
        setState(() => _recentlyUnchecked.remove(task.id!));
      }
    } catch (e) {
      debugPrint('Error re-checking task: $e');
    }
  }

  String _dateHeader(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = todayDate.difference(d).inDays;

    final monthDay = DateFormat('MMM d').format(date);
    final weekday = DateFormat('EEEE').format(date);

    if (diff == 0) return '$monthDay · Today · $weekday';
    if (diff == 1) return '$monthDay · Yesterday · $weekday';
    return '$monthDay · $weekday';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'History',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sortedDates.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 68,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No completed tasks yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _sortedDates.length,
                  itemBuilder: (context, i) {
                    final date = _sortedDates[i];
                    final tasks = _tasksByDate[date]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                          child: Text(
                            _dateHeader(date),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurfaceVariant,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        ...tasks.map((task) => _buildTaskRow(task, theme, isDark)),
                      ],
                    );
                  },
                ),
    );
  }

  Widget _buildTaskRow(Task task, ThemeData theme, bool isDark) {
    final isUnchecked = task.id != null && _recentlyUnchecked.contains(task.id!);

    if (isUnchecked) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF3A3118) : const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.radio_button_unchecked_rounded,
              color: Color(0xFFFFA000),
              size: 22,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Task unchecked',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFFCC80),
                ),
              ),
            ),
            TextButton(
              onPressed: () => _redoTask(task),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6EC6D9),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text(
                'Undo',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => _uncheckTask(task),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFD7EEF2),
              child: Text(
                _userInitial,
                style: const TextStyle(
                  color: Color(0xFF1E5A67),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'You completed ',
                          style: TextStyle(
                            fontSize: 15,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        TextSpan(
                          text: task.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (task.time.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.time,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF81C784),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}