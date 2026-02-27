import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tinytasks/models/task.dart';

class TaskDetailView extends StatelessWidget {
  static const routeName = '/task-detail';

  final Task task;

  const TaskDetailView({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final createdAtFormatted = DateFormat('EEE, MMM d, yyyy • h:mm a')
        .format(task.createdAt);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(label: 'Time', value: task.time),
                    const SizedBox(height: 8),
                    _DetailRow(
                      label: 'Status',
                      value: task.isCompleted ? 'Completed' : 'Pending',
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(label: 'Created', value: createdAtFormatted),
                    const SizedBox(height: 8),
                    _DetailRow(label: 'User ID', value: task.userId.toString()),
                    if (task.id != null) ...[
                      const SizedBox(height: 8),
                      _DetailRow(label: 'Task ID', value: task.id.toString()),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}
