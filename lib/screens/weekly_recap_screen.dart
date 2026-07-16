import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/habit.dart';
import '../providers/habit_provider.dart';

class WeeklyRecapScreen extends ConsumerWidget {
  const WeeklyRecapScreen({super.key});

  DateTime _weekStart(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  bool _isWithinWeek(String dateEntry, DateTime start) {
    final rawDate = dateEntry.split('_split_').first;
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return false;
    final normalized = DateTime(parsed.year, parsed.month, parsed.day);
    return !normalized.isBefore(start) &&
        normalized.isBefore(start.add(const Duration(days: 7)));
  }

  String _shareText({
    required int completions,
    required int activeDays,
    required int freezes,
    required Habit? bestHabit,
    required int bestStreak,
  }) {
    final bestLine = bestHabit == null
        ? 'Best habit: not started yet'
        : 'Best habit: ${bestHabit.title} ($bestStreak day streak)';
    return [
      'My StreakMind weekly recap',
      '$completions habit completions',
      '$activeDays active days',
      '$freezes streak freezes protected',
      bestLine,
    ].join('\n');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final habits = ref.watch(habitNotifierProvider);
    final start = _weekStart(DateTime.now());
    final end = start.add(const Duration(days: 6));
    final range =
        '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d').format(end)}';

    final weeklyCompletions = habits.fold<int>(
      0,
      (total, habit) =>
          total +
          habit.completedDates
              .where((date) => _isWithinWeek(date, start))
              .length,
    );
    final activeDays = {
      for (final habit in habits)
        for (final date in habit.completedDates)
          if (_isWithinWeek(date, start)) date.split('_split_').first,
    }.length;
    final weeklyFreezes = habits.fold<int>(
      0,
      (total, habit) =>
          total +
          habit.freezeDates.where((date) => _isWithinWeek(date, start)).length,
    );
    final bestHabit = habits.isEmpty
        ? null
        : habits.reduce((a, b) => a.currentStreak >= b.currentStreak ? a : b);
    final bestStreak = bestHabit?.currentStreak ?? 0;
    final shareText = _shareText(
      completions: weeklyCompletions,
      activeDays: activeDays,
      freezes: weeklyFreezes,
      bestHabit: bestHabit,
      bestStreak: bestStreak,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Recap')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            elevation: 0,
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    range,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.72,
                      ),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    weeklyCompletions == 0
                        ? 'Start logging to build your recap.'
                        : '$weeklyCompletions completions this week',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _MetricPill(
                        icon: Icons.calendar_today_rounded,
                        label: '$activeDays active days',
                      ),
                      _MetricPill(
                        icon: Icons.shield_rounded,
                        label: '$weeklyFreezes freezes',
                      ),
                      _MetricPill(
                        icon: Icons.local_fire_department_rounded,
                        label: '$bestStreak best streak',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (bestHabit != null)
            Card(
              elevation: 0,
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.emoji_events_rounded),
                ),
                title: const Text('Best Habit'),
                subtitle: Text(bestHabit.title),
                trailing: Text(
                  '${bestHabit.currentStreak}d',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Share Card',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    shareText,
                    style: TextStyle(
                      height: 1.45,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy Share Card'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: shareText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Recap copied.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetricPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
