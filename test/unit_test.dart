import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:momentum/core/constants.dart';
import 'package:momentum/models/habit.dart';
import 'package:momentum/services/motivation_service.dart';

void main() {
  group('AppConstants Tests', () {
    test('getCategoryIcon returns correct icons', () {
      expect(
        AppConstants.getCategoryIcon(AppConstants.catWater),
        Icons.local_drink_rounded,
      );
      expect(
        AppConstants.getCategoryIcon(AppConstants.catGym),
        Icons.fitness_center_rounded,
      );
      expect(
        AppConstants.getCategoryIcon(AppConstants.catCoding),
        Icons.code_rounded,
      );
      expect(
        AppConstants.getCategoryIcon('Unknown'),
        Icons.check_circle_outline_rounded,
      );
    });

    test('getCategoryColor returns correct colors', () {
      expect(AppConstants.getCategoryColor(AppConstants.catWater), Colors.blue);
      expect(
        AppConstants.getCategoryColor(AppConstants.catGym),
        Colors.deepOrange,
      );
      expect(AppConstants.getCategoryColor('Unknown'), Colors.grey);
    });
  });

  group('MotivationService Tests', () {
    final service = MotivationService();

    test(
      'generateMessage returns valid motivation message for Friendly style',
      () {
        final msg = service.generateMessage(
          category: AppConstants.catWater,
          personality: 'Friendly',
          streak: 0,
          time: DateTime(2026, 6, 25, 9, 0), // 9 AM
        );
        expect(msg, isNotEmpty);
        expect(msg, isA<String>());
      },
    );

    test('generateMessage returns strict warning for Strict personality', () {
      final msg = service.generateMessage(
        category: AppConstants.catGym,
        personality: 'Strict',
        streak: 2,
        time: DateTime(2026, 6, 25, 18, 0),
      );
      expect(msg, isNotEmpty);
      final lowerMsg = msg.toLowerCase();
      expect(
        lowerMsg.contains('excuses') ||
            lowerMsg.contains('sweat') ||
            lowerMsg.contains('show up') ||
            lowerMsg.contains('stop scrolling'),
        isTrue,
      );
    });

    test(
      'generateMessage returns high streak message when streak is large',
      () {
        final msg = service.generateMessage(
          category: AppConstants.catCoding,
          personality: 'Professional',
          streak: 10,
          time: DateTime(2026, 6, 25, 14, 0),
        );
        expect(msg.contains('10-day streak'), isTrue);
      },
    );
  });

  group('Habit model date helpers', () {
    Habit buildHabit({
      List<String> completedDates = const [],
      List<String> skippedDates = const [],
      List<String> freezeDates = const [],
      DateTime? createdAt,
    }) {
      return Habit(
        id: 'habit-1',
        title: 'Drink water',
        description: '',
        category: AppConstants.catWater,
        timeOfDay: '08:00',
        recurrenceType: 'Daily',
        notificationId: 1,
        createdAt: createdAt ?? DateTime(2026, 7, 1),
        completedDates: completedDates,
        skippedDates: skippedDates,
        freezeDates: freezeDates,
      );
    }

    test('isCompletedOn only checks the requested date', () {
      final habit = buildHabit(completedDates: ['2026-07-02']);

      expect(habit.isCompletedOn(DateTime(2026, 7, 2)), isTrue);
      expect(habit.isCompletedOn(DateTime(2026, 7, 3)), isFalse);
    });

    test('isCompletedOn supports interval completion entries', () {
      final habit = buildHabit(
        completedDates: ['2026-07-03_split_1783075200000'],
      );

      expect(habit.isCompletedOn(DateTime(2026, 7, 3)), isTrue);
      expect(habit.isCompletedOn(DateTime(2026, 7, 4)), isFalse);
    });

    test('isSkippedOn reads persisted skip dates', () {
      final habit = buildHabit(skippedDates: ['2026-07-03']);

      expect(habit.isSkippedOn(DateTime(2026, 7, 3)), isTrue);
      expect(habit.isSkippedOn(DateTime(2026, 7, 4)), isFalse);
    });

    test('hasFreezeInWeek detects one protected miss per week', () {
      final habit = buildHabit(freezeDates: ['2026-07-01']);

      expect(habit.hasFreezeInWeek(DateTime(2026, 7, 3)), isTrue);
      expect(habit.hasFreezeInWeek(DateTime(2026, 7, 8)), isFalse);
    });
  });
}
