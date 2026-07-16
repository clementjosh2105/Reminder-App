import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

part 'habit.g.dart';

@HiveType(typeId: 0)
class Habit extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final String category;

  @HiveField(4)
  final String timeOfDay;

  @HiveField(5)
  final String recurrenceType;

  @HiveField(6)
  final List<int> customDays;

  @HiveField(7)
  final int hourlyInterval; // Matches fields[7]

  @HiveField(8)
  final bool isEnabled; // Matches fields[8]

  @HiveField(9)
  final int notificationId; // Matches fields[9]

  @HiveField(10)
  final DateTime createdAt; // Matches fields[10]

  @HiveField(11)
  final List<String> completedDates; // Matches fields[11]

  @HiveField(12)
  final int currentStreak; // Matches fields[12]

  @HiveField(13)
  final int longestStreak; // Matches fields[13]

  @HiveField(14)
  final int intervalSeconds; // Custom interval in seconds (e.g. 30s, 5min). 0 = unused.

  @HiveField(15)
  final List<String> skippedDates;

  @HiveField(16)
  final List<String> freezeDates;

  Habit({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.timeOfDay,
    required this.recurrenceType,
    this.customDays = const [],
    this.hourlyInterval = 2,
    this.isEnabled = true, // Defaults perfectly to true
    required this.notificationId,
    required this.createdAt,
    this.completedDates = const [],
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.intervalSeconds = 0,
    this.skippedDates = const [],
    this.freezeDates = const [],
  });

  bool isCompletedToday() {
    return isCompletedOn(DateTime.now());
  }

  bool isCompletedOn(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return completedDates.any((dateEntry) => dateEntry.startsWith(dateStr));
  }

  bool isSkippedOn(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return skippedDates.contains(dateStr);
  }

  bool isFrozenOn(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return freezeDates.contains(dateStr);
  }

  bool hasFreezeInWeek(DateTime date) {
    final weekStart = date.subtract(Duration(days: date.weekday - 1));
    final normalizedWeekStart = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );
    final weekEnd = normalizedWeekStart.add(const Duration(days: 7));

    return freezeDates.any((dateEntry) {
      final parsed = DateTime.tryParse(dateEntry);
      if (parsed == null) return false;
      final normalized = DateTime(parsed.year, parsed.month, parsed.day);
      return !normalized.isBefore(normalizedWeekStart) &&
          normalized.isBefore(weekEnd);
    });
  }

  double getCompletionRate() {
    if (completedDates.isEmpty) return 0.0;
    final totalDaysActive = DateTime.now().difference(createdAt).inDays + 1;
    if (totalDaysActive <= 0) return 0.0;
    final rate = completedDates.length / totalDaysActive;
    return rate > 1.0 ? 1.0 : rate; // Cap at 100% maximum range
  }

  Habit copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? timeOfDay,
    String? recurrenceType,
    List<int>? customDays,
    int? hourlyInterval,
    bool? isEnabled,
    int? notificationId,
    DateTime? createdAt,
    List<String>? completedDates,
    int? currentStreak,
    int? longestStreak,
    int? intervalSeconds,
    List<String>? skippedDates,
    List<String>? freezeDates,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      customDays: customDays ?? this.customDays,
      hourlyInterval: hourlyInterval ?? this.hourlyInterval,
      isEnabled: isEnabled ?? this.isEnabled,
      notificationId: notificationId ?? this.notificationId,
      createdAt: createdAt ?? this.createdAt,
      completedDates: completedDates ?? this.completedDates,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      skippedDates: skippedDates ?? this.skippedDates,
      freezeDates: freezeDates ?? this.freezeDates,
    );
  }
}
