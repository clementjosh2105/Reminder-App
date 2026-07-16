import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/constants.dart';
import '../models/habit.dart';
import '../providers/habit_provider.dart';
import '../services/notification_service.dart';
import 'create_edit_habit_screen.dart';
import 'template_packs_screen.dart';

class HabitListScreen extends ConsumerWidget {
  const HabitListScreen({super.key});

  void _showDeleteConfirmDialog(
    BuildContext context,
    WidgetRef ref,
    Habit habit,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Tracker"),
          content: Text(
            "Are you sure you want to delete '${habit.title}'? This will erase all its history and streaks.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final ns = NotificationService();
                await ns.cancelHabit(
                  habit.notificationId,
                  habit.recurrenceType,
                  habit.customDays.length,
                );

                try {
                  final box = Hive.isBoxOpen('settings_box_v1')
                      ? Hive.box('settings_box_v1')
                      : await Hive.openBox('settings_box_v1');
                  await box.delete('interval_fire_time_${habit.id}');
                } catch (_) {}

                ref.read(habitNotifierProvider.notifier).deleteHabit(habit.id);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Tracker entry deleted"),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final habits = ref.watch(habitNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Habits & Focus Trackers"),
        actions: [
          IconButton(
            tooltip: 'Templates',
            icon: const Icon(Icons.auto_awesome_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TemplatePacksScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CreateEditHabitScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: habits.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.library_add_rounded,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No schedules configured yet",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Create your first reminder to start consistency coaching!",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TemplatePacksScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text("Use a Template Pack"),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CreateEditHabitScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text("Add Tracker"),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: habits.length,
              itemBuilder: (context, index) {
                final habit = habits[index];
                return _buildHabitCard(context, ref, theme, habit);
              },
            ),
    );
  }

  Widget _buildHabitCard(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    Habit habit,
  ) {
    final categoryColor = AppConstants.getCategoryColor(habit.category);
    final isEnabled = habit.isEnabled;
    final isCustomInterval = habit.recurrenceType == 'CustomInterval';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isEnabled
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : theme.colorScheme.onSurface.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      color: isEnabled
          ? theme.colorScheme.surface
          : theme.colorScheme.surface.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppConstants.getCategoryIcon(habit.category),
              color: isEnabled
                  ? categoryColor
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  isCustomInterval && habit.currentStreak > 0
                      ? "${habit.title} (${habit.currentStreak})"
                      : habit.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isEnabled
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  habit.category,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: categoryColor,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                habit.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        habit.recurrenceType == 'Hourly'
                            ? "Every ${habit.hourlyInterval} hrs starting at ${habit.timeOfDay}"
                            : isCustomInterval
                            ? "Every ${habit.intervalSeconds >= 60 ? '${habit.intervalSeconds ~/ 60}m' : '${habit.intervalSeconds}s'}"
                            : "${habit.timeOfDay} - ${habit.recurrenceType}",
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 14,
                        color: Colors.orange.shade600,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        isCustomInterval
                            ? "${habit.currentStreak} splits hit"
                            : "${habit.currentStreak}d streak",
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: isEnabled,
                onChanged: (value) async {
                  ref
                      .read(habitNotifierProvider.notifier)
                      .toggleHabit(habit.id);

                  if (!value) {
                    final ns = NotificationService();
                    await ns.cancelHabit(
                      habit.notificationId,
                      habit.recurrenceType,
                      habit.customDays.length,
                    );
                    try {
                      final box = Hive.isBoxOpen('settings_box_v1')
                          ? Hive.box('settings_box_v1')
                          : await Hive.openBox('settings_box_v1');
                      await box.delete('interval_fire_time_${habit.id}');
                    } catch (_) {}
                  } else {
                    if (habit.recurrenceType == 'CustomInterval') {
                      final ns = NotificationService();
                      await ns.scheduleHabit(
                        habit,
                        "Time to pick up your interval sessions!",
                      );
                    }
                  }
                },
              ),
              PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'edit') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CreateEditHabitScreen(habit: habit),
                      ),
                    );
                  } else if (action == 'delete') {
                    _showDeleteConfirmDialog(context, ref, habit);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 20),
                        SizedBox(width: 8),
                        Text("Edit"),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_rounded, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text("Delete", style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
