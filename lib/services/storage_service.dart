import 'package:hive_flutter/hive_flutter.dart';
import '../models/habit.dart';

class StorageService {
  static const String _habitsBoxName = 'habits_box_v1';
  static const String _settingsBoxName = 'settings_box_v1';

  late Box<Habit> _habitsBox;
  late Box _settingsBox;

  // Initialize Hive and open necessary boxes
  Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters only if not already registered
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HabitAdapter());
    }

    _habitsBox = await Hive.openBox<Habit>(_habitsBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
  }

  // --- HABIT OPERATIONS ---

  List<Habit> getHabits() {
    return _habitsBox.values.toList();
  }

  Future<void> saveHabit(Habit habit) async {
    await _habitsBox.put(habit.id, habit);
  }

  Future<void> deleteHabit(String id) async {
    await _habitsBox.delete(id);
  }

  Future<void> clearAllData() async {
    await _habitsBox.clear();
    await _settingsBox.clear();
  }

  // --- SETTINGS & CONFIG OPERATIONS ---

  String getThemeMode() {
    return _settingsBox.get('theme_mode', defaultValue: 'system') as String;
  }

  Future<void> setThemeMode(String themeMode) async {
    await _settingsBox.put('theme_mode', themeMode);
  }

  bool getNotificationSound() {
    return _settingsBox.get('notification_sound', defaultValue: true) as bool;
  }

  Future<void> setNotificationSound(bool enabled) async {
    await _settingsBox.put('notification_sound', enabled);
  }

  String getMotivationPersonality() {
    return _settingsBox.get('motivation_personality', defaultValue: 'Friendly')
        as String;
  }

  Future<void> setMotivationPersonality(String personality) async {
    await _settingsBox.put('motivation_personality', personality);
  }

  bool hasCompletedOnboarding() {
    return _settingsBox.get('completed_onboarding', defaultValue: false)
        as bool;
  }

  Future<void> setCompletedOnboarding(bool completed) async {
    await _settingsBox.put('completed_onboarding', completed);
  }

  bool getShowAds() {
    return _settingsBox.get('show_ads', defaultValue: true) as bool;
  }

  Future<void> setShowAds(bool value) async {
    await _settingsBox.put('show_ads', value);
  }

  int getSnoozeDuration() {
    return _settingsBox.get('snooze_duration', defaultValue: 10) as int;
  }

  Future<void> setSnoozeDuration(int minutes) async {
    await _settingsBox.put('snooze_duration', minutes);
  }

  bool getShareActivityWithFriends() {
    return _settingsBox.get('share_activity_with_friends', defaultValue: true)
        as bool;
  }

  Future<void> setShareActivityWithFriends(bool value) async {
    await _settingsBox.put('share_activity_with_friends', value);
  }

  bool getSocialNotifications() {
    return _settingsBox.get('social_notifications', defaultValue: true) as bool;
  }

  Future<void> setSocialNotifications(bool value) async {
    await _settingsBox.put('social_notifications', value);
  }

  String getFriendRequestMode() {
    return _settingsBox.get('friend_request_mode', defaultValue: 'everyone')
        as String;
  }

  Future<void> setFriendRequestMode(String value) async {
    await _settingsBox.put('friend_request_mode', value);
  }

  DateTime? getLastInterstitialShownTime() {
    final ms = _settingsBox.get('last_interstitial_shown_time') as int?;
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  Future<void> setLastInterstitialShownTime(DateTime time) async {
    await _settingsBox.put(
      'last_interstitial_shown_time',
      time.millisecondsSinceEpoch,
    );
  }

  // --- INTERVAL HABIT TRACKING ---

  /// Saves the absolute time (ms) when the next interval notification will fire.
  Future<void> setIntervalFireTime(String habitId, DateTime time) async {
    await _settingsBox.put(
      'interval_fire_time_$habitId',
      time.millisecondsSinceEpoch,
    );
  }

  /// Returns the scheduled fire time for the next interval notification.
  DateTime? getIntervalFireTime(String habitId) {
    final ms = _settingsBox.get('interval_fire_time_$habitId') as int?;
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  /// Gets today's instance count for an interval habit.
  int getIntervalCount(String habitId) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate =
        _settingsBox.get('interval_count_date_$habitId') as String? ?? '';
    if (storedDate != today) return 0; // new day → count is 0
    return _settingsBox.get('interval_count_$habitId', defaultValue: 0) as int;
  }

  /// Increments today's instance count.
  Future<int> incrementIntervalCount(String habitId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate =
        _settingsBox.get('interval_count_date_$habitId') as String? ?? '';
    final current = storedDate == today
        ? (_settingsBox.get('interval_count_$habitId', defaultValue: 0) as int)
        : 0;
    final next = current + 1;
    await _settingsBox.put('interval_count_$habitId', next);
    await _settingsBox.put('interval_count_date_$habitId', today);
    return next;
  }

  /// Resets the instance count to 0 for today.
  Future<void> resetIntervalCount(String habitId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await _settingsBox.put('interval_count_$habitId', 0);
    await _settingsBox.put('interval_count_date_$habitId', today);
  }

  /// Saves the timestamp when the user last completed this interval habit.
  Future<void> setIntervalLastCompletedAt(String habitId, DateTime time) async {
    await _settingsBox.put(
      'interval_done_at_$habitId',
      time.millisecondsSinceEpoch,
    );
  }

  /// Returns the last time the user completed this interval habit.
  DateTime? getIntervalLastCompletedAt(String habitId) {
    final ms = _settingsBox.get('interval_done_at_$habitId') as int?;
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  // --- OFFLINE MODE PERSISTENCE ---

  bool isOfflineMode() {
    return _settingsBox.get('offline_mode', defaultValue: false) as bool;
  }

  Future<void> setOfflineMode(bool enabled) async {
    await _settingsBox.put('offline_mode', enabled);
  }
}
