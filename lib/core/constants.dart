import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'StreakMind';

  // Habit Categories
  static const String catWater = 'Drink water';
  static const String catGym = 'Hit the gym';
  static const String catCoding = 'Start coding';
  static const String catBreak = 'Take breaks';
  static const String catStudy = 'Study';
  static const String catRead = 'Read books';
  static const String catSleep = 'Sleep on time';
  static const String catCustom = 'Custom';

  static const List<String> categories = [
    catWater,
    catGym,
    catCoding,
    catBreak,
    catStudy,
    catRead,
    catSleep,
    catCustom,
  ];

  // Maps categories to Material Icons
  static IconData getCategoryIcon(String category) {
    switch (category) {
      case catWater:
        return Icons.local_drink_rounded;
      case catGym:
        return Icons.fitness_center_rounded;
      case catCoding:
        return Icons.code_rounded;
      case catBreak:
        return Icons.coffee_rounded;
      case catStudy:
        return Icons.menu_book_rounded;
      case catRead:
        return Icons.import_contacts_rounded;
      case catSleep:
        return Icons.bedtime_rounded;
      case catCustom:
        return Icons.auto_awesome_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  // Maps categories to color schemes
  static Color getCategoryColor(String category) {
    switch (category) {
      case catWater:
        return Colors.blue;
      case catGym:
        return Colors.deepOrange;
      case catCoding:
        return Colors.purple;
      case catBreak:
        return Colors.amber;
      case catStudy:
        return Colors.green;
      case catRead:
        return Colors.teal;
      case catSleep:
        return Colors.indigo;
      case catCustom:
        return const Color(0xFFE91E8C);
      default:
        return Colors.grey;
    }
  }

  // Default Motivational Quotes
  static const List<String> defaultQuotes = [
    "Your future is created by what you do today, not tomorrow.",
    "Small daily improvements over time lead to stunning results.",
    "Motivation gets you started for now. Habit is what keeps you going.",
    "Do something today that your future self will thank you for.",
    "It's not about having time, it's about making time.",
    "Consistency is the key to unlocking your true potential.",
    "Don't wish it were easier. Wish you were better.",
    "Success is the sum of small efforts, repeated day in and day out.",
  ];
}
