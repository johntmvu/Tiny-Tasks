import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tinytasks/widgets/task_tile.dart';
import 'package:tinytasks/models/task.dart';

class TaskView extends StatefulWidget {
  const TaskView({super.key});

  @override
  State<TaskView> createState() => _TaskViewState();
}

class _TaskViewState extends State<TaskView> {
  DateTime selectedDate = DateTime.now();
  final List<Task> _tasks = [
    Task(title: "Review math homework", time: "09:00 AM"),
    Task(title: "Take medication", time: "10:30 AM", isDone: true),
    Task(title: "Study for biology quiz", time: "11:00 AM"),
    Task(title: "Lunch break", time: "12:30 PM"),
    Task(title: "Practice piano", time: "02:00 PM"),
    Task(title: "Go for a walk", time: "04:00 PM"),
    Task(title: "homework", time: "21:33 PM"),
  ];

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
            child: ListView.builder(
              itemCount: _tasks.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                return TaskTile(
                  task: _tasks[index],
                  onCheckboxChanged: (bool? value) {
                    setState(() {
                      _tasks[index].isDone = value ?? false;
                    });
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
                  onPressed: () {
                    // Your logic here
                  },
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
