import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

const _kAccentBg = Color(0xFFD7EEF2);
const _kAccentFg = Color(0xFF1E5A67);

class TaskView extends StatefulWidget {
  final int? userId;
  final String? firebaseUserId;
  final String? accessToken;

  const TaskView({super.key, this.userId, this.firebaseUserId, this.accessToken});

  @override
  State<TaskView> createState() => _TaskViewState();
}

class _TaskViewState extends State<TaskView> {
  final TaskRepository _taskRepository = TaskRepository();
  final BigTaskRepository _bigTaskRepository = BigTaskRepository();

  DateTime _selectedDate = DateTime.now();
  List<Task> _tasks = [];
  bool _isLoading = true;
  String _selectedPeriod = 'full';
  List<BigTask> _bigTasks = [];
  Map<int, List<Task>> _tinyTasksByBigTask = {};
  bool _isLoadingBigTasks = false;
  final Set<int> _recentlyCompleted = {};
  final List<({Task task, int index})> _recentlyDeleted = [];

  @override
  void initState() {
    super.initState();
    _rescheduleOverdueTasks().then((_) {
      _loadTasks();
      _loadBigTasks();
    });
  }

  String get _formattedDate =>
      DateFormat('EEE, MMM d, y').format(_selectedDate);
  String get _dateKey => DateFormat('yyyy-MM-dd').format(_selectedDate);

  List<Task> get _filteredTasks {
    if (_selectedPeriod == 'full') {
      return _tasks;
    }
    return _tasks.where((task) => task.period == _selectedPeriod).toList();
  }

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

    // ✅ FIXED: safe calendar call
    try {
      if (widget.accessToken != null) {
        await GoogleCalendarService().createEvent(
          accessToken: widget.accessToken!,
          title: task.title,
          date: task.date,
        );
      }
    } catch (e) {
      debugPrint("Calendar sync failed: $e");
    }

