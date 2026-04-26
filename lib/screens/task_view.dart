import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/task.dart';
import '../models/big_task.dart';
import '../repositories/task_repository.dart';
import '../repositories/big_task_repository.dart';
import '../services/gemini_service.dart';
import '../widgets/task_tile.dart';
import '../widgets/big_task_tile.dart';
import 'settings_view.dart';
import 'history_view.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../services/google_calendar_service.dart';
import '../services/google_auth_service.dart';

const _kAccentBg = Color(0xFFD7EEF2);
const _kAccentFg = Color(0xFF1E5A67);

class TaskView extends StatefulWidget {
  final int? userId;
  final String? firebaseUserId;
  final String? accessToken;

  const TaskView({
    super.key,
    this.userId,
    this.firebaseUserId,
    this.accessToken,
  });

  @override
  State<TaskView> createState() => _TaskViewState();
}

class _TaskViewState extends State<TaskView> {
  final TaskRepository _taskRepository = TaskRepository();
  final BigTaskRepository _bigTaskRepository = BigTaskRepository();
  final GoogleAuthService _googleAuthService = GoogleAuthService();

  DateTime _selectedDate = DateTime.now();
  List<Task> _tasks = [];
  bool _isLoading = true;
  String _selectedPeriod = 'full';
  bool _showBigTasks = false;
  List<BigTask> _bigTasks = [];
  Map<int, List<Task>> _tinyTasksByBigTask = {};
  bool _isLoadingBigTasks = false;
  final Set<int> _recentlyCompleted = {};
  final List<({Task task, int index})> _recentlyDeleted = [];
  Set<DateTime> _taskDates = {};

  @override
  void initState() {
    super.initState();
    _rescheduleOverdueTasks().then((_) {
      _loadTasks();
      _loadBigTasks();
      _loadTaskDates();
    });
  }

  Future<void> _loadTaskDates() async {
    if (widget.userId == null) return;
    final dateStrings = await _taskRepository.getTaskDatesForUser(
      widget.userId!,
    );
    if (mounted) {
      setState(() {
        _taskDates = dateStrings.map((s) {
          final parts = s.split('-');
          return DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        }).toSet();
      });
    }
  }

  String get _formattedDate =>
      DateFormat('EEE, MMM d, y').format(_selectedDate);
  String get _dateKey => DateFormat('yyyy-MM-dd').format(_selectedDate);

  Future<String?> _resolveCalendarAccessToken() async {
    if (widget.accessToken == null) return null;
    final refreshedToken = await _googleAuthService.getAccessTokenSilently();
    return refreshedToken ?? widget.accessToken;
  }

  Future<void> _syncTaskToGoogleCalendar(Task task) async {
    final accessToken = await _resolveCalendarAccessToken();
    if (accessToken == null) return;

    try {
      await GoogleCalendarService().createEvent(
        accessToken: accessToken,
        title: task.title,
        date: task.date,
      );
    } catch (e) {
      debugPrint('Calendar sync failed: $e');
    }
  }

  List<Task> get _filteredTasks {
    if (_selectedPeriod == 'full') {
      return _tasks;
    }
    return _tasks.where((task) => task.period == _selectedPeriod).toList();
  }

