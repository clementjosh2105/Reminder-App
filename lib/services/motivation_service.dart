import 'dart:math';
import '../core/constants.dart';

class MotivationService {
  final Random _random = Random();

  String generateMessage({
    required String category,
    required String personality,
    required int streak,
    required DateTime time,
  }) {
    final String timeOfDay = _getTimeOfDay(time);

    // 1. Check for special streak achievements
    if (streak >= 7) {
      return _generateStreakMessage(personality, category, streak);
    }

    // 2. Select message list based on style/personality
    switch (personality) {
      case 'Strict':
        return _getStrictMessage(category, timeOfDay);
      case 'Funny':
        return _getFunnyMessage(category, timeOfDay);
      case 'Professional':
        return _getProfessionalMessage(category, timeOfDay);
      case 'Friendly':
      default:
        return _getFriendlyMessage(category, timeOfDay);
    }
  }

  String _getTimeOfDay(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 21) return 'evening';
    return 'night';
  }

  // --- STREAK SPECIAL MESSAGES ---
  String _generateStreakMessage(
    String personality,
    String category,
    int streak,
  ) {
    switch (personality) {
      case 'Strict':
        return "You have maintained a $streak-day streak for '$category'. Don't you dare break it today!";
      case 'Funny':
        return "A $streak-day streak! You are officially addicted to '$category'. We've created a monster!";
      case 'Professional':
        return "Impressive consistency. You have achieved a $streak-day streak for '$category'. Keep it up.";
      case 'Friendly':
      default:
        return "Wow, a $streak-day streak! You are doing absolutely amazing with '$category'. Keep going!";
    }
  }

  // --- FRIENDLY PERSONALITY ---
  String _getFriendlyMessage(String category, String timeOfDay) {
    final Map<String, List<String>> messages = {
      AppConstants.catWater: [
        "Time for a quick water break. Let's hydrate together!",
        "Take a moment to drink some water. Your body will thank you.",
        "A healthy body needs water. Let's drink a glass right now!",
      ],
      AppConstants.catGym: [
        "Time to get active! Enjoy your workout, you've got this.",
        "Your fitness goal is waiting. Let's move and feel great!",
        "Gym time! Just do what you can. Every step counts.",
      ],
      AppConstants.catCoding: [
        "Ready to write some code? Let's build something awesome!",
        "Let's solve some problems. Happy coding!",
        "Time to code. Don't worry about bugs, you'll figure them out!",
      ],
      AppConstants.catBreak: [
        "Time for a breather. Stretch out, relax, and clear your mind.",
        "Take a short break. You've been working hard!",
        "Pause and look away from the screen. Breathe in, breathe out.",
      ],
      AppConstants.catStudy: [
        "Ready to learn something new? Let's open the books!",
        "Focus time. You are growing smarter with every page.",
        "Study session starting. You're building a brighter future.",
      ],
      AppConstants.catRead: [
        "Time to dive into a good story. Enjoy your reading time!",
        "A book is a dream you hold in your hand. Let's read a bit.",
        "Let's get lost in a book for a few minutes.",
      ],
      AppConstants.catSleep: [
        "Time to wind down. Get ready for a peaceful night's sleep.",
        "Rest is fuel for tomorrow. Let's put the screens away and rest.",
        "Sleep well! You did your best today.",
      ],
    };

    final list =
        messages[category] ??
        [
          "Here is your gentle reminder for $category. You've got this!",
          "Time to focus on $category. Keep up the good work!",
        ];

    // Add time of day touch
    if (timeOfDay == 'morning' && _random.nextBool()) {
      return "Good morning! $category is a great way to start your day.";
    }

    return list[_random.nextInt(list.length)];
  }

  // --- STRICT COACH PERSONALITY ---
  String _getStrictMessage(String category, String timeOfDay) {
    final Map<String, List<String>> messages = {
      AppConstants.catWater: [
        "You scheduled this. Drink your water. No excuses.",
        "Dehydration is weakness. Drink water immediately.",
        "Pick up the cup and drink. Action, not thoughts.",
      ],
      AppConstants.catGym: [
        "Excuses don't burn calories. Get up and hit the gym.",
        "You set this reminder because you wanted to change. Show up.",
        "Stop scrolling. Start sweating. Now.",
      ],
      AppConstants.catCoding: [
        "Clean workspace, open editor, and write the code. Do it now.",
        "Code doesn't write itself. Focus and get to work.",
        "No distractions. Commit to your coding goals.",
      ],
      AppConstants.catBreak: [
        "Work ends here for a few minutes. Step away from the screens.",
        "An exhausted mind produces garbage. Take your break.",
        "Stop. Close your eyes. Do not open work until this break is done.",
      ],
      AppConstants.catStudy: [
        "Focus on your studies. Knowledge is power, don't waste it.",
        "Put your phone on silent. Open your books. Zero excuses.",
        "Study now, celebrate later. Show some discipline.",
      ],
      AppConstants.catRead: [
        "Open the book. Read the pages. Cultivate your mind.",
        "Stop making excuses. Read your chapters now.",
        "Readers are leaders. Start reading.",
      ],
      AppConstants.catSleep: [
        "Shut down the laptop. Turn off the light. Go to sleep.",
        "Sleep is mandatory, not optional. Close your eyes.",
        "Stop stealing time from tomorrow. Go to bed.",
      ],
    };

    final list =
        messages[category] ??
        [
          "You committed to $category. Action is the only truth. Start now.",
          "Get up and do $category. No compromises.",
        ];

    return list[_random.nextInt(list.length)];
  }

  // --- FUNNY PERSONALITY ---
  String _getFunnyMessage(String category, String timeOfDay) {
    final Map<String, List<String>> messages = {
      AppConstants.catWater: [
        "Your water bottle is feeling ignored. Stop hurting its feelings.",
        "Remember, you are basically a houseplant with complicated emotions. Go water yourself.",
        "Water: 0 calories, 100% chance of making you pee, but do it anyway.",
      ],
      AppConstants.catGym: [
        "The gym misses you. Or at least, the membership system likes your money.",
        "Sweat is just fat crying. Go make your fat cry.",
        "Gym time! Think of the post-workout snack.",
      ],
      AppConstants.catCoding: [
        "Time to turn coffee into bugs. I mean, code.",
        "If compile succeeds on first try, be very suspicious. Go code!",
        "Control + S is your best friend. Go write some syntax errors!",
      ],
      AppConstants.catBreak: [
        "Please step away from the machine. The robot uprising can wait.",
        "Take a break. If you crash, we can't reboot you.",
        "Stare into space. Pretend you are buffering.",
      ],
      AppConstants.catStudy: [
        "Studying: because magic isn't real and you need a career.",
        "Let's study. Future you is begging you not to fail this.",
        "Absorb information like a sponge. Hopefully a clean one.",
      ],
      AppConstants.catRead: [
        "Read books. It makes you look smart even if you're just looking at the pages.",
        "Smell the pages. Okay, now read them.",
        "A book is like Netflix, but you have to use your brain's graphics card.",
      ],
      AppConstants.catSleep: [
        "Your bed is calling. It wants to cuddle.",
        "Go to sleep. The memes will still be there tomorrow.",
        "Sleep: the free trial version of death, but with cozy blankets.",
      ],
    };

    final list =
        messages[category] ??
        [
          "It is time for $category. Do it before the notifications get passive-aggressive.",
          "Reminder to do $category. If you don't, I will notify you again. And again.",
        ];

    return list[_random.nextInt(list.length)];
  }

  // --- PROFESSIONAL PERSONALITY ---
  String _getProfessionalMessage(String category, String timeOfDay) {
    final Map<String, List<String>> messages = {
      AppConstants.catWater: [
        "Hydration is critical for cognitive function and metabolic efficiency. Please hydrate.",
        "Optimal physical performance requires regular fluid intake. Time for water.",
        "Please consume water to sustain performance levels.",
      ],
      AppConstants.catGym: [
        "Physical training is scheduled. Proceed to exercise to support cardiovascular health.",
        "Gym session block starts now. Prioritize fitness to maintain peak energy.",
        "Training session active. Exercise promotes optimal long-term productivity.",
      ],
      AppConstants.catCoding: [
        "Development block initialized. Open IDE and execute coding tasks.",
        "Focus on system design and software development objectives now.",
        "Please allocate focus to write and review code.",
      ],
      AppConstants.catBreak: [
        "Take a recess to mitigate cognitive fatigue and repetitive strain.",
        "Scheduled pause. Relieve visual stress and restore executive capacity.",
        "Please pause task operations. Take a rest interval.",
      ],
      AppConstants.catStudy: [
        "Structured study session. Execute learning and research protocols.",
        "Acquisition of knowledge is essential for professional advancement.",
        "Please focus on study objectives for this time block.",
      ],
      AppConstants.catRead: [
        "Scheduled reading interval. Review reference material or literature.",
        "Reading fosters analytical reasoning. Proceed to read.",
        "Please proceed with your designated reading material.",
      ],
      AppConstants.catSleep: [
        "Restoration protocol initiated. Prepare for circadian rest cycle.",
        "Sufficient sleep is required to sustain future cognitive efficiency.",
        "System shutdown. Please prepare for sleep.",
      ],
    };

    final list =
        messages[category] ??
        [
          "Scheduled task block for $category is active. Please initiate task.",
          "Prioritize your objective: $category. Execution leads to results.",
        ];

    return list[_random.nextInt(list.length)];
  }
}
