import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../models/habit.dart';
import '../providers/habit_provider.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final habits = ref.watch(habitNotifierProvider);
    final todayHabits = ref.watch(todayHabitsProvider);
    final stats = ref.watch(streakStatsProvider);

    // Calculate overall stats
    final int totalHabits = habits.length;
    double overallCompletionRate = 0.0;
    if (habits.isNotEmpty) {
      final totalRates = habits
          .map((h) => h.getCompletionRate())
          .reduce((a, b) => a + b);
      overallCompletionRate = totalRates / habits.length;
    }

    // Daily summary data:
    final completedToday = todayHabits
        .where((h) => h.isCompletedToday())
        .toList();
    final missedToday = todayHabits
        .where((h) => !h.isCompletedToday() && !h.isSkippedOn(DateTime.now()))
        .toList();
    final skippedToday = todayHabits
        .where((h) => h.isSkippedOn(DateTime.now()))
        .toList();
    final streaksMaintained = todayHabits
        .where((h) => h.currentStreak > 0)
        .toList();

    // Compile history logs: Map of Sanitized Date -> List of Completed Habits
    final Map<String, List<Habit>> historyMap = {};
    for (final habit in habits) {
      for (final rawDateStr in habit.completedDates) {
        // SANITIZATION GATEWAY: If string contains a split metadata tag, extract just the raw date component
        final String cleanDateStr = rawDateStr.contains('_split_')
            ? rawDateStr.split('_split_').first
            : rawDateStr;

        if (!historyMap.containsKey(cleanDateStr)) {
          historyMap[cleanDateStr] = [];
        }

        // Prevent duplicate habit chip listings under the exact same daily block map array
        if (!historyMap[cleanDateStr]!.contains(habit)) {
          historyMap[cleanDateStr]!.add(habit);
        }
      }
    }

    // Sort history dates in descending order
    final sortedDates = historyMap.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(title: const Text("Statistics & Report")),
      body: totalHabits == 0
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No data available",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Create habits and complete them to view stats!",
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Top Metrics Cards
                _buildMetricsOverview(theme, overallCompletionRate, stats),
                const SizedBox(height: 28),

                // Daily Summary Report Card
                Text(
                  "Today's Coach Report",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDailyReport(
                  theme,
                  completedToday,
                  streaksMaintained,
                  missedToday,
                  skippedToday,
                ),
                const SizedBox(height: 28),

                // Completion History Logs
                const Text(
                  "Completion Timeline Log",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (sortedDates.isEmpty)
                  _buildNoHistoryCard()
                else
                  ...sortedDates.take(10).map((dateStr) {
                    // SAFE EXECUTION: The date string is completely sanitized here, avoiding FormatException crashes
                    final date = DateTime.parse(dateStr);
                    final completedHabits = historyMap[dateStr]!;
                    return _buildHistoryItem(theme, date, completedHabits);
                  }),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildMetricsOverview(
    ThemeData theme,
    double completionRate,
    StreakStats stats,
  ) {
    final successPercent = (completionRate * 100).toInt();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Success Rate",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                          Icon(
                            Icons.insights_rounded,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "$successPercent%",
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Lifetime completion avg",
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Active Streaks",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                          Icon(
                            Icons.local_fire_department_rounded,
                            color: Colors.orange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "${stats.activeStreaksCount}",
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Habits currently on streak",
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDailyReport(
    ThemeData theme,
    List<Habit> completed,
    List<Habit> streaks,
    List<Habit> missed,
    List<Habit> skipped,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Completed Habits
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Habits Completed: ${completed.length}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            if (completed.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 34, top: 4, bottom: 12),
                child: Text(
                  completed.map((h) => h.title).join(", "),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(left: 34, top: 4, bottom: 12),
                child: Text(
                  "None completed yet today.",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),

            const Divider(),
            const SizedBox(height: 8),

            // 2. Streaks Maintained
            Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.orange,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Streaks Maintained: ${streaks.length}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            if (streaks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 34, top: 4, bottom: 12),
                child: Text(
                  streaks
                      .map((h) => "${h.title} (${h.currentStreak}d)")
                      .join(", "),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(left: 34, top: 4, bottom: 12),
                child: Text(
                  "No active streaks today.",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),

            const Divider(),
            const SizedBox(height: 8),

            Row(
              children: [
                Icon(
                  Icons.fast_forward_rounded,
                  color: skipped.isEmpty ? Colors.grey : Colors.blue.shade400,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Skipped Today: ${skipped.length}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            if (skipped.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 34, top: 4, bottom: 12),
                child: Text(
                  skipped.map((h) => h.title).join(", "),
                  style: TextStyle(color: Colors.blue.shade300, fontSize: 13),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(left: 34, top: 4, bottom: 12),
                child: Text(
                  "No skipped habits today.",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),

            const Divider(),
            const SizedBox(height: 8),

            // 3. Missed Tasks
            Row(
              children: [
                Icon(
                  Icons.cancel_rounded,
                  color: missed.isEmpty ? Colors.grey : Colors.red.shade400,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Missed/Pending: ${missed.length}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            if (missed.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 34, top: 4),
                child: Text(
                  missed.map((h) => h.title).join(", "),
                  style: TextStyle(color: Colors.red.shade300, fontSize: 13),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(left: 34, top: 4),
                child: Text(
                  "Amazing! No pending or missed tasks for today.",
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoHistoryCard() {
    return Card(
      elevation: 0,
      color: Colors.grey.withValues(alpha: 0.05),
      child: const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            "No completion logs found. Complete a habit to add entries here!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(
    ThemeData theme,
    DateTime date,
    List<Habit> completedHabits,
  ) {
    final dateString = DateFormat('MMMM dd, yyyy').format(date);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateString,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: completedHabits.map((habit) {
                final categoryColor = AppConstants.getCategoryColor(
                  habit.category,
                );
                return Chip(
                  avatar: Icon(
                    AppConstants.getCategoryIcon(habit.category),
                    color: categoryColor,
                    size: 14,
                  ),
                  label: Text(
                    habit.title,
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: categoryColor.withValues(alpha: 0.08),
                  side: BorderSide(color: categoryColor.withValues(alpha: 0.2)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 0,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