  Color get _surfaceColor => Theme.of(context).colorScheme.surface;
  Color get _onSurfaceColor => Theme.of(context).colorScheme.onSurface;
  Color get _mutedTextColor => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get _cardColor => Theme.of(context).cardColor;
  Color get _softSurfaceColor =>
      Theme.of(context).colorScheme.surfaceContainerHighest;
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Future<void> _loadTasks() async {
    if (widget.userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final dateTasks = await _taskRepository.getTasksByUserAndDate(
        widget.userId!,
        _dateKey,
      );

      setState(() {
        _tasks = dateTasks;
      });
      _loadTaskDates();
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load tasks: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addTask(Task task) async {
    try {
      await _taskRepository.createTask(
        task,
        firebaseUserId: widget.firebaseUserId,
      );

      await _syncTaskToGoogleCalendar(task);

      await _loadTasks();
    } catch (e) {
      debugPrint('Error adding task: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add task: $e')));
      }
    }
  }

  Future<void> _deleteTask(Task task, int displayIndex) async {
    if (task.id == null) return;
    final taskId = task.id!;
    try {
      await _taskRepository.deleteTask(
        taskId,
        firebaseUserId: widget.firebaseUserId,
      );
      if (mounted) {
        setState(() => _recentlyDeleted.add((task: task, index: displayIndex)));
        await _loadTasks();
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(
              () => _recentlyDeleted.removeWhere((e) => e.task.id == taskId),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error deleting task: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete task: $e')));
      }
    }
  }

  Future<void> _undoDeleteTask(Task task) async {
    setState(() => _recentlyDeleted.removeWhere((e) => e.task.id == task.id));
    try {
      await _taskRepository.createTask(
        Task(
          userId: task.userId,
          firebaseUserId: task.firebaseUserId,
          title: task.title,
          description: task.description,
          date: task.date,
          time: task.time,
          isCompleted: task.isCompleted,
          createdAt: task.createdAt,
          period: task.period,
          bigTaskId: task.bigTaskId,
          isRescheduled: task.isRescheduled,
        ),
        firebaseUserId: widget.firebaseUserId,
      );
      await _loadTasks();
    } catch (e) {
      debugPrint('Error restoring task: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to restore task: $e')));
      }
    }
  }

  Future<void> _editTask(Task task) async {
    try {
      await _taskRepository.updateTask(
        task,
        firebaseUserId: widget.firebaseUserId,
      );
      await _loadTasks();
    } catch (e) {
      debugPrint('Error editing task: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update task: $e')));
      }
    }
  }

  void _showEditTaskDialog(Task task) {
    final titleController = TextEditingController(text: task.title);
    final descriptionController = TextEditingController(
      text: task.description ?? '',
    );
    String selectedTaskPeriod = task.period;
    TimeOfDay? selectedTime = _parseTimeOfDay(task.time);
    bool reminderEnabled = task.reminderEnabled;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Edit Task',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Task Title',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setModalState(() {
                            selectedTime = picked;
                            selectedTaskPeriod = picked.hour < 12 ? 'am' : 'pm';
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 20,
                              color: _mutedTextColor,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              selectedTime != null
                                  ? selectedTime!.format(context)
                                  : 'Time (optional)',
                              style: TextStyle(
                                fontSize: 16,
                                color: selectedTime != null
                                    ? _onSurfaceColor
                                    : _mutedTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedTaskPeriod,
                      decoration: InputDecoration(
                        labelText: 'Time Slot',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'full',
                          child: Text('Full Day'),
                        ),
                        DropdownMenuItem(value: 'am', child: Text('AM')),
                        DropdownMenuItem(value: 'pm', child: Text('PM')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() => selectedTaskPeriod = value);
                        }
                      },
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Remind me'),
                      subtitle: selectedTime == null
                          ? const Text(
                              'Set a time above to enable',
                              style: TextStyle(fontSize: 12),
                            )
                          : null,
                      secondary: const Icon(Icons.notifications_outlined),
                      value: reminderEnabled,
                      onChanged: selectedTime == null
                          ? null
                          : (val) =>
                              setModalState(() => reminderEnabled = val),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccentBg,
                foregroundColor: _kAccentFg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                Navigator.pop(context);
                await _editTask(
                  task.copyWith(
                    title: title,
                    description: descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                    time: selectedTime != null
                        ? selectedTime!.format(context)
                        : '',
                    period: selectedTaskPeriod,
                    reminderEnabled:
                        reminderEnabled && selectedTime != null,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleTask(Task task, bool value) async {
    try {
      final updatedTask = task.copyWith(isCompleted: value);
      await _taskRepository.updateTask(
        updatedTask,
        firebaseUserId: widget.firebaseUserId,
      );

      if (value && task.id != null) {
        setState(() => _recentlyCompleted.add(task.id!));
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _recentlyCompleted.remove(task.id!));
        });
      } else if (!value && task.id != null) {
        setState(() => _recentlyCompleted.remove(task.id!));
      }

      await _loadTasks();
      if (value && task.bigTaskId != null) {
        await _checkAndAutoCompleteBigTask(task.bigTaskId!);
      }
    } catch (e) {
      debugPrint('Error updating task: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update task: $e')));
      }
    }
  }

  Future<void> _checkAndAutoCompleteBigTask(int bigTaskId) async {
    final tinyTasks = await _bigTaskRepository.getTinyTasksForBigTask(bigTaskId);
    if (tinyTasks.isEmpty) return;
    if (!tinyTasks.every((t) => t.isCompleted)) return;

    final bigTask = await _bigTaskRepository.getBigTaskById(bigTaskId);
    if (bigTask == null || bigTask.isCompleted) return;

    await _bigTaskRepository.updateBigTask(
      bigTask.copyWith(isCompleted: true),
      firebaseUserId: widget.firebaseUserId,
    );
    await _loadBigTasks();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${bigTask.title}" completed! Slot freed up.')),
      );
    }
  }

  TimeOfDay? _parseTimeOfDay(String timeStr) {
    if (timeStr.isEmpty) return null;
    final amPm = RegExp(
      r'(\d{1,2}):(\d{2})\s*(AM|PM)',
      caseSensitive: false,
    ).firstMatch(timeStr);
    if (amPm != null) {
      int hour = int.parse(amPm.group(1)!);
      final minute = int.parse(amPm.group(2)!);
      final isPm = amPm.group(3)!.toUpperCase() == 'PM';
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    }
    final h24 = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(timeStr);
    if (h24 != null) {
      return TimeOfDay(
        hour: int.parse(h24.group(1)!),
        minute: int.parse(h24.group(2)!),
      );
    }
    return null;
  }

  Future<void> _rescheduleOverdueTasks() async {
    if (widget.userId == null) return;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      final allTasks = await _taskRepository.getTasksByUser(widget.userId!);
      for (final task in allTasks) {
        if (!task.isCompleted &&
            task.date.isNotEmpty &&
            task.date.compareTo(today) < 0) {
          await _taskRepository.updateTask(
            task.copyWith(date: today, isRescheduled: true),
            firebaseUserId: widget.firebaseUserId,
          );
        }
      }
    } catch (e) {
      debugPrint('Error rescheduling overdue tasks: $e');
    }
  }

  Future<void> _loadBigTasks() async {
    if (widget.userId == null) return;

    setState(() {
      _isLoadingBigTasks = true;
    });

    try {
      final bigTasks = await _bigTaskRepository.getBigTasksByUser(
        widget.userId!,
      );
      final tinyTasksMap = <int, List<Task>>{};
      for (final bigTask in bigTasks) {
        if (bigTask.id != null) {
          tinyTasksMap[bigTask.id!] = await _bigTaskRepository
              .getTinyTasksForBigTask(bigTask.id!);
        }
      }
      setState(() {
        _bigTasks = bigTasks;
        _tinyTasksByBigTask = tinyTasksMap;
      });
    } catch (e) {
      debugPrint('Error loading big tasks: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load big tasks: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBigTasks = false;
        });
      }
    }
  }

  Future<void> _deleteBigTask(BigTask bigTask) async {
    try {
      if (bigTask.id != null) {
        await _bigTaskRepository.deleteBigTask(
          bigTask.id!,
          firebaseUserId: widget.firebaseUserId,
        );
        await _loadBigTasks();
      }
    } catch (e) {
      debugPrint('Error deleting big task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete big task: $e')),
        );
      }
    }
  }

  void _showEditBigTaskDialog(BigTask bigTask) {
    final titleController = TextEditingController(text: bigTask.title);
    final descriptionController = TextEditingController(
      text: bigTask.description ?? '',
    );
    String selectedPriority = bigTask.priority;
    String selectedDueDate = bigTask.dueDate;
    String selectedColor = bigTask.color;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Edit Big Task',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe your task',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPriority,
                      decoration: InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() => selectedPriority = value);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () async {
                        final now = DateTime.now();
                        final initial =
                            DateTime.tryParse(selectedDueDate) ??
                            now.add(const Duration(days: 1));
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initial.isBefore(now)
                              ? now.add(const Duration(days: 1))
                              : initial,
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setModalState(() {
                            selectedDueDate = DateFormat(
                              'yyyy-MM-dd',
                            ).format(picked);
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'Due: $selectedDueDate',
                          style: TextStyle(
                            fontSize: 16,
                            color: _onSurfaceColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Color',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _onSurfaceColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: bigTaskColors.entries.map((entry) {
                        final isSelected = selectedColor == entry.key;
                        return GestureDetector(
                          onTap: () =>
                              setModalState(() => selectedColor = entry.key),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: entry.value,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: _onSurfaceColor, width: 2)
                                  : null,
                            ),
                            child: isSelected
                                ? Icon(
                                    Icons.check,
                                    size: 18,
                                    color: _onSurfaceColor,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccentBg,
                foregroundColor: _kAccentFg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                Navigator.pop(dialogContext);
                final scaffoldMessenger = ScaffoldMessenger.of(dialogContext);
                try {
                  await _bigTaskRepository.updateBigTask(
                    bigTask.copyWith(
                      title: title,
                      description: descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      priority: selectedPriority,
                      dueDate: selectedDueDate,
                      color: selectedColor,
                    ),
                    firebaseUserId: widget.firebaseUserId,
                  );
                  await _loadBigTasks();
                } catch (e) {
                  debugPrint('Error updating big task: $e');
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Failed to update big task: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showEditTinyTaskDialog(Task task) {
    final titleController = TextEditingController(text: task.title);
    String selectedDate = task.date;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Edit Subtask',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () async {
                      final now = DateTime.now();
                      final initial = DateTime.tryParse(selectedDate) ?? now;
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: initial.isBefore(now) ? now : initial,
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setModalState(() {
                          selectedDate = DateFormat(
                            'yyyy-MM-dd',
                          ).format(picked);
                        });
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Date: $selectedDate',
                        style: TextStyle(fontSize: 16, color: _onSurfaceColor),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccentBg,
                foregroundColor: _kAccentFg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                Navigator.pop(context);
                await _editTask(
                  task.copyWith(title: title, date: selectedDate),
                );
                await _loadBigTasks();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  static const int _bigTaskLimit = 3;

  void _showAddBigTaskDialog() {
    final activeBigTasks = _bigTasks.where((t) => !t.isCompleted).length;
    if (activeBigTasks >= _bigTaskLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete a big task to add a new one (limit: 3 active).',
          ),
        ),
      );
      return;
    }

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedPriority = 'medium';
    String? selectedDueDate;
    String selectedColor = 'blue';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Add Big Task',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPriority,
                      decoration: InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() => selectedPriority = value);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: now.add(const Duration(days: 1)),
                          firstDate: now.add(const Duration(days: 1)),
                          lastDate: now.add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setModalState(() {
                            selectedDueDate = DateFormat(
                              'yyyy-MM-dd',
                            ).format(picked);
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          selectedDueDate != null
                              ? 'Due: $selectedDueDate'
                              : 'Select due date',
                          style: TextStyle(
                            color: selectedDueDate != null
                                ? _onSurfaceColor
                                : _mutedTextColor,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Color',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _onSurfaceColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: bigTaskColors.entries.map((entry) {
                        final isSelected = selectedColor == entry.key;
                        return GestureDetector(
                          onTap: () =>
                              setModalState(() => selectedColor = entry.key),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: entry.value,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: _onSurfaceColor, width: 2)
                                  : null,
                            ),
                            child: isSelected
                                ? Icon(
                                    Icons.check,
                                    size: 18,
                                    color: _onSurfaceColor,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccentBg,
                foregroundColor: _kAccentFg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () {
                final title = titleController.text.trim();
                final description = descriptionController.text.trim();
                if (title.isEmpty ||
                    description.isEmpty ||
                    selectedDueDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Title, description, and due date are required.',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(context);
                _createBigTaskWithDecomposition(
                  title: title,
                  description: description,
                  priority: selectedPriority,
                  dueDate: selectedDueDate!,
                  color: selectedColor,
                );
              },
              child: const Text('Create & Decompose'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createBigTaskWithDecomposition({
    required String title,
    required String description,
    required String priority,
    required String dueDate,
    required String color,
  }) async {
    if (widget.userId == null) return;

    final bigTask = BigTask(
      userId: widget.userId,
      firebaseUserId: widget.firebaseUserId,
      title: title,
      description: description,
      priority: priority,
      dueDate: dueDate,
      color: color,
    );

    int bigTaskId;
    try {
      bigTaskId = await _bigTaskRepository.createBigTask(
        bigTask,
        firebaseUserId: widget.firebaseUserId,
      );
    } catch (e) {
      debugPrint('Error creating big task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create big task: $e')),
        );
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Decomposing with AI…'),
          ],
        ),
      ),
    );

    List<Map<String, String>> subtasks;
    try {
      subtasks = await GeminiService.instance.decomposeBigTask(
        title: title,
        description: description,
        priority: priority,
        startDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        dueDate: dueDate,
      );
    } catch (e) {
      debugPrint('Gemini error: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'AI decomposition failed. Big task was saved without subtasks.',
            ),
          ),
        );
      }
      await _loadBigTasks();
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);

    await _showDecompositionConfirmDialog(
      subtasks: subtasks,
      bigTaskId: bigTaskId,
      dueDate: dueDate,
    );
    await _loadBigTasks();
  }

  Future<void> _showDecompositionConfirmDialog({
    required List<Map<String, String>> subtasks,
    required int bigTaskId,
    required String dueDate,
  }) async {
    final checked = List<bool>.filled(subtasks.length, true);
    final dates = subtasks.map((s) => s['date'] ?? _dateKey).toList();
    final today = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Review Subtasks',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: StatefulBuilder(
            builder: (context, setModalState) {
              return SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(subtasks.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Checkbox(
                              value: checked[i],
                              onChanged: (v) =>
                                  setModalState(() => checked[i] = v ?? false),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                subtasks[i]['title'] ?? '',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                final dueParsed =
                                    DateTime.tryParse(dueDate) ??
                                    today.add(const Duration(days: 7));
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      DateTime.tryParse(dates[i]) ?? today,
                                  firstDate: today,
                                  lastDate: dueParsed,
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    dates[i] = DateFormat(
                                      'yyyy-MM-dd',
                                    ).format(picked);
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _kAccentBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  dates[i],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _kAccentFg,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Discard All'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccentBg,
                foregroundColor: _kAccentFg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(context);
                _saveDecomposedTasks(
                  subtasks: subtasks,
                  checked: checked,
                  dates: dates,
                  bigTaskId: bigTaskId,
                );
              },
              child: const Text('Add Selected'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveDecomposedTasks({
    required List<Map<String, String>> subtasks,
    required List<bool> checked,
    required List<String> dates,
    required int bigTaskId,
  }) async {
    try {
      for (int i = 0; i < subtasks.length; i++) {
        if (!checked[i]) continue;
        final task = Task(
          userId: widget.userId,
          firebaseUserId: widget.firebaseUserId,
          title: subtasks[i]['title'] ?? '',
          date: dates[i],
          period: 'full',
          bigTaskId: bigTaskId,
        );

        await _taskRepository.createTask(
          task,
          firebaseUserId: widget.firebaseUserId,
        );

        await _syncTaskToGoogleCalendar(task);
      }
      await _loadTasks();
    } catch (e) {
      debugPrint('Error saving subtask: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save subtasks: $e')));
      }
    }
  }

  Widget _buildBigTaskList() {
    if (_isLoadingBigTasks) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }

    if (_bigTasks.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.rocket_launch_rounded,
                size: 68,
                color: _mutedTextColor,
              ),
              const SizedBox(height: 12),
              Text(
                'No big tasks yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _mutedTextColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Tap 'Add Big Task' to create one.",
                style: TextStyle(fontSize: 14, color: _mutedTextColor),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 88),
        itemCount: _bigTasks.length,
        itemBuilder: (context, index) {
          final bigTask = _bigTasks[index];
          return BigTaskTile(
            bigTask: bigTask,
            tinyTasks: _tinyTasksByBigTask[bigTask.id] ?? [],
            onTinyTaskToggle: (task) {
              _toggleTask(task, !task.isCompleted);
              Future.delayed(const Duration(milliseconds: 300), _loadBigTasks);
            },
            onTinyTaskEdit: (task) => _showEditTinyTaskDialog(task),
            onEdit: () => _showEditBigTaskDialog(bigTask),
            onDelete: () => _deleteBigTask(bigTask),
          );
        },
      ),
    );
  }

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
    _loadTasks();
  }

  void _nextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
    _loadTasks();
  }

  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedTaskPeriod = _selectedPeriod == 'big'
        ? 'full'
        : _selectedPeriod;
    TimeOfDay? selectedTime;
    bool reminderEnabled = false;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Add Task',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: StatefulBuilder(
            builder: (context, setModalState) {
              Future<void> pickTime() async {
                DateTime tempTime = DateTime(
                  2000,
                  1,
                  1,
                  selectedTime?.hour ?? TimeOfDay.now().hour,
                  selectedTime?.minute ?? TimeOfDay.now().minute,
                );
                await showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: SizedBox(
                      height: 220,
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.time,
                        initialDateTime: tempTime,
                        use24hFormat: false,
                        onDateTimeChanged: (dt) => tempTime = dt,
                      ),
                    ),
                  ),
                );
                final picked = TimeOfDay(
                  hour: tempTime.hour,
                  minute: tempTime.minute,
                );
                setModalState(() {
                  selectedTime = picked;
                  selectedTaskPeriod = picked.hour < 12 ? 'am' : 'pm';
                });
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Task Title',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      readOnly: true,
                      onTap: pickTime,
                      decoration: InputDecoration(
                        labelText: 'Time (optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        suffixIcon: const Icon(Icons.access_time_rounded),
                      ),
                      controller: TextEditingController(
                        text: selectedTime?.format(context) ?? '',
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedTaskPeriod,
                      decoration: InputDecoration(
                        labelText: 'Time Slot',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'full',
                          child: Text('Full Day'),
                        ),
                        DropdownMenuItem(value: 'am', child: Text('AM')),
                        DropdownMenuItem(value: 'pm', child: Text('PM')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() {
                            selectedTaskPeriod = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Remind me'),
                      subtitle: selectedTime == null
                          ? const Text(
                              'Set a time above to enable',
                              style: TextStyle(fontSize: 12),
                            )
                          : null,
                      secondary: const Icon(Icons.notifications_outlined),
                      value: reminderEnabled,
                      onChanged: selectedTime == null
                          ? null
                          : (val) =>
                              setModalState(() => reminderEnabled = val),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccentBg,
                foregroundColor: _kAccentFg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () async {
                final title = titleController.text.trim();
                final description = descriptionController.text.trim();
                if (title.isEmpty) return;

                final newTask = Task(
                  userId: widget.userId,
                  firebaseUserId: widget.firebaseUserId,
                  title: title,
                  description: description.isEmpty ? null : description,
                  date: _dateKey,
                  time: selectedTime != null
                      ? selectedTime!.format(context)
                      : '',
                  isCompleted: false,
                  period: selectedTaskPeriod,
                  reminderEnabled: reminderEnabled && selectedTime != null,
                );

                Navigator.pop(context);
                await _addTask(newTask);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _softSurfaceColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _buildPeriodButton('Full Day', 'full', Icons.check_rounded),
          _buildPeriodButton('AM', 'am', Icons.wb_sunny_rounded),
          _buildPeriodButton('PM', 'pm', Icons.nightlight_round),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, String value, IconData icon) {
    final bool isSelected = _selectedPeriod == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPeriod = value;
          });
        },
        child: AnimatedContainer(
          duration: isSelected
              ? const Duration(milliseconds: 200)
              : Duration.zero,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? _kAccentBg : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? _kAccentFg : _mutedTextColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? _kAccentFg : _onSurfaceColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCalendarPicker() {
    final isDark = _isDark;
    final primary = const Color(0xFF1E5A67);
    showDialog(
      context: context,
      builder: (context) {
        DateTime focusedDay = _selectedDate;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                    child: TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(day, _selectedDate),
                      enabledDayPredicate: (day) {
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        final normalized = DateTime(
                          day.year,
                          day.month,
                          day.day,
                        );
                        return !normalized.isBefore(today);
                      },
                      onDaySelected: (selectedDay, newFocusedDay) {
                        setState(() {
                          _selectedDate = selectedDay;
                        });
                        Navigator.of(context).pop();
                        _loadTasks();
                      },
                      onPageChanged: (newFocused) {
                        setModalState(() => focusedDay = newFocused);
                      },
                      eventLoader: (day) {
                        final normalized = DateTime(
                          day.year,
                          day.month,
                          day.day,
                        );
                        return _taskDates.any((d) => isSameDay(d, normalized))
                            ? [true]
                            : [];
                      },
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: primary,
                          shape: BoxShape.circle,
                        ),
                        markerDecoration: BoxDecoration(
                          color: isDark ? Colors.tealAccent : primary,
                          shape: BoxShape.circle,
                        ),
                        markersMaxCount: 1,
                        outsideDaysVisible: false,
                        disabledTextStyle: TextStyle(
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDateCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.18 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _previousDay,
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _onSurfaceColor,
            ),
          ),
          GestureDetector(
            onTap: _showCalendarPicker,
            child: Text(
              _formattedDate,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _onSurfaceColor,
              ),
            ),
          ),
          IconButton(
            onPressed: _nextDay,
            icon: Icon(Icons.arrow_forward_ios_rounded, color: _onSurfaceColor),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note_rounded, size: 68, color: _mutedTextColor),
            const SizedBox(height: 12),
            Text(
              'No tasks for this time slot',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _mutedTextColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap "Add Task" to create one.',
              style: TextStyle(fontSize: 14, color: _mutedTextColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedUndoCard(Task task) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _isDark ? const Color(0xFF1B3A27) : const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _isDark
                  ? Colors.black.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF66BB6A),
              size: 22,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Task completed',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF66BB6A),
                ),
              ),
            ),
            TextButton(
              onPressed: () => _toggleTask(task, false),
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
      ),
    );
  }

  Widget _buildDeletedUndoCard(Task task) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _isDark ? const Color(0xFF3A1B1B) : const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _isDark
                  ? Colors.black.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFE57373),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '"${task.title}" deleted',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE57373),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => _undoDeleteTask(task),
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
      ),
    );
  }

  Widget _buildTaskList() {
    if (_showBigTasks) return _buildBigTaskList();

    if (_isLoading) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }

    final displayTasks = _filteredTasks
        .where(
          (t) =>
              !t.isCompleted ||
              (t.id != null && _recentlyCompleted.contains(t.id!)),
        )
        .toList();

    if (displayTasks.isEmpty && _recentlyDeleted.isEmpty) {
      return _buildEmptyState();
    }

    final List<({Task task, bool isDeleted})> combined = [
      for (final t in displayTasks) (task: t, isDeleted: false),
    ];

    final sortedDeleted = List.of(_recentlyDeleted)
      ..sort((a, b) => a.index.compareTo(b.index));

    for (final entry in sortedDeleted.reversed) {
      final idx = entry.index.clamp(0, combined.length);
      combined.insert(idx, (task: entry.task, isDeleted: true));
    }

    final bigTaskLookup = <int, BigTask>{
      for (final bt in _bigTasks)
        if (bt.id != null) bt.id!: bt,
    };

    return Expanded(
      child: ListView.builder(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 88),
        itemCount: combined.length,
        itemBuilder: (context, index) {
          final item = combined[index];

          if (item.isDeleted) {
            return _buildDeletedUndoCard(item.task);
          }

          final task = item.task;

          if (task.isCompleted) {
            return _buildCompletedUndoCard(task);
          }

          Color? tileColor;
          if (task.bigTaskId != null) {
            final bt = bigTaskLookup[task.bigTaskId];
            if (bt != null) {
              tileColor = bigTaskColors[bt.color];
            }
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Slidable(
              key: ValueKey(task.id),
              endActionPane: ActionPane(
                motion: const DrawerMotion(),
                extentRatio: 0.4,
                children: [
                  SlidableAction(
                    onPressed: (_) => _showEditTaskDialog(task),
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(18),
                    ),
                  ),
                  SlidableAction(
                    onPressed: (_) => _deleteTask(task, index),
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(18),
                    ),
                  ),
                ],
              ),
              child: TaskTile(
                task: task,
                bigTaskColor: tileColor,
                onChanged: (value) {
                  _toggleTask(task, value ?? false);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: _surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.history_rounded, color: _onSurfaceColor),
          onPressed: () {
            if (widget.userId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HistoryView(
                    userId: widget.userId!,
                    firebaseUserId: widget.firebaseUserId,
                  ),
                ),
              ).then((_) => _loadTasks());
            }
          },
        ),
        title: Text(
          'Tiny Tasks',
          style: TextStyle(
            color: _onSurfaceColor,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: _onSurfaceColor),
            onPressed: _loadTasks,
          ),
          IconButton(
            icon: Icon(Icons.settings, color: _onSurfaceColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
              builder: (context) => SettingsView(
                userId: widget.userId,
                firebaseUserId: widget.firebaseUserId,
              ),
            ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_showBigTasks) _buildDateCard(),
          if (!_showBigTasks) _buildPeriodSelector(),
          _buildTaskList(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showBigTasks ? _showAddBigTaskDialog : _showAddTaskDialog,
        backgroundColor: _kAccentBg,
        foregroundColor: _kAccentFg,
        elevation: 2,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          _showBigTasks ? 'Add Big Task' : 'Add Task',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _showBigTasks ? 1 : 0,
        onTap: (index) {
          final goingBig = index == 1;
          setState(() => _showBigTasks = goingBig);
          if (goingBig) _loadBigTasks();
        },
        elevation: 8,
        selectedItemColor: _kAccentFg,
        unselectedItemColor: _mutedTextColor,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.task_alt_rounded),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.layers_rounded),
            label: 'Big Tasks',
          ),
        ],
      ),
    );
  }
}
