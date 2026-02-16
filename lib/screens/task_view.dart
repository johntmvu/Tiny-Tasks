import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tinytasks/widgets/task_tile.dart';
import 'package:tinytasks/models/task.dart';
import 'package:tinytasks/repositories/task_repository.dart';

class TaskView extends StatefulWidget {
  final int userId;
  
  const TaskView({super.key, required this.userId});

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

  Future<void> _loadTasks() async {
    try {
      final tasks = await _taskRepository.getTasksByUser(widget.userId);
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading tasks: $e');
      setState(() {
        _isLoading = false;
      });
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
      });
    }
  }

  void _previousDay() {
    setState(() {
      selectedDate = selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _nextDay() {
    setState(() {
      selectedDate = selectedDate.add(const Duration(days: 1));
    });
  }

  Future<void> _addTask(String title, String time) async {
    try {
      final newTask = Task(
        userId: 1, // Placeholder userId
        title: title,
        time: time,
      );
      await _taskRepository.createTask(newTask);
      await _loadTasks(); // Refresh the list
    } catch (e) {
      print('Error adding task: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tiny Tasks'),
        centerTitle: true,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.settings)),
        ],
      ),
      body: Column(
        children: [
          Divider(),
          // Date navigation row
          Row(
            children: [
              IconButton(icon: Icon(Icons.arrow_back), onPressed: _previousDay),
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    child: Text(
                      DateFormat('EEE, MMM d, yyyy').format(selectedDate),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(icon: Icon(Icons.arrow_forward), onPressed: _nextDay),
            ],
          ),
          Divider(),
          // Day Time slider
          SingleChoice(),
          Divider(),
          // Task list
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _tasks.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) {
                      return TaskTile(
                        task: _tasks[index],
                        onCheckboxChanged: (bool? value) async {
                          setState(() {
                            _tasks[index] = _tasks[index].copyWith(
                              isCompleted: value ?? false,
                            );
                          });
                          // Save to database
                          await _taskRepository.updateTask(_tasks[index]);
                        },
                      );
                    },
                  ),
          ),
          Divider(),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
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
    final timeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Task Title'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: timeController,
                decoration: const InputDecoration(labelText: 'Time (HH:mm)'),
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
                if (titleController.text.isNotEmpty &&
                    timeController.text.isNotEmpty) {
                  _addTask(titleController.text, timeController.text);
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
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
            icon: Icon(Icons.sunny_snowing),
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