    await _loadTasks();
  } catch (e) {
    debugPrint('Error adding task: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add task: $e')),
      );
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
            setState(() => _recentlyDeleted.removeWhere((e) => e.task.id == taskId));
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update task: $e')),
        );
      }
    }
  }

  void _showEditTaskDialog(Task task) {
    final titleController = TextEditingController(text: task.title);
    final descriptionController =
        TextEditingController(text: task.description ?? '');
    String selectedTaskPeriod = task.period;
    TimeOfDay? selectedTime = _parseTimeOfDay(task.time);
    bool reminderEnabled = task.reminderEnabled;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
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
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black38),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded,
                                size: 20, color: Colors.black54),
                            const SizedBox(width: 10),
                            Text(
                              selectedTime != null
                                  ? selectedTime!.format(context)
                                  : 'Time (optional)',
                              style: TextStyle(
                                fontSize: 16,
                                color: selectedTime != null
                                    ? Colors.black87
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedTaskPeriod,
                      decoration: InputDecoration(
                        labelText: 'Time Slot',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'full', child: Text('Full Day')),
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
    } catch (e) {
      debugPrint('Error updating task: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update task: $e')));
      }
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
    final descriptionController =
        TextEditingController(text: bigTask.description ?? '');
    String selectedPriority = bigTask.priority;
    String selectedDueDate = bigTask.dueDate;
    String selectedColor = bigTask.color;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Big Task',
              style: TextStyle(fontWeight: FontWeight.w700)),
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
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedPriority,
                      decoration: InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(
                            value: 'medium', child: Text('Medium')),
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
                            selectedDueDate =
                                DateFormat('yyyy-MM-dd').format(picked);
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black38),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'Due: $selectedDueDate',
                          style: const TextStyle(
                              fontSize: 16, color: Colors.black87),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Color',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: bigTaskColors.entries.map((entry) {
                        final isSelected = selectedColor == entry.key;
                        return GestureDetector(
                          onTap: () => setModalState(
                              () => selectedColor = entry.key),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: entry.value,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                      color: Colors.black54, width: 2)
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    size: 18, color: Colors.black54)
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
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                Navigator.pop(context);
                try {
                  await _bigTaskRepository.updateBigTask(
                    bigTask.copyWith(
                      title: title,
                      description:
                          descriptionController.text.trim().isEmpty
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
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Failed to update big task: $e')),
                    );
                  }
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
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Subtask',
              style: TextStyle(fontWeight: FontWeight.w700)),
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
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () async {
                      final now = DateTime.now();
                      final initial =
                          DateTime.tryParse(selectedDate) ?? now;
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            initial.isBefore(now) ? now : initial,
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setModalState(() {
                          selectedDate =
                              DateFormat('yyyy-MM-dd').format(picked);
                        });
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black38),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Date: $selectedDate',
                        style: const TextStyle(
                            fontSize: 16, color: Colors.black87),
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
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                Navigator.pop(context);
                await _editTask(
                    task.copyWith(title: title, date: selectedDate));
                await _loadBigTasks();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showAddBigTaskDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedPriority = 'medium';
    String? selectedDueDate;
    String selectedColor = 'blue';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
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
                        labelText: 'Description (optional)',
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
                          border: Border.all(color: Colors.black38),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          selectedDueDate != null
                              ? 'Due: $selectedDueDate'
                              : 'Select due date',
                          style: TextStyle(
                            color: selectedDueDate != null
                                ? Colors.black87
                                : Colors.black54,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Color',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
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
                                  ? Border.all(color: Colors.black54, width: 2)
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 18,
                                    color: Colors.black54,
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
                if (title.isEmpty || selectedDueDate == null) return;
                Navigator.pop(context);
                _createBigTaskWithDecomposition(
                  title: title,
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
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
    String? description,
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

    // Show loading dialog
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
        Navigator.pop(context); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI decomposition failed. Big task was saved without subtasks.'),
          ),
        );
      }
      await _loadBigTasks();
      return;
    }

    if (!mounted) return;
    Navigator.pop(context); // dismiss loading

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
          backgroundColor: Colors.white,
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
      try {
        await _taskRepository.createTask(
          task,
          firebaseUserId: widget.firebaseUserId,
        );
      } catch (e) {
        debugPrint('Error saving subtask: $e');
      }
    }
    await _loadTasks();
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
            children: const [
              Icon(
                Icons.rocket_launch_rounded,
                size: 68,
                color: Color(0xFFB0BEC5),
              ),
              SizedBox(height: 12),
              Text(
                'No big tasks yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              SizedBox(height: 6),
              Text(
                "Tap 'Add Big Task' to create one.",
                style: TextStyle(fontSize: 14, color: Colors.black45),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
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
    String selectedTaskPeriod = _selectedPeriod == 'big' ? 'full' : _selectedPeriod;
    TimeOfDay? selectedTime;
    bool reminderEnabled = false;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Add Task',
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
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black38),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded,
                                size: 20, color: Colors.black54),
                            const SizedBox(width: 10),
                            Text(
                              selectedTime != null
                                  ? selectedTime!.format(context)
                                  : 'Time (optional)',
                              style: TextStyle(
                                fontSize: 16,
                                color: selectedTime != null
                                    ? Colors.black87
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedTaskPeriod,
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
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _buildPeriodButton('Big Tasks', 'big', Icons.rocket_launch_rounded),
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
          if (value == 'big') _loadBigTasks();
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
                color: isSelected ? _kAccentFg : Colors.black54,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? _kAccentFg : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          Text(
            _formattedDate,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          IconButton(
            onPressed: _nextDay,
            icon: const Icon(Icons.arrow_forward_ios_rounded),
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
          children: const [
            Icon(Icons.event_note_rounded, size: 68, color: Color(0xFFB0BEC5)),
            SizedBox(height: 12),
            Text(
              'No tasks for this time slot',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Tap "Add Task" to create one.',
              style: TextStyle(fontSize: 14, color: Colors.black45),
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
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF66BB6A), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Task completed',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ),
            TextButton(
              onPressed: () => _toggleTask(task, false),
              style: TextButton.styleFrom(
                foregroundColor: _kAccentFg,
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
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.delete_outline_rounded,
                color: Color(0xFFE53935), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '"${task.title}" deleted',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFB71C1C),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => _undoDeleteTask(task),
              style: TextButton.styleFrom(
                foregroundColor: _kAccentFg,
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
    if (_selectedPeriod == 'big') return _buildBigTaskList();

    if (_isLoading) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }

    // Filter: show incomplete tasks + recently completed (undo card); hide the rest
    final displayTasks = _filteredTasks.where((t) =>
      !t.isCompleted ||
      (t.id != null && _recentlyCompleted.contains(t.id!))
    ).toList();

    if (displayTasks.isEmpty && _recentlyDeleted.isEmpty) {
      return _buildEmptyState();
    }

    // Build merged list: insert deleted undo cards at their original positions.
    // Each entry is either a regular Task or a deleted-marker Task.
    final List<({Task task, bool isDeleted})> combined = [
      for (final t in displayTasks) (task: t, isDeleted: false),
    ];
    final sortedDeleted = List.of(_recentlyDeleted)
      ..sort((a, b) => a.index.compareTo(b.index));
    // Insert from highest index to lowest to avoid shifting earlier entries.
    for (final entry in sortedDeleted.reversed) {
      final idx = entry.index.clamp(0, combined.length);
      combined.insert(idx, (task: entry.task, isDeleted: true));
    }

    // Build a lookup for big task colors
    final bigTaskLookup = <int, BigTask>{
      for (final bt in _bigTasks)
        if (bt.id != null) bt.id!: bt,
    };

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.history_rounded, color: Colors.black87),
          onPressed: () {
            if (widget.userId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HistoryView(userId: widget.userId!, firebaseUserId: widget.firebaseUserId),
                ),
              ).then((_) => _loadTasks());
            }
          },
        ),
        title: const Text(
          'Tiny Tasks',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
            onPressed: _loadTasks,
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsView()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedPeriod != 'big') _buildDateCard(),
          _buildPeriodSelector(),
          _buildTaskList(),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _selectedPeriod == 'big'
                ? _showAddBigTaskDialog
                : _showAddTaskDialog,
            icon: const Icon(Icons.add_rounded),
            label: Text(
              _selectedPeriod == 'big' ? 'Add Big Task' : 'Add Task',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccentBg,
              foregroundColor: _kAccentFg,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
