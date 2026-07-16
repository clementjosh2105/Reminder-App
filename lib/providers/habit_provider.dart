import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/habit.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/motivation_service.dart';
import '../services/admob_service.dart';
import 'leaderboard_provider.dart';
import 'settings_provider.dart';
import 'social_provider.dart';

// ============================================================================
// GLOBAL CORE INFRASTRUCTURE PROVIDERS
// ============================================================================
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);
final motivationServiceProvider = Provider<MotivationService>(
  (ref) => MotivationService(),
);

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError(
    'storageServiceProvider must be overridden inside main.dart',
  );
});

final admobServiceProvider = Provider<AdMobService>((ref) {
  throw UnimplementedError(
    'admobServiceProvider must be overridden inside main.dart',
  );
});

class HabitNotifier extends StateNotifier<List<Habit>> {
  final Ref _ref;

  HabitNotifier(this._ref) : super([]) {
    loadHabits();
  }

  bool _isScheduledOn(Habit habit, DateTime date) {
    if (!habit.isEnabled) return false;
    final weekday = date.weekday;
    switch (habit.recurrenceType) {
      case 'Once':
        final creationDay = DateTime(
          habit.createdAt.year,
          habit.createdAt.month,
          habit.createdAt.day,
        );
        final targetDay = DateTime(date.year, date.month, date.day);
        return creationDay.isAtSameMomentAs(targetDay);
      case 'Daily':
      case 'Hourly':
      case 'CustomInterval':
        return true;
      case 'Weekdays':
        return weekday >= 1 && weekday <= 5;
      case 'Weekends':
        return weekday == 6 || weekday == 7;
      case 'CustomDays':
        return habit.customDays.contains(weekday);
      default:
        return false;
    }
  }

  DateTime? _getLastScheduledDateBeforeToday(Habit habit) {
    final now = DateTime.now();
    DateTime checkDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));
    final creationDate = DateTime(
      habit.createdAt.year,
      habit.createdAt.month,
      habit.createdAt.day,
    );

    int loopCount = 0;
    while ((checkDate.isAfter(creationDate) ||
            checkDate.isAtSameMomentAs(creationDate)) &&
        loopCount < 365) {
      if (habit.recurrenceType == 'CustomInterval' ||
          habit.recurrenceType == 'Hourly') {
        return null;
      }
      if (_isScheduledOn(habit, checkDate)) {
        return checkDate;
      }
      checkDate = checkDate.subtract(const Duration(days: 1));
      loopCount++;
    }
    return null;
  }

  Future<void> loadHabits() async {
    final storage = _ref.read(storageServiceProvider);
    final list = storage.getHabits();

    final updatedList = <Habit>[];
    for (final habit in list) {
      if (habit.recurrenceType == 'CustomInterval' ||
          habit.recurrenceType == 'Hourly') {
        try {
          if (Hive.isBoxOpen('settings_box_v1')) {
            final box = Hive.box('settings_box_v1');
            final fireTime = box.get('interval_fire_time_${habit.id}') as int?;
            if (fireTime != null) {
              final fireDateTime = DateTime.fromMillisecondsSinceEpoch(
                fireTime,
              );
              final now = DateTime.now();
              if (fireDateTime.day != now.day ||
                  fireDateTime.month != now.month ||
                  fireDateTime.year != now.year) {
                await box.delete('interval_fire_time_${habit.id}');
                if (habit.currentStreak > 0) {
                  final updatedHabit = habit.copyWith(currentStreak: 0);
                  await storage.saveHabit(updatedHabit);
                  updatedList.add(updatedHabit);
                  continue;
                }
              }
            }
          }
        } catch (_) {}
      }

      if (habit.isEnabled &&
          habit.currentStreak > 0 &&
          habit.recurrenceType != 'CustomInterval' &&
          habit.recurrenceType != 'Hourly') {
        final lastScheduled = _getLastScheduledDateBeforeToday(habit);
        if (lastScheduled != null) {
          final lastScheduledStr = DateFormat(
            'yyyy-MM-dd',
          ).format(lastScheduled);
          if (!habit.completedDates.contains(lastScheduledStr) &&
              !habit.skippedDates.contains(lastScheduledStr)) {
            final shouldUseFreeze = !habit.hasFreezeInWeek(lastScheduled);
            final updatedHabit = shouldUseFreeze
                ? habit.copyWith(
                    freezeDates: [...habit.freezeDates, lastScheduledStr],
                  )
                : habit.copyWith(currentStreak: 0);
            await storage.saveHabit(updatedHabit);
            updatedList.add(updatedHabit);
            continue;
          }
        }
      }
      updatedList.add(habit);
    }

    state = updatedList;
  }

  Future<void> addHabit(Habit habit) async {
    await _ref.read(storageServiceProvider).saveHabit(habit);
    state = [...state, habit];
    _syncLeaderboardScore();
    await _rescheduleHabitNotification(habit);
  }

  Future<void> updateHabit(Habit habit) async {
    await _ref.read(storageServiceProvider).saveHabit(habit);
    state = [
      for (final item in state)
        if (item.id == habit.id) habit else item,
    ];
    _syncLeaderboardScore();
    await _rescheduleHabitNotification(habit);
  }

  Future<void> deleteHabit(String id) async {
    final habitToDelete = state.firstWhere((h) => h.id == id);
    final notificationService = _ref.read(notificationServiceProvider);
    await notificationService.cancelHabit(
      habitToDelete.notificationId,
      habitToDelete.recurrenceType,
      habitToDelete.customDays.length,
    );

    await _ref.read(storageServiceProvider).deleteHabit(id);
    state = state.where((h) => h.id != id).toList();
    _syncLeaderboardScore();
  }

  Future<void> toggleHabit(String id) async {
    final oldHabit = state.firstWhere((h) => h.id == id);
    final updatedHabit = oldHabit.copyWith(isEnabled: !oldHabit.isEnabled);
    await _ref.read(storageServiceProvider).saveHabit(updatedHabit);

    state = [
      for (final item in state)
        if (item.id == id) updatedHabit else item,
    ];
    _syncLeaderboardScore();

    final notificationService = _ref.read(notificationServiceProvider);
    if (updatedHabit.isEnabled) {
      await _rescheduleHabitNotification(updatedHabit);
    } else {
      await notificationService.cancelHabit(
        updatedHabit.notificationId,
        updatedHabit.recurrenceType,
        updatedHabit.customDays.length,
      );
    }
  }

  Future<void> resetCustomIntervalStreak(String id) async {
    final habit = state.firstWhere((h) => h.id == id);
    if (habit.currentStreak == 0) return;

    final updatedHabit = habit.copyWith(currentStreak: 0);
    await _ref.read(storageServiceProvider).saveHabit(updatedHabit);

    // PERSIST THE BREAK STATE TO DISK: Remember this chain is broken across restarts
    try {
      if (Hive.isBoxOpen('settings_box_v1')) {
        final box = Hive.box('settings_box_v1');
        await box.put('interval_chain_broken_$id', true);
        await box.delete('interval_fire_time_$id'); // Safe to clean up now
      }
    } catch (_) {}

    state = [
      for (final h in state)
        if (h.id == id) updatedHabit else h,
    ];
    _syncLeaderboardScore();
  }

  Future<void> restartCustomInterval(String id) async {
    final habit = state.firstWhere((h) => h.id == id);
    final updatedHabit = habit.copyWith(currentStreak: 0);
    await _ref.read(storageServiceProvider).saveHabit(updatedHabit);

    // REMOVE THE BREAK STATE FROM DISK: The chain is reset, clear the flag
    try {
      if (Hive.isBoxOpen('settings_box_v1')) {
        final box = Hive.box('settings_box_v1');
        await box.delete('interval_chain_broken_$id');
        await box.delete('interval_fire_time_$id');
      }
    } catch (_) {}

    state = [
      for (final h in state)
        if (h.id == id) updatedHabit else h,
    ];
    _syncLeaderboardScore();
    await _rescheduleHabitNotification(updatedHabit);
  }

  Future<void> resetMissedHabitStats(String id) async {
    final habit = state.firstWhere((h) => h.id == id);
    final storage = _ref.read(storageServiceProvider);
    await storage.resetIntervalCount(id);

    final updatedHabit = habit.copyWith(currentStreak: 0);
    await _ref.read(storageServiceProvider).saveHabit(updatedHabit);

    try {
      if (Hive.isBoxOpen('settings_box_v1')) {
        final box = Hive.box('settings_box_v1');
        await box.put('interval_chain_broken_$id', true);
        await box.delete('interval_fire_time_$id');
      }
    } catch (_) {}

    state = [
      for (final h in state)
        if (h.id == id) updatedHabit else h,
    ];
    _syncLeaderboardScore();
    await _rescheduleHabitNotification(updatedHabit);
  }

  Future<void> completeHabit(String id, DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final habit = state.firstWhere((h) => h.id == id);

    final targetDateString = "${dateStr}_split_${DateTime.now().millisecondsSinceEpoch}";

    final updatedHabit = habit.copyWith(
      completedDates: [...habit.completedDates, targetDateString],
      skippedDates: habit.skippedDates.where((d) => d != dateStr).toList(),
      freezeDates: habit.freezeDates.where((d) => d != dateStr).toList(),
      currentStreak: habit.currentStreak + 1,
      longestStreak: (habit.currentStreak + 1) > habit.longestStreak
          ? (habit.currentStreak + 1)
          : habit.longestStreak,
    );

    // FIXED: Save back to persistence storage before updating UI arrays
    await _ref.read(storageServiceProvider).saveHabit(updatedHabit);

    state = [
      for (final h in state)
        if (h.id == id) updatedHabit else h,
    ];
    _syncLeaderboardScore();
    _publishHabitActivity(updatedHabit);

    final storage = _ref.read(storageServiceProvider);
    await storage.incrementIntervalCount(updatedHabit.id);
    await _rescheduleHabitNotification(updatedHabit);
  }

  Future<void> uncompleteHabit(String id, DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final habit = state.firstWhere((h) => h.id == id);

    List<String> cleanedDates = List<String>.from(habit.completedDates);
    if (cleanedDates.isNotEmpty) cleanedDates.removeLast();

    final updatedHabit = habit.copyWith(
      completedDates: cleanedDates,
      currentStreak: habit.currentStreak > 0 ? habit.currentStreak - 1 : 0,
    );

    // FIXED: Save back to persistence storage before updating UI arrays
    await _ref.read(storageServiceProvider).saveHabit(updatedHabit);

    state = [
      for (final h in state)
        if (h.id == id) updatedHabit else h,
    ];
    _syncLeaderboardScore();
  }

  Future<void> snoozeHabit(String id, [int? minutes]) async {
    final habit = state.firstWhere((h) => h.id == id);
    final snoozeMinutes = minutes ?? _ref.read(settingsProvider).snoozeDuration;
    final motivationMessage = _ref
        .read(motivationServiceProvider)
        .generateMessage(
          category: habit.category,
          personality: _ref.read(settingsProvider).motivationPersonality,
          streak: habit.currentStreak,
          time: DateTime.now(),
        );

    _ref
        .read(notificationServiceProvider)
        .snooze(habit, snoozeMinutes, motivationMessage);
  }

  Future<void> skipHabit(String id) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final habit = state.firstWhere((h) => h.id == id);
    final isHighFrequency =
        habit.recurrenceType == 'CustomInterval' ||
        habit.recurrenceType == 'Hourly';

    final updatedSkippedDates =
        isHighFrequency || habit.skippedDates.contains(dateStr)
        ? habit.skippedDates
        : [...habit.skippedDates, dateStr];

    final updatedHabit = habit.copyWith(skippedDates: updatedSkippedDates);
    await _ref.read(storageServiceProvider).saveHabit(updatedHabit);

    state = [
      for (final h in state)
        if (h.id == id) updatedHabit else h,
    ];

    _syncLeaderboardScore();
    await _rescheduleHabitNotification(updatedHabit);
  }

  Future<void> _rescheduleHabitNotification(Habit habit) async {
    final notificationService = _ref.read(notificationServiceProvider);
    final motivationMessage = _ref
        .read(motivationServiceProvider)
        .generateMessage(
          category: habit.category,
          personality: _ref.read(settingsProvider).motivationPersonality,
          streak: habit.currentStreak,
          time: DateTime.now(),
        );
    await notificationService.scheduleHabit(habit, motivationMessage);
  }

  void _syncLeaderboardScore() {
    unawaited(
      _ref
          .read(leaderboardServiceProvider)
          .syncCurrentUserScore(state)
          .catchError((_) {}),
    );
  }

  void _publishHabitActivity(Habit habit) {
    unawaited(
      _ref
          .read(socialServiceProvider)
          .publishHabitActivity(
            habit: habit,
            shareActivityWithFriends: _ref
                .read(settingsProvider)
                .shareActivityWithFriends,
          )
          .catchError((_) {}),
    );
  }
}

