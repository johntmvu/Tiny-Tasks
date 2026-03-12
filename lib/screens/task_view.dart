import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:tinytasks/widgets/task_tile.dart';
import 'package:tinytasks/models/task.dart';
import 'settings_view.dart';
import 'package:tinytasks/repositories/task_repository.dart';
import 'package:tinytasks/screens/task_detail_view.dart';

class TaskView extends StatefulWidget {
  final int userId;
  final String firebaseUserId;

  const TaskView({
    super.key,
    required this.userId,
    required this.firebaseUserId,
  });

  @override
  State<TaskView> createState() => _TaskViewState();
}

class _TaskViewState extends State<TaskView> {
  DateTime selectedDate = DateTime.now();
  List<Task> _tasks = [];
  final TaskRepository _taskRepository = TaskRepository();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _syncTasks() async {
    setState(() => _isLoading = true);
    try {
      await _taskRepository.syncFromFirestore(
        widget.firebaseUserId,
        widget.userId,
      );
      await _loadTasks();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tasks synced')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTasks() async {
    try {
      final tasks = await _taskRepository.getTasksByUserAndDate(
        widget.userId,
        _formatDate(selectedDate),
      );
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load tasks: $e')));
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        _isLoading = true;
      });
      _loadTasks();
    }
  }

  void _previousDay() {
    setState(() {
      selectedDate = selectedDate.subtract(const Duration(days: 1));
      _isLoading = true;
    });
    _loadTasks();
  }

  void _nextDay() {
    setState(() {
      selectedDate = selectedDate.add(const Duration(days: 1));
      _isLoading = true;
    });
    _loadTasks();
  }

  Future<void> _addTask(String title, String time) async {
    try {
      final newTask = Task(
        userId: widget.userId,
        title: title,
        time: time,
        date: _formatDate(selectedDate),
      );

      await _taskRepository.createTask(
        newTask,
        firebaseUserId: widget.firebaseUserId,
      );
      await _loadTasks();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add task: $e')));
    }
  }

  Future<void> _updateTask(Task task, {String? title, String? time}) async {
    try {
      final updatedTask = task.copyWith(title: title, time: time);

      await _taskRepository.updateTask(
        updatedTask,
        firebaseUserId: widget.firebaseUserId,
      );
      await _loadTasks();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update task: $e')));
    }
  }

  Future<void> _deleteTask(String taskId) async {
    try {
      await _taskRepository.deleteTask(
        int.parse(taskId),
        firebaseUserId: widget.firebaseUserId,
      );
      await _loadTasks();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete task: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tiny Tasks'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.sync), onPressed: _syncTasks),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsView()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const Divider(),

          // Date Navigation
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _previousDay,
              ),
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    child: Text(
                      DateFormat('EEE, MMM d, yyyy').format(selectedDate),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: _nextDay,
              ),
            ],
          ),

          const Divider(),

          const SingleChoice(),

          const Divider(),

          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _tasks.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) {
                      return TaskTile(
                        task: _tasks[index],
                        onTap: () => TaskDetailView.show(context, _tasks[index]),
                        onCheckboxChanged: (bool? value) async {
                          final updatedTask = _tasks[index].copyWith(
                            isCompleted: value ?? false,
                          );
                          await _taskRepository.updateTask(
                            updatedTask,
                            firebaseUserId: widget.firebaseUserId,
                          );
                          await _loadTasks();
                        },
                        onEdit: () => _showEditTaskDialog(_tasks[index]),
                        onDelete: () => _showDeleteTaskDialog(_tasks[index]),
                      );
                    },
                  ),
          ),

          const Divider(),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showAddTaskDialog,
                  icon: const Icon(Icons.add),
                  label: const Text("Add Task"),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    var selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Task'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Task Title'),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Select Time',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      initialDateTime: DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        DateTime.now().day,
                        selectedTime.hour,
                        selectedTime.minute,
                      ),
                      onDateTimeChanged: (DateTime newDateTime) {
                        setDialogState(() {
                          selectedTime = TimeOfDay.fromDateTime(newDateTime);
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Selected: ${selectedTime.format(context)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (titleController.text.isNotEmpty) {
                      _addTask(
                        titleController.text.trim(),
                        selectedTime.format(context),
                      );
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditTaskDialog(Task task) {
    final titleController = TextEditingController(text: task.title);
    var selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Task'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Task Title'),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Select Time',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      initialDateTime: DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        DateTime.now().day,
                        selectedTime.hour,
                        selectedTime.minute,
                      ),
                      onDateTimeChanged: (DateTime newDateTime) {
                        setDialogState(() {
                          selectedTime = TimeOfDay.fromDateTime(newDateTime);
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Selected: ${selectedTime.format(context)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) return;
                    _updateTask(
                      task,
                      title: titleController.text.trim(),
                      time: selectedTime.format(context),
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showDeleteTaskDialog(Task task) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && task.id != null) {
      await _deleteTask(task.id!);
    }
  }
}

enum Calendar { full, am, pm }

class SingleChoice extends StatefulWidget {
  const SingleChoice({super.key});

  @override
  State<SingleChoice> createState() => _SingleChoiceState();
}

class _SingleChoiceState extends State<SingleChoice> {
  Calendar calendarView = Calendar.full;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SegmentedButton<Calendar>(
        segments: const <ButtonSegment<Calendar>>[
          ButtonSegment<Calendar>(
            value: Calendar.full,
            label: Text('Full Day'),
            icon: Icon(Icons.sunny),
          ),
          ButtonSegment<Calendar>(
            value: Calendar.am,
            label: Text('AM'),
            icon: Icon(Icons.wb_sunny),
          ),
          ButtonSegment<Calendar>(
            value: Calendar.pm,
            label: Text('PM'),
            icon: Icon(Icons.nightlight_round),
          ),
        ],
        selected: <Calendar>{calendarView},
        onSelectionChanged: (Set<Calendar> newSelection) {
          setState(() {
            calendarView = newSelection.first;
          });
        },
      ),
    );
  }
}
