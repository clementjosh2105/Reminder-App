import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/habit_templates.dart';
import '../models/habit.dart';
import '../providers/habit_provider.dart';

class TemplatePacksScreen extends ConsumerWidget {
  const TemplatePacksScreen({super.key});

  Future<void> _addPack(
    BuildContext context,
    WidgetRef ref,
    HabitTemplatePack pack,
  ) async {
    final notifier = ref.read(habitNotifierProvider.notifier);
    final now = DateTime.now();

    for (var i = 0; i < pack.habits.length; i++) {
      final template = pack.habits[i];
      final id = '${now.microsecondsSinceEpoch}_$i';
      await notifier.addHabit(
        Habit(
          id: id,
          title: template.title,
          description: template.description,
          category: template.category,
          timeOfDay: template.timeOfDay,
          recurrenceType: template.recurrenceType,
          notificationId: now.millisecondsSinceEpoch.remainder(1000000) + i,
          createdAt: now,
        ),
      );
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${pack.name} added.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Template Packs')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final pack = habitTemplatePacks[index];
          return Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pack.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              pack.description,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.62,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final habit in pack.habits)
                        Chip(
                          avatar: Icon(
                            AppConstants.getCategoryIcon(habit.category),
                            size: 16,
                            color: AppConstants.getCategoryColor(
                              habit.category,
                            ),
                          ),
                          label: Text(habit.title),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _addPack(context, ref, pack),
                      icon: const Icon(Icons.add_task_rounded),
                      label: Text('Add ${pack.habits.length} Habits'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemCount: habitTemplatePacks.length,
      ),
    );
  }
}
