import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tinytasks/models/task.dart';

class TaskDetailView extends StatelessWidget {
  final Task task;

  const TaskDetailView({super.key, required this.task});

  static void show(BuildContext context, Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TaskDetailView(task: task),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheduledDate = DateFormat('EEEE, MMMM d, yyyy')
        .format(DateTime.parse(task.date));
    final createdAtFormatted = DateFormat('MMM d, yyyy • h:mm a')
        .format(task.createdAt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 80),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // status chip + title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: task.isCompleted
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  task.isCompleted ? 'Completed' : 'Pending',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: task.isCompleted
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Divider(height: 1),
          const SizedBox(height: 28),

          // detail rows
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Scheduled for',
            value: scheduledDate,
          ),
          const SizedBox(height: 24),
          _InfoRow(
            icon: Icons.access_time_outlined,
            label: 'Time',
            value: task.time.isNotEmpty ? task.time : 'No time set',
          ),
          const SizedBox(height: 24),
          _InfoRow(
            icon: Icons.add_circle_outline,
            label: 'Created on',
            value: createdAtFormatted,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade500,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
