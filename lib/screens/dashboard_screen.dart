import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/constants.dart';
import '../services/groq_service.dart';
import '../providers/auth_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/social_provider.dart';
import '../models/activity_item.dart';
import '../models/friendship.dart';
import '../models/habit.dart';
import '../services/notification_service.dart';
import '../widgets/celebration_overlay.dart';
import 'habit_list_screen.dart';
import 'leaderboard_screen.dart';
import 'statistics_screen.dart';
import 'settings_screen.dart';
import 'create_edit_habit_screen.dart';
import 'friends_screen.dart';
import 'template_packs_screen.dart';
import 'weekly_recap_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  bool _isBannerLoading = false;
  bool _isAdDismissed = false;
  double? _loadedAdWidth;
  String _motivationalQuote = '';
  String _insightMessage = '';
  String _dailyFocus = '';
  bool _showingCelebration = false;
  OverlayEntry? _celebrationEntry;
  Map<String, bool> _missedIntervalsMap = {};

  Timer? _liveRefreshTimer;

  // INSTANT TAP GUARD: Eradicates racing duplicate logging events on fast intervals
  final Map<String, bool> _isProcessingTaps = {};

  @override
  void initState() {
    super.initState();
    _getRandomQuote();
    _loadInsight();
    _loadDailyFocus();
    _evaluateIntervalDeadlines();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDailyCheckInIfNeeded();
    });
    NotificationService.notificationTaps.addListener(_handleNotificationTap);

    // BACKGROUND TICKING ENGINE: Refreshes real-time layouts directly every 1 second
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _currentIndex == 0) {
        _evaluateIntervalDeadlines();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final showAds = ref.read(settingsProvider).showAds;
    if (showAds) {
      _loadBannerAd();
    } else {
      _disposeBannerAd();
    }
  }

  @override
  void dispose() {
    _celebrationEntry?.remove();
    _disposeBannerAd();
    _liveRefreshTimer?.cancel();
    NotificationService.notificationTaps.removeListener(_handleNotificationTap);
    super.dispose();
  }

  Future<void> _evaluateIntervalDeadlines() async {
    try {
      final habits = ref.read(habitNotifierProvider);
      if (habits.isEmpty) return;

      final box = Hive.isBoxOpen('settings_box_v1')
          ? Hive.box('settings_box_v1')
          : await Hive.openBox('settings_box_v1');

      Map<String, bool> updatedMissedMap = {};
      bool stateChanged = false;

      for (final habit in habits) {
        if (!habit.isEnabled) continue;
        // 1. Check if the disk memory remembers this chain was broken
        final isPersistedBroken =
            box.get('interval_chain_broken_${habit.id}') as bool? ?? false;
        if (isPersistedBroken) {
          updatedMissedMap[habit.id] = true;
          continue; // Already processed as broken, move to next habit
        }

        // 2. Otherwise, check normal live deadline timing frames
        final fireTime = box.get('interval_fire_time_${habit.id}') as int?;
        if (fireTime != null) {
          final now = DateTime.now().millisecondsSinceEpoch;

          if (now > (fireTime + 60000)) {
            updatedMissedMap[habit.id] = true;

            await ref
                .read(habitNotifierProvider.notifier)
                .resetMissedHabitStats(habit.id);
            stateChanged = true;
          }
        }
      }

      bool mapsDiffer = updatedMissedMap.length != _missedIntervalsMap.length;
      if (!mapsDiffer) {
        for (final key in updatedMissedMap.keys) {
          if (_missedIntervalsMap[key] != true) {
            mapsDiffer = true;
            break;
          }
        }
      }

      if (mounted && (mapsDiffer || stateChanged)) {
        setState(() {
          _missedIntervalsMap = updatedMissedMap;
        });
      }
    } catch (_) {}
  }

  void _getRandomQuote() async {
    const list = AppConstants.defaultQuotes;
    setState(() {
      _motivationalQuote = list[DateTime.now().day % list.length];
    });
    try {
      final aiMessage = await GroqService.generateDashboardQuote();
      setState(() {
        _motivationalQuote = aiMessage;
      });
    } catch (_) {}
  }

  void _loadInsight() async {
    try {
      final habits = ref.read(habitNotifierProvider);
      if (habits.isEmpty) return;
      final top = habits.reduce(
        (a, b) => a.currentStreak >= b.currentStreak ? a : b,
      );
      final rate = (top.getCompletionRate() * 100).toStringAsFixed(0);
      final prompt = await GroqService.generateInsight(
        habitTitle: top.title,
        category: top.category,
        completionRate: rate,
        currentStreak: top.currentStreak,
      );
      if (mounted) setState(() => _insightMessage = prompt);
    } catch (_) {}
  }

  Future<void> _loadDailyFocus() async {
    try {
      final box = Hive.isBoxOpen('settings_box_v1')
          ? Hive.box('settings_box_v1')
          : await Hive.openBox('settings_box_v1');
      if (!mounted) return;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final savedDate = box.get('daily_focus_date') as String?;
      final savedFocus = box.get('daily_focus_text') as String?;
      if (mounted && savedDate == today && savedFocus != null) {
        setState(() => _dailyFocus = savedFocus);
      }
    } catch (_) {}
  }

  Future<void> _showDailyCheckInIfNeeded() async {
    if (!mounted) return;
    try {
      final box = Hive.isBoxOpen('settings_box_v1')
          ? Hive.box('settings_box_v1')
          : await Hive.openBox('settings_box_v1');
      if (!mounted) return;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (box.get('daily_focus_date') == today) return;

      final controller = TextEditingController();
      final focus = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Today\'s Focus'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 60,
            decoration: const InputDecoration(
              hintText: 'What matters most today?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(''),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      controller.dispose();

      await box.put('daily_focus_date', today);
      if (focus != null && focus.isNotEmpty) {
        await box.put('daily_focus_text', focus);
        if (mounted) setState(() => _dailyFocus = focus);
      } else {
        await box.delete('daily_focus_text');
      }
    } catch (_) {}
  }

  bool _isTimePast(String timeOfDayStr) {
    final parts = timeOfDayStr.split(':');
    final int hour = int.parse(parts[0]);
    final int minute = int.parse(parts[1]);
    final now = DateTime.now();
    if (now.hour > hour) return true;
    if (now.hour == hour && now.minute >= minute) return true;
    return false;
  }

  void _disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerLoaded = false;
    _isBannerLoading = false;
    _loadedAdWidth = null;
  }

  void _loadBannerAd() async {
    final showAds = ref.read(settingsProvider).showAds;
    if (!showAds) return;

    final currentWidth = MediaQuery.of(context).size.width;
    if (_bannerAd != null && _loadedAdWidth == currentWidth) return;

    if (_isBannerLoading) return;
    _isBannerLoading = true;

    if (_bannerAd != null) {
      _disposeBannerAd();
    }

    final adMobService = ref.read(admobServiceProvider);
    await adMobService.init();
    if (!mounted) {
      _isBannerLoading = false;
      return;
    }

    try {
      final adSize =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
            currentWidth.truncate(),
          );
      final finalAdSize = adSize ?? AdSize.banner;

      if (!mounted) {
        _isBannerLoading = false;
        return;
      }

      _bannerAd = adMobService.createBannerAd(
        size: finalAdSize,
        onAdLoaded: () {
          if (!mounted) return;
          setState(() {
            _isBannerLoaded = true;
            _isBannerLoading = false;
            _loadedAdWidth = currentWidth;
            _isAdDismissed = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          if (!mounted) return;
          setState(() {
            _isBannerLoaded = false;
            _isBannerLoading = false;
            _bannerAd = null;
            _loadedAdWidth = null;
          });
        },
      )..load();
    } catch (e) {
      debugPrint("Failed to load adaptive banner ad: $e");
      if (mounted) {
        setState(() {
          _isBannerLoading = false;
          _bannerAd = null;
          _loadedAdWidth = null;
        });
      }
    }
  }

  void _handleNotificationTap() {
    final response = NotificationService.notificationTaps.value;
    if (response == null) return;

    final payload = response.payload;
    if (payload != null && payload.contains('|')) {
      final parts = payload.split('|');
      final String habitId = parts[0];

      NotificationService.notificationTaps.value = null;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _evaluateIntervalDeadlines().then((_) {
          _showCompletionFlowDialog(habitId, response.actionId);
        });
      });
    }
  }

  void _showCompletionFlowDialog(String habitId, String? actionId) {
    final habits = ref.watch(habitNotifierProvider);
    final habitIndex = habits.indexWhere((h) => h.id == habitId);
    if (habitIndex == -1) return;

    final habit = habits[habitIndex];
    final isMissedInterval = _missedIntervalsMap[habit.id] ?? false;
    final isHighFrequency =
        habit.recurrenceType == 'CustomInterval' ||
        habit.recurrenceType == 'Hourly';

    final isLocked =
        !isHighFrequency &&
        !habit.isCompletedToday() &&
        !_isTimePast(habit.timeOfDay);

    if (actionId == 'action_done') {
      if (isLocked) {
        _showToast("'${habit.title}' is locked until ${habit.timeOfDay}.");
        return;
      }
      if (isMissedInterval) {
        _showToast("Missing validation window. Streak broken.");
        return;
      }
      ref
          .read(habitNotifierProvider.notifier)
          .completeHabit(habit.id, DateTime.now());
      _showToast("Great job! Session logged.");
      _checkAndCelebrate();
      _evaluateIntervalDeadlines();
      return;
    } else if (actionId == 'action_snooze') {
      final snoozeMins = ref.read(settingsProvider).snoozeDuration;
      ref.read(habitNotifierProvider.notifier).snoozeHabit(habit.id);
      _showToast("Snoozed for $snoozeMins minutes.");
      return;
    } else if (actionId == 'action_skip') {
      ref.read(habitNotifierProvider.notifier).skipHabit(habit.id);
      _showToast(
        isHighFrequency
            ? "Interval session skipped."
            : "Habit skipped for today.",
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                AppConstants.getCategoryIcon(habit.category),
                color: AppConstants.getCategoryColor(habit.category),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(habit.title)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                habit.description,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              Text(
                isLocked
                    ? "This habit is locked until ${habit.timeOfDay}."
                    : isMissedInterval
                    ? "Window missed. Reset your tracking session below to start a new streak cascade."
                    : "Log an interval milestone entry for this tracker?",
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Dismiss"),
            ),
            if (!isLocked && !isMissedInterval)
              ElevatedButton(
                onPressed: () {
                  ref
                      .read(habitNotifierProvider.notifier)
                      .completeHabit(habit.id, DateTime.now());
                  Navigator.of(context).pop();
                  _checkAndCelebrate();
                  _evaluateIntervalDeadlines();
                },
                child: const Text("Log Entry"),
              ),
          ],
        );
      },
    );
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _checkAndCelebrate() {
    if (_showingCelebration) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final todayHabits = ref.read(todayHabitsProvider);
      if (todayHabits.isEmpty) return;

      final topHabit = ref
          .read(habitNotifierProvider)
          .reduce((a, b) => a.currentStreak >= b.currentStreak ? a : b);

      // PREMIUM UPGRADE: Assign structural IconData & color palettes instead of old emojis
      IconData celebrationIcon =
          Icons.terminal_rounded; // Default Developer Style
      Color accentColor = const Color(0xFFa855f7); // Premium Purple Palette

      if (topHabit.category.toLowerCase().contains('health') ||
          topHabit.title.toLowerCase().contains('water')) {
        celebrationIcon = Icons.offline_bolt_rounded;
        accentColor = const Color(0xFF06b6d4); // Tech Cyan
      } else if (topHabit.category.toLowerCase().contains('mind') ||
          topHabit.category.toLowerCase().contains('break')) {
        celebrationIcon = Icons.coffee_rounded;
        accentColor = const Color(0xFFf97316); // Energy Orange
      }

      String dynamicMemeText =
          "Commit successful! Keep your tracking momentum high.";

      try {
        dynamicMemeText = await GroqService.generateCelebrationMeme(
          habitTitle: topHabit.title,
          category: topHabit.category,
          currentStreak: topHabit.currentStreak,
        );
      } catch (_) {}

      if (mounted) {
        setState(() => _showingCelebration = true);
        _celebrationEntry = OverlayEntry(
          builder: (_) => CelebrationOverlay(
            icon: celebrationIcon,
            accentColor: accentColor,
            message: dynamicMemeText,
            onComplete: () {
              _celebrationEntry?.remove();
              _celebrationEntry = null;
              if (mounted) setState(() => _showingCelebration = false);
            },
          ),
        );
        Overlay.of(context).insert(_celebrationEntry!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayHabits = ref.watch(todayHabitsProvider);
    final completionRate = ref.watch(todayCompletionRateProvider);
    final stats = ref.watch(streakStatsProvider);
    final friendships = ref.watch(myFriendshipsProvider);
    final activity = ref.watch(friendActivityProvider);

    final List<Widget> screens = [
      _buildHomeDashboard(
        theme,
        todayHabits,
        completionRate,
        stats,
        friendships,
        activity,
      ),
      const HabitListScreen(),
      const StatisticsScreen(),
      const LeaderboardScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: screens[_currentIndex]),
          if (_currentIndex == 0 &&
              _isBannerLoaded &&
              _bannerAd != null &&
              !_isAdDismissed)
            SafeArea(
              top: false,
              bottom: false,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    color: theme.scaffoldBackgroundColor,
                    alignment: Alignment.center,
                    width: double.infinity,
                    height: _bannerAd!.size.height.toDouble() + 14.0,
                    padding: const EdgeInsets.only(top: 14.0),
                    child: SizedBox(
                      width: _bannerAd!.size.width.toDouble(),
                      height: _bannerAd!.size.height.toDouble(),
                      child: AdWidget(ad: _bannerAd!),
                    ),
                  ),
                  Positioned(
                    top: 0.0,
                    right: 8.0,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isAdDismissed = true;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(3.0),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(
                            alpha: 0.9,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.12,
                            ),
                            width: 1.0,
                          ),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 14.0,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_rounded),
            label: 'Habits',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_rounded),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_rounded),
            label: 'Top',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0 || _currentIndex == 1
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CreateEditHabitScreen(),
                  ),
                );
              },
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  Widget _buildHomeDashboard(
    ThemeData theme,
    List<Habit> todayHabits,
    double completionRate,
    StreakStats stats,
    AsyncValue<List<Friendship>> friendships,
    AsyncValue<List<ActivityItem>> activity,
  ) {
    final dateStr = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 80.0,
          pinned: true,
          backgroundColor: theme.scaffoldBackgroundColor,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              AppConstants.appName,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
          ),
          actions: [
            IconButton(
              tooltip: 'Templates',
              icon: const Icon(Icons.auto_awesome_rounded),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TemplatePacksScreen(),
                  ),
                );
              },
            ),
            IconButton(
              tooltip: 'Weekly recap',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WeeklyRecapScreen()),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                dateStr,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQuoteCard(theme),
                const SizedBox(height: 16),
                if (_dailyFocus.isNotEmpty) ...[
                  _buildDailyFocusCard(theme),
                  const SizedBox(height: 16),
                ],
                if (_insightMessage.isNotEmpty) ...[
                  _buildInsightCard(theme),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 8),
                _buildProgressCard(theme, todayHabits, completionRate),
                const SizedBox(height: 24),
                _buildSocialCard(theme, friendships, activity),
                const SizedBox(height: 24),
                _buildStreakGrid(theme, stats, todayHabits),
                const SizedBox(height: 28),
                const Text(
                  "Focus Trackers",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (todayHabits.isEmpty)
                  _buildEmptyState(theme)
                else
                  ...todayHabits.map(
                    (habit) => _buildHabitChecklistItem(theme, habit),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHabitChecklistItem(ThemeData theme, Habit habit) {
    final todayPrefix = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final logsTodayCount = habit.completedDates
        .where((d) => d.startsWith(todayPrefix))
        .length;

    final isMissedInterval = _missedIntervalsMap[habit.id] ?? false;

    bool isWindowPending = false;
    int? fireTime;
    try {
      if (Hive.isBoxOpen('settings_box_v1')) {
        final box = Hive.box('settings_box_v1');
        fireTime = box.get('interval_fire_time_${habit.id}') as int?;
        if (fireTime != null) {
          final now = DateTime.now().millisecondsSinceEpoch;
          isWindowPending = now < fireTime;
        }
      }
    } catch (_) {}

    final localTapBlock = _isProcessingTaps[habit.id] ?? false;
    final disableLogButton = isWindowPending || localTapBlock;

    String subtitleText = "";
    String buttonText = "Log";
    if (isMissedInterval) {
      subtitleText = "Chain Broken (Missed Window)";
      buttonText = "Restart";
    } else if (isWindowPending && fireTime != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final secondsLeft = ((fireTime - now) / 1000).ceil();
      if (secondsLeft > 0) {
        if (secondsLeft >= 3600) {
          final h = secondsLeft ~/ 3600;
          final m = (secondsLeft % 3600) ~/ 60;
          subtitleText = "Waiting... Next in ${h}h ${m}m";
          buttonText = "Next in ${h}h ${m}m";
        } else if (secondsLeft >= 60) {
          final m = secondsLeft ~/ 60;
          final s = secondsLeft % 60;
          subtitleText = "Waiting... Next in ${m}m ${s}s";
          buttonText = "${m}m ${s}s";
        } else {
          subtitleText = "Waiting... Next in ${secondsLeft}s";
          buttonText = "${secondsLeft}s";
        }
      } else {
        subtitleText = "Waiting for next notification...";
        buttonText = "Waiting...";
      }
    } else if (fireTime != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final remaining = 60 - ((now - fireTime) / 1000).floor();
      final secondsLeft = remaining.clamp(0, 60);
      subtitleText = "⚡ Active! Complete now (⏱️ ${secondsLeft}s left!)";
      buttonText = "Log ($logsTodayCount)";
    } else {
      subtitleText = "Waiting for schedule...";
      buttonText = "Log";
    }

    return Card(
      key: ValueKey(habit.id),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isMissedInterval
              ? Colors.red.withValues(alpha: 0.2)
              : theme.colorScheme.onSurface.withValues(alpha: 0.08),
          width: 1.5,
        ),
      ),
      color: isMissedInterval
          ? Colors.red.withValues(alpha: 0.02)
          : disableLogButton
          ? theme.colorScheme.surface.withValues(alpha: 0.6)
          : theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isMissedInterval
                        ? Colors.red.withValues(alpha: 0.1)
                        : disableLogButton
                        ? Colors.grey.withValues(alpha: 0.1)
                        : AppConstants.getCategoryColor(
                            habit.category,
                          ).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isMissedInterval
                        ? Icons.gpp_bad_rounded
                        : disableLogButton
                        ? Icons.hourglass_empty_rounded
                        : AppConstants.getCategoryIcon(habit.category),
                    color: isMissedInterval
                        ? Colors.red
                        : disableLogButton
                        ? Colors.grey
                        : AppConstants.getCategoryColor(habit.category),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: disableLogButton
                              ? theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                )
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            isMissedInterval
                                ? Icons.timer_off_rounded
                                : disableLogButton
                                ? Icons.update_rounded
                                : Icons.repeat_rounded,
                            size: 13,
                            color: isMissedInterval
                                ? Colors.red
                                : disableLogButton
                                ? Colors.grey
                                : theme.colorScheme.primary.withValues(
                                    alpha: 0.7,
                                  ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              subtitleText,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: disableLogButton ? 0.4 : 0.6,
                                ),
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isMissedInterval)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      foregroundColor: theme.colorScheme.onSecondaryContainer,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      ref
                          .read(habitNotifierProvider.notifier)
                          .restartCustomInterval(habit.id);
                      _showToast("Chain restarted.");
                      _evaluateIntervalDeadlines();
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text("Restart"),
                  )
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: disableLogButton
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.1)
                          : theme.colorScheme.primary,
                      foregroundColor: disableLogButton
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                          : theme.colorScheme.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: disableLogButton
                        ? null
                        : () async {
                            setState(() {
                              _isProcessingTaps[habit.id] = true;
                            });

                            try {
                              await ref
                                  .read(habitNotifierProvider.notifier)
                                  .completeHabit(habit.id, DateTime.now());
                              _showToast("Logged execution entry.");
                              _checkAndCelebrate();
                              await _evaluateIntervalDeadlines();
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isProcessingTaps[habit.id] = false;
                                });
                              }
                            }
                          },
                    icon: Icon(
                      disableLogButton
                          ? Icons.lock_outline_rounded
                          : Icons.add_rounded,
                      size: 16,
                    ),
                    label: Text(buttonText),
                  ),
              ],
            ),
            if (logsTodayCount > 0) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Running Streak: ${habit.currentStreak} splits",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "Total Sessions Today: $logsTodayCount",
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteCard(ThemeData theme) {
    return GestureDetector(
      onTap: _getRandomQuote,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.07),
              theme.colorScheme.secondary.withValues(alpha: 0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.format_quote_rounded,
              size: 32,
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _motivationalQuote,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.85,
                      ),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "- AI Life Coach",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: theme.colorScheme.primary.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyFocusCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.flag_rounded,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today\'s Focus',
                  style: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer.withValues(
                      alpha: 0.72,
                    ),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _dailyFocus,
                  style: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialCard(
    ThemeData theme,
    AsyncValue<List<Friendship>> friendshipsValue,
    AsyncValue<List<ActivityItem>> activityValue,
  ) {
    final friendships = friendshipsValue.valueOrNull ?? const <Friendship>[];
    final activities = activityValue.valueOrNull ?? const <ActivityItem>[];
    final currentUid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    final pendingRequests = friendships
        .where(
          (item) => item.status == 'pending' && item.recipientUid == currentUid,
        )
        .length;
    final unreadThreads = friendships
        .where((item) => item.unreadBy.contains(currentUid))
        .length;
    final latestActivity = activities.isNotEmpty ? activities.first : null;

    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const FriendsScreen()));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.12,
                ),
                child: Icon(
                  Icons.people_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Friends',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      latestActivity == null
                          ? 'Add friends, start challenges, and message them.'
                          : '${latestActivity.actorName}: ${latestActivity.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.62,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (pendingRequests + unreadThreads > 0)
                Badge.count(count: pendingRequests + unreadThreads),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withValues(alpha: 0.10),
            Colors.orange.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: Colors.amber,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Coach Insight',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                    color: Colors.amber.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _insightMessage,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _loadInsight,
            child: Icon(
              Icons.refresh_rounded,
              size: 18,
              color: Colors.amber.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(
    ThemeData theme,
    List<Habit> todayHabits,
    double rate,
  ) {
    final percentage = (rate * 100).toInt();
    final containsInterval = todayHabits.any(
      (h) =>
          h.recurrenceType == 'CustomInterval' || h.recurrenceType == 'Hourly',
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surface.withValues(alpha: 0.95),
            ],
          ),
        ),
        padding: const EdgeInsets.all(22.0),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: rate,
                    strokeWidth: 8,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.08,
                    ),
                    color: theme.colorScheme.primary,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  "$percentage%",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    containsInterval
                        ? "Tracking Performance"
                        : "Today's Progress",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    todayHabits.isEmpty
                        ? "No tasks scheduled."
                        : "${todayHabits.where((h) => h.isCompletedToday()).length} of ${todayHabits.length} habits completed",
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      rate >= 1.0
                          ? "Awesome! Target satisfied!"
                          : rate >= 0.5
                          ? "Over halfway there, keep going!"
                          : "Start your tracking momentum!",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakGrid(
    ThemeData theme,
    StreakStats stats,
    List<Habit> habits,
  ) {
    final isIntervalMode =
        habits.isNotEmpty &&
        habits.any((h) => h.recurrenceType == 'CustomInterval');

    String currentVal = "${stats.currentStreak} Days";
    String longestVal = "${stats.longestStreak} Days";

    if (isIntervalMode) {
      final intervalHabit = habits.firstWhere(
        (h) => h.recurrenceType == 'CustomInterval',
      );
      currentVal = "${intervalHabit.currentStreak} Splits";
      longestVal = "${intervalHabit.currentStreak} Max";
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            theme,
            "Current Streak",
            currentVal,
            Icons.local_fire_department_rounded,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            theme,
            "Longest Chain",
            longestVal,
            Icons.emoji_events_rounded,
            Colors.amber.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            "Free window! Nothing active.",
            style: TextStyle(
              fontSize: 15,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
