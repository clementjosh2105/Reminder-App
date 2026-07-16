import 'constants.dart';

class HabitTemplate {
  final String title;
  final String description;
  final String category;
  final String timeOfDay;
  final String recurrenceType;

  const HabitTemplate({
    required this.title,
    required this.description,
    required this.category,
    required this.timeOfDay,
    this.recurrenceType = 'Daily',
  });
}

class HabitTemplatePack {
  final String name;
  final String description;
  final List<HabitTemplate> habits;

  const HabitTemplatePack({
    required this.name,
    required this.description,
    required this.habits,
  });
}

const habitTemplatePacks = [
  HabitTemplatePack(
    name: 'Focused Student',
    description: 'Study rhythm, reading, hydration, and sleep anchors.',
    habits: [
      HabitTemplate(
        title: 'Deep study block',
        description: 'One focused session with phone away.',
        category: AppConstants.catStudy,
        timeOfDay: '18:00',
      ),
      HabitTemplate(
        title: 'Read 10 pages',
        description: 'Build a daily reading chain.',
        category: AppConstants.catRead,
        timeOfDay: '21:00',
      ),
      HabitTemplate(
        title: 'Sleep wind down',
        description: 'Start your bedtime routine on time.',
        category: AppConstants.catSleep,
        timeOfDay: '22:30',
      ),
    ],
  ),
  HabitTemplatePack(
    name: 'Healthy Reset',
    description: 'Simple body basics that are easy to repeat.',
    habits: [
      HabitTemplate(
        title: 'Drink water',
        description: 'Start the day with a full glass of water.',
        category: AppConstants.catWater,
        timeOfDay: '08:00',
      ),
      HabitTemplate(
        title: 'Move for 20 minutes',
        description: 'Walk, stretch, gym, or any light workout.',
        category: AppConstants.catGym,
        timeOfDay: '19:00',
      ),
      HabitTemplate(
        title: 'Screen break',
        description: 'Take a real break away from your device.',
        category: AppConstants.catBreak,
        timeOfDay: '16:00',
      ),
    ],
  ),
  HabitTemplatePack(
    name: 'Builder Mode',
    description: 'For coding practice and shipping small progress daily.',
    habits: [
      HabitTemplate(
        title: 'Code for 45 minutes',
        description: 'Make one concrete improvement or solve one problem.',
        category: AppConstants.catCoding,
        timeOfDay: '20:00',
      ),
      HabitTemplate(
        title: 'Review notes',
        description: 'Capture what you learned today.',
        category: AppConstants.catStudy,
        timeOfDay: '21:00',
      ),
      HabitTemplate(
        title: 'Recovery break',
        description: 'Step away before the next session.',
        category: AppConstants.catBreak,
        timeOfDay: '17:30',
      ),
    ],
  ),
];
