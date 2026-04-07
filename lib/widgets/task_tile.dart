
import 'package:flutter/material.dart';
import '../models/task.dart';

class TaskTile extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final ValueChanged<bool?>? onChanged;
  final Color? bigTaskColor;

  const TaskTile({
    super.key,
    required this.task,
    this.onTap,
    this.onDelete,
    this.onChanged,
    this.bigTaskColor,
  });

  Color _periodColor() {
    switch (task.period) {
      case 'am':
        return const Color(0xFFFFF3CD);
      case 'pm':
        return const Color(0xFFE3F2FD);
      default:
        return const Color(0xFFE8F5E9);
    }
  }

  String _periodLabel() {
    switch (task.period) {
      case 'am':
        return 'AM';
      case 'pm':
        return 'PM';
      default:
        return 'FULL DAY';
    }
  }

  @override
  Widget build(BuildContext context) {
    final description = task.description ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: bigTaskColor != null
            ? Border(left: BorderSide(color: bigTaskColor!, width: 4))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        onTap: onTap,
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: onChanged,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: task.isCompleted ? Colors.black45 : Colors.black87,
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: task.isCompleted ? Colors.black38 : Colors.black54,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _periodColor(),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _periodLabel(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        trailing: onDelete != null
            ? IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: onDelete,
              )
            : null,
      ),
    );
  }
}