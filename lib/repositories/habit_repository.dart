import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/habit.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/motivation_service.dart';
import '../services/admob_service.dart';

class HabitRepository {
  final StorageService _storageService;
  final NotificationService _notificationService;
  final MotivationService _motivationService;
  final AdMobService _adMobService;

  HabitRepository({
    required StorageService storageService,
    required NotificationService notificationService,
    required MotivationService motivationService,
    required AdMobService admobService,
  }) : _storageService = storageService,
       _notificationService = notificationService,
       _motivationService = motivationService,
       _adMobService = admobService;

  List<Habit> getHabits() {
    return _storageService.getHabits();
  }

  // Add or update a habit
  Future<void> saveHabit(Habit habit) async {
    // 1. Save in Hive
    await _storageService.saveHabit(habit);

    // 2. Schedule notifications if enabled
    if (habit.isEnabled) {
      final motivationMsg = _motivationService.generateMessage(
        category: habit.category,
        personality: _storageService.getMotivationPersonality(),
        streak: habit.currentStreak,
        time: DateTime.now(),
      );
      await _notificationService.scheduleHabit(habit, motivationMsg);
    } else {
      await _notificationService.cancelHabit(
        habit.notificationId,
        habit.recurrenceType,
        habit.customDays.length,
      );
    }
  }

  // Toggle habit enable/disable
  Future<void> toggleHabit(String id) async {
    final habits = getHabits();
    final habitIndex = habits.indexWhere((h) => h.id == id);
    if (habitIndex == -1) return;

    final habit = habits[habitIndex];
    final updatedHabit = habit.copyWith(isEnabled: !habit.isEnabled);

    await saveHabit(updatedHabit);
  }

  // Delete a habit
  Future<void> deleteHabit(String id) async {
    final habits = getHabits();
    final habit = habits.firstWhere((h) => h.id == id);

    // 1. Cancel notifications
    await _notificationService.cancelHabit(
      habit.notificationId,
      habit.recurrenceType,
      habit.customDays.length,
    );

    // 2. Delete from Hive
    await _storageService.deleteHabit(id);
  }

  // Complete habit for a specific date (usually today)
  Future<void> completeHabit(String id, DateTime date) async {
    final habits = getHabits();
    final habitIndex = habits.indexWhere((h) => h.id == id);
    if (habitIndex == -1) return;

    final habit = habits[habitIndex];
    final dateString = _formatDate(date);

    // Avoid duplicate completions for the same day
    if (habit.completedDates.contains(dateString)) return;

    final updatedCompletedDates = List<String>.from(habit.completedDates)
      ..add(dateString);

    // Recalculate streaks
    final int newStreak = _calculateStreak(
      updatedCompletedDates,
      habit.skippedDates.where((d) => d != dateString).toList(),
      habit.recurrenceType,
      habit.customDays,
    );

    final int newLongestStreak = max(habit.longestStreak, newStreak);

    final updatedHabit = habit.copyWith(
      completedDates: updatedCompletedDates,
      skippedDates: habit.skippedDates.where((d) => d != dateString).toList(),
      currentStreak: newStreak,
      longestStreak: newLongestStreak,
    );

    // Save changes
    await _storageService.saveHabit(updatedHabit);

    // Update notifications with a potentially new streak message
    if (updatedHabit.isEnabled) {
      final motivationMsg = _motivationService.generateMessage(
        category: updatedHabit.category,
        personality: _storageService.getMotivationPersonality(),
        streak: newStreak,
        time: DateTime.now(),
      );
      await _notificationService.scheduleHabit(updatedHabit, motivationMsg);
    }

    // Trigger AdMob interstitial ad occasionally with a 20-minute cooldown
    await _showInterstitialAdWithCooldown();
  }

  // Uncomplete habit for a specific date (usually today)
  Future<void> uncompleteHabit(String id, DateTime date) async {
    final habits = getHabits();
    final habitIndex = habits.indexWhere((h) => h.id == id);
    if (habitIndex == -1) return;

    final habit = habits[habitIndex];
    final dateString = _formatDate(date);

    if (!habit.completedDates.contains(dateString)) return;

    final updatedCompletedDates = List<String>.from(habit.completedDates)
      ..remove(dateString);

    // Recalculate streaks
    final int newStreak = _calculateStreak(
      updatedCompletedDates,
      habit.skippedDates,
      habit.recurrenceType,
      habit.customDays,
    );

    final updatedHabit = habit.copyWith(
      completedDates: updatedCompletedDates,
      currentStreak: newStreak,
    );

    // Save changes
    await _storageService.saveHabit(updatedHabit);

    // Reschedule reminder notifications
    if (updatedHabit.isEnabled) {
      final motivationMsg = _motivationService.generateMessage(
        category: updatedHabit.category,
        personality: _storageService.getMotivationPersonality(),
        streak: newStreak,
        time: DateTime.now(),
      );
      await _notificationService.scheduleHabit(updatedHabit, motivationMsg);
    }
  }

  // Snooze habit for a reminder duration (10 min)
  Future<void> snoozeHabit(String id, int minutes) async {
    final habits = getHabits();
    final habit = habits.firstWhere((h) => h.id == id);

    final motivationMsg = _motivationService.generateMessage(
      category: habit.category,
      personality: _storageService.getMotivationPersonality(),
      streak: habit.currentStreak,
      time: DateTime.now(),
    );

    await _notificationService.snooze(habit, minutes, motivationMsg);
  }

  // Skip habit for today
  Future<void> skipHabit(String id) async {
    final habits = getHabits();
    final habit = habits.firstWhere((h) => h.id == id);
    final today = _formatDate(DateTime.now());
    final isHighFrequency =
        habit.recurrenceType == 'CustomInterval' ||
        habit.recurrenceType == 'Hourly';

    final updatedHabit = isHighFrequency || habit.skippedDates.contains(today)
        ? habit
        : habit.copyWith(skippedDates: [...habit.skippedDates, today]);

    if (!identical(updatedHabit, habit)) {
      await _storageService.saveHabit(updatedHabit);
    }

    if (updatedHabit.isEnabled) {
      final motivationMsg = _motivationService.generateMessage(
        category: updatedHabit.category,
        personality: _storageService.getMotivationPersonality(),
        streak: updatedHabit.currentStreak,
        time: DateTime.now(),
      );
      await _notificationService.scheduleHabit(updatedHabit, motivationMsg);
    }

    await _showInterstitialAdWithCooldown();
  }

  // Reschedule all active notifications (run on app startup or system reboot)
  Future<void> rescheduleAllActiveReminders() async {
    final habits = getHabits();
    for (final habit in habits) {
      if (habit.isEnabled) {
        final motivationMsg = _motivationService.generateMessage(
          category: habit.category,
          personality: _storageService.getMotivationPersonality(),
          streak: habit.currentStreak,
          time: DateTime.now(),
        );
        await _notificationService.scheduleHabit(habit, motivationMsg);
      }
    }
  }

  // --- STREAK CALCULATION ALGORITHM ---

  int _calculateStreak(
    List<String> completedDates,
    List<String> skippedDates,
    String recurrenceType,
    List<int> customDays,
  ) {
    if (completedDates.isEmpty) return 0;

    final completedSet = completedDates.toSet();
    final skippedSet = skippedDates.toSet();
    int streak = 0;
    DateTime checkDate = DateTime.now();

    // If today is a scheduled day but not completed, we check if yesterday was completed.
    // If today is completed, we start checking from today.
    final todayStr = _formatDate(checkDate);

    final bool todayIsScheduled = _isScheduledOn(
      checkDate,
      recurrenceType,
      customDays,
    );
    final bool todayIsCompleted = completedSet.contains(todayStr);

    if (todayIsScheduled &&
        !todayIsCompleted &&
        !skippedSet.contains(todayStr)) {
      // Habit has not been completed today yet.
      // Check if yesterday was completed (if yesterday was scheduled).
      // If yesterday was scheduled and not completed, streak is 0.
      // So we set our starting date to yesterday to start counting backwards.
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    int safetyCounter = 365; // Max check 1 year back
    while (safetyCounter > 0) {
      final bool isScheduled = _isScheduledOn(
        checkDate,
        recurrenceType,
        customDays,
      );
      if (isScheduled) {
        final dateStr = _formatDate(checkDate);
        if (completedSet.contains(dateStr)) {
          streak++;
        } else if (skippedSet.contains(dateStr)) {
          // Skipped scheduled days do not add to the streak and do not break it.
        } else {
          // Streak broken
          break;
        }
      }
      checkDate = checkDate.subtract(const Duration(days: 1));
      safetyCounter--;
    }

    return streak;
  }

  bool _isScheduledOn(
    DateTime date,
    String recurrenceType,
    List<int> customDays,
  ) {
    switch (recurrenceType) {
      case 'Once':
        return true;
      case 'Daily':
      case 'Hourly':
        return true;
      case 'Weekdays':
        return date.weekday >= 1 && date.weekday <= 5;
      case 'Weekends':
        return date.weekday == 6 || date.weekday == 7;
      case 'CustomDays':
        return customDays.contains(date.weekday);
      default:
        return true;
    }
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  // Show Interstitial ad with a persistent 20-minute cooldown limit
  Future<void> _showInterstitialAdWithCooldown() async {
    if (!_storageService.getShowAds()) return;

    final lastShown = _storageService.getLastInterstitialShownTime();
    final now = DateTime.now();

    if (lastShown != null && now.difference(lastShown).inMinutes < 20) {
      debugPrint(
        "Skipping Interstitial ad: 20-minute cooldown active (last shown ${now.difference(lastShown).inMinutes} mins ago).",
      );
      return;
    }

    final shown = _adMobService.showInterstitialAd();
    if (shown) {
      await _storageService.setLastInterstitialShownTime(now);
    }
  }
}
