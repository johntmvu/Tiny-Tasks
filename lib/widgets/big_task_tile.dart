import 'package:flutter/material.dart';
import '../models/big_task.dart';
import '../models/task.dart';

const Map<String, Color> bigTaskColors = {
  'blue': Color(0xFF90CAF9),
  'green': Color(0xFFA5D6A7),
  'orange': Color(0xFFFFCC80),
  'purple': Color(0xFFCE93D8),
  'red': Color(0xFFEF9A9A),
  'teal': Color(0xFF80CBC4),
  'pink': Color(0xFFF48FB1),
  'yellow': Color(0xFFFFF59D),
};

class BigTaskTile extends StatefulWidget {
  final BigTask bigTask;
  final List<Task> tinyTasks;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final ValueChanged<Task>? onTinyTaskToggle;
  final ValueChanged<Task>? onTinyTaskEdit;

  const BigTaskTile({
    super.key,
    required this.bigTask,
    required this.tinyTasks,
    this.onDelete,
    this.onEdit,
    this.onTinyTaskToggle,
    this.onTinyTaskEdit,
  });

  @override
  State<BigTaskTile> createState() => _BigTaskTileState();
}

class _BigTaskTileState extends State<BigTaskTile> {
  Color _priorityBadgeColor() {
    switch (widget.bigTask.priority) {
      case 'high':
        return const Color(0xFFFFE0E0);
      case 'low':
        return const Color(0xFFE8F5E9);
      default:
        return const Color(0xFFFFF3CD);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tinyTasks = widget.tinyTasks;
    final completedCount = tinyTasks.where((t) => t.isCompleted).length;
    final totalCount = tinyTasks.length;
    final allDone = totalCount > 0 && completedCount == totalCount;
    final taskColor =
        bigTaskColors[widget.bigTask.color] ?? const Color(0xFF90CAF9);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white,
          leading: CircleAvatar(
            radius: 12,
            backgroundColor: taskColor,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  widget.bigTask.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: allDone ? Colors.black45 : Colors.black87,
                    decoration:
                        allDone ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _priorityBadgeColor(),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.bigTask.priority.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '$completedCount/$totalCount subtasks · Due ${widget.bigTask.dueDate}',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onEdit != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: widget.onEdit,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                ),
              if (widget.onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  onPressed: widget.onDelete,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                ),
              const SizedBox(width: 8),
            ],
          ),
          children: tinyTasks.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'No subtasks yet.',
                      style: TextStyle(color: Colors.black45, fontSize: 14),
                    ),
                  ),
                ]
              : tinyTasks.map((task) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Checkbox(
                          value: task.isCompleted,
                          onChanged: (_) {
                            widget.onTinyTaskToggle?.call(task);
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 15,
                              color: task.isCompleted ? Colors.black38 : Colors.black87,
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            task.date,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        if (widget.onTinyTaskEdit != null)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                size: 16, color: Colors.black38),
                            padding: const EdgeInsets.only(left: 4),
                            constraints: const BoxConstraints(),
                            onPressed: () => widget.onTinyTaskEdit!(task),
                          ),
                      ],
                    ),
                  );
                }).toList(),
        ),
      ),
    );
  }
}