final habitNotifierProvider = StateNotifierProvider<HabitNotifier, List<Habit>>(
  (ref) {
    return HabitNotifier(ref);
  },
);

final todayHabitsProvider = Provider<List<Habit>>((ref) {
  final allHabits = ref.watch(habitNotifierProvider);
  final currentWeekday = DateTime.now().weekday;

  return allHabits.where((habit) {
    if (!habit.isEnabled) return false;

    switch (habit.recurrenceType) {
      case 'Once':
        final today = DateTime.now();
        final created = habit.createdAt;
        return today.year == created.year &&
            today.month == created.month &&
            today.day == created.day;
      case 'Daily':
      case 'Hourly':
      case 'CustomInterval':
        return true;
      case 'Weekdays':
        return currentWeekday >= 1 && currentWeekday <= 5;
      case 'Weekends':
        return currentWeekday == 6 || currentWeekday == 7;
      case 'CustomDays':
        return habit.customDays.contains(currentWeekday);
      default:
        return false;
    }
  }).toList();
});

final todayCompletionRateProvider = Provider<double>((ref) {
  final todayHabits = ref.watch(todayHabitsProvider);
  if (todayHabits.isEmpty) return 0.0;

  final completedCount = todayHabits.where((h) => h.isCompletedToday()).length;
  return completedCount / todayHabits.length;
});

class StreakStats {
  final int currentStreak;
  final int longestStreak;
  final int activeStreaksCount;
  StreakStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.activeStreaksCount,
  });
}

final streakStatsProvider = Provider<StreakStats>((ref) {
  final allHabits = ref.watch(habitNotifierProvider);
  if (allHabits.isEmpty) {
    return StreakStats(
      currentStreak: 0,
      longestStreak: 0,
      activeStreaksCount: 0,
    );
  }

  int currentMax = 0;
  int longestMax = 0;
  int activeCount = 0;

  for (final habit in allHabits) {
    if (habit.currentStreak > currentMax) currentMax = habit.currentStreak;
    if (habit.longestStreak > longestMax) longestMax = habit.longestStreak;
    if (habit.currentStreak > 0) activeCount++;
  }

  return StreakStats(
    currentStreak: currentMax,
    longestStreak: longestMax,
    activeStreaksCount: activeCount,
  );
});
