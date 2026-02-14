import 'package:flutter/material.dart';
import '../models/task.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Task> tasks = [];
  final TextEditingController taskController = TextEditingController();

  void addTask() {
    final text = taskController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      tasks.add(Task(title: text));
      taskController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Today's Tasks")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: taskController,
              decoration: InputDecoration(
                labelText: "Add a task",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => addTask(),
            ),
            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: addTask,
              child: const Text("Add Task"),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: tasks.isEmpty
                  ? const Center(child: Text("No tasks yet. Add one!"))
                  : ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        return Card(
                          child: ListTile(
                            title: Text(tasks[index].title),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}