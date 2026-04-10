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

    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          backgroundColor: cardColor,
          collapsedBackgroundColor: cardColor,
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
                    color: allDone ? onSurfaceVariant : onSurface,
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
              style: TextStyle(fontSize: 13, color: onSurfaceVariant),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onEdit != null)
                IconButton(
                  icon: Icon(Icons.edit_outlined, size: 20, color: onSurfaceVariant),
                  onPressed: widget.onEdit,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                ),
              if (widget.onDelete != null)
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, size: 20, color: onSurfaceVariant),
                  onPressed: widget.onDelete,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                ),
              const SizedBox(width: 8),
            ],
          ),
          children: tinyTasks.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'No subtasks yet.',
                      style: TextStyle(color: onSurfaceVariant, fontSize: 14),
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
                              color: task.isCompleted ? onSurfaceVariant : onSurface,
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
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            task.date,
                            style: TextStyle(
                              fontSize: 12,
                              color: onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (widget.onTinyTaskEdit != null)
                          IconButton(
                            icon: Icon(Icons.edit_outlined,
                                size: 16, color: onSurfaceVariant),
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
