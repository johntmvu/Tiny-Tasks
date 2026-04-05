import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../repositories/task_repository.dart';
import '../widgets/task_tile.dart';
import 'settings_view.dart';

class TaskView extends StatefulWidget {
  final int? userId;
  final String? firebaseUserId;

  const TaskView({
    super.key,
    this.userId,
    this.firebaseUserId,
  });

  @override
  State<TaskView> createState() => _TaskViewState();
}

class _TaskViewState extends State<TaskView> {
  final TaskRepository _taskRepository = TaskRepository();

  DateTime _selectedDate = DateTime.now();
  List<Task> _tasks = [];
  bool _isLoading = true;
  String _selectedPeriod = 'full';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  String get _formattedDate => DateFormat('EEE, MMM d, y').format(_selectedDate);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load tasks: $e')),
        );
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

  Future<void> _deleteTask(Task task) async {
    try {
      if (task.id != null) {
        await _taskRepository.deleteTask(
          task.id!,
          firebaseUserId: widget.firebaseUserId,
        );
        await _loadTasks();
      }
    } catch (e) {
      debugPrint('Error deleting task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete task: $e')),
        );
      }
    }
  }

  Future<void> _toggleTask(Task task, bool value) async {
    try {
      final updatedTask = task.copyWith(isCompleted: value);
      await _taskRepository.updateTask(
        updatedTask,
        firebaseUserId: widget.firebaseUserId,
      );
      await _loadTasks();
    } catch (e) {
      debugPrint('Error updating task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update task: $e')),
        );
      }
    }
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
    final timeController = TextEditingController();
    String selectedTaskPeriod = _selectedPeriod;

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
                    TextField(
                      controller: timeController,
                      decoration: InputDecoration(
                        labelText: 'Time (optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
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
                        DropdownMenuItem(value: 'full', child: Text('Full Day')),
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
                backgroundColor: const Color(0xFFD7EEF2),
                foregroundColor: const Color(0xFF1E5A67),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () async {
                final title = titleController.text.trim();
                final description = descriptionController.text.trim();
                final time = timeController.text.trim();

                if (title.isEmpty) return;

                final newTask = Task(
                  userId: widget.userId,
                  firebaseUserId: widget.firebaseUserId,
                  title: title,
                  description: description.isEmpty ? null : description,
                  date: _dateKey,
                  time: time,
                  isCompleted: false,
                  period: selectedTaskPeriod,
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
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFD7EEF2) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? const Color(0xFF1E5A67) : Colors.black54,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? const Color(0xFF1E5A67) : Colors.black87,
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
            Icon(
              Icons.event_note_rounded,
              size: 68,
              color: Color(0xFFB0BEC5),
            ),
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
              style: TextStyle(
                fontSize: 14,
                color: Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList() {
    if (_isLoading) {
      return const Expanded(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_filteredTasks.isEmpty) {
      return _buildEmptyState();
    }

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        itemCount: _filteredTasks.length,
        itemBuilder: (context, index) {
          final task = _filteredTasks[index];
          return TaskTile(
            task: task,
            onChanged: (value) {
              _toggleTask(task, value ?? false);
            },
            onDelete: () {
              _deleteTask(task);
            },
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
                MaterialPageRoute(
                  builder: (context) => const SettingsView(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateCard(),
          _buildPeriodSelector(),
          _buildTaskList(),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _showAddTaskDialog,
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Add Task',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD7EEF2),
              foregroundColor: const Color(0xFF1E5A67),
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