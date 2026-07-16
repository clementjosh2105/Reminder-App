import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/habit.dart';
import 'motivation_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(
  NotificationResponse notificationResponse,
) async {
  debugPrint(
    "Background Notification Action Tap: ${notificationResponse.actionId}",
  );
  if (notificationResponse.payload != null) {
    await NotificationService.rescheduleNextSingleOccurrence(
      notificationResponse.payload!,
    );
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'high_importance_channel';
  static const String channelName = 'FCM Push Notifications';
  static const String channelDesc =
      'Notifications for habit consistency and cloud sync';

  static final ValueNotifier<List<String>> diagnosticLogs =
      ValueNotifier<List<String>>([]);

  static void log(String message) {
    final timestamp = DateTime.now()
        .toString()
        .split('.')
        .first
        .split(' ')
        .last;
    diagnosticLogs.value = [...diagnosticLogs.value, "[$timestamp] $message"];
    debugPrint("📊 [NOTIF_LOG] $message");
  }

  static final ValueNotifier<NotificationResponse?>
  _notificationResponseController = ValueNotifier<NotificationResponse?>(null);

  static ValueNotifier<NotificationResponse?> get notificationTaps =>
      _notificationResponseController;

  Future<void> init() async {
    if (kIsWeb) {
      log("NotificationService initialization skipped on Web.");
      return;
    }
    tz.initializeTimeZones();
    try {
      final dynamic tzResult = await FlutterTimezone.getLocalTimezone();
      String timeZoneName = 'UTC';
      if (tzResult is String) {
        timeZoneName = tzResult;
      } else if (tzResult is Map) {
        timeZoneName = tzResult['identifier'] as String? ?? 'UTC';
      } else if (tzResult != null) {
        try {
          timeZoneName = (tzResult as dynamic).identifier as String? ?? 'UTC';
        } catch (_) {
          timeZoneName = tzResult.toString();
        }
      }
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      log("Timezone set to: $timeZoneName");
    } catch (e) {
      log("Failed to set timezone, falling back to UTC: $e");
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (ex) {
        debugPrint('Failed to set UTC location: $ex');
      }
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDesc,
        importance: Importance.max,
        playSound: true,
      );

      await androidImplementation?.createNotificationChannel(channel);
      log(
        'High Importance Android Notification Channel Registered: $channelId',
      );
    }

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        log(
          "🔔 Foreground Notification Action Tap Callback: ID=${response.id}, Action=${response.actionId}, Payload=${response.payload}",
        );
        if (response.payload != null) {
          await rescheduleNextSingleOccurrence(response.payload!);
        }
        _notificationResponseController.value = response;
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  Future<void> requestPermissions() async {
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();
      log("Requested Android OS background permission tracks.");
    } else if (Platform.isIOS) {
      final IOSFlutterLocalNotificationsPlugin? iosImplementation =
          _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >();

      await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      log("Requested iOS notification permissions.");
    }
  }

  Future<void> _safeZonedSchedule({
    required int id,
    required String? title,
    required String? body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required UILocalNotificationDateInterpretation
    uiLocalNotificationDateInterpretation,
    DateTimeComponents? matchDateTimeComponents,
    String? payload,
  }) async {
    if (kIsWeb) return;
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;

    if (!kIsWeb && Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      final bool? canScheduleExact = await androidImplementation
          ?.canScheduleExactNotifications();

      if (canScheduleExact == false) {
        log(
          "Exact alarm permission missing on device. Falling back to inexact mode.",
        );
        scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
      }
    }

    try {
      log("⏰ Querying Queue: ID $id at $scheduledDate");
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            uiLocalNotificationDateInterpretation,
        matchDateTimeComponents: matchDateTimeComponents,
        payload: payload,
      );
      log("Target Scheduled Successfully: ID $id");
    } catch (e) {
      log("Fallback Fired! Error: $e");
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            uiLocalNotificationDateInterpretation,
        matchDateTimeComponents: matchDateTimeComponents,
        payload: payload,
      );
      log("Scheduled absolute fallback window.");
    }
  }

  Future<void> _safeZonedScheduleWithWarning({
    required int id,
    required String? title,
    required String? body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required UILocalNotificationDateInterpretation uiLocalNotificationDateInterpretation,
    DateTimeComponents? matchDateTimeComponents,
    required String payload,
  }) async {
    // 1. Schedule main notification
    await _safeZonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      uiLocalNotificationDateInterpretation: uiLocalNotificationDateInterpretation,
      matchDateTimeComponents: matchDateTimeComponents,
      payload: payload,
    );

    // 2. Schedule warning notification 60s later
    final warningDate = scheduledDate.add(const Duration(seconds: 60));
    final warningAndroidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    final warningPlatformDetails = NotificationDetails(android: warningAndroidDetails);

    await _safeZonedSchedule(
      id: id + 888888,
      title: "Momentum warning! ⚠️",
      body: "You will lose the streak if you did not complete the habit!",
      scheduledDate: warningDate,
      notificationDetails: warningPlatformDetails,
      uiLocalNotificationDateInterpretation: uiLocalNotificationDateInterpretation,
      matchDateTimeComponents: matchDateTimeComponents,
      payload: payload,
    );
  }

  Future<void> scheduleHabit(Habit habit, String motivationMessage) async {
    if (kIsWeb) return;
    log(
      "📅 [Schedule] Habit ID: ${habit.id} ('${habit.title}'), Recurrence: ${habit.recurrenceType}, TimeOfDay: ${habit.timeOfDay}",
    );
    await cancelHabit(
      habit.notificationId,
      habit.recurrenceType,
      habit.customDays.length,
    );

    if (!habit.isEnabled) {
      log("  -> Scheduling skipped: Habit is disabled.");
      return;
    }

    final timeParts = habit.timeOfDay.split(':');
    final int hour = int.parse(timeParts[0]);
    final int minute = int.parse(timeParts[1]);

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDesc,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          styleInformation: BigTextStyleInformation(motivationMessage),
          actions: const <AndroidNotificationAction>[
            AndroidNotificationAction(
              'action_done',
              'Done',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              'action_snooze',
              'Snooze 10m',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              'action_skip',
              'Skip',
              showsUserInterface: true,
            ),
          ],
        );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );
    final payload = '${habit.id}|${habit.notificationId}';

    tz.TZDateTime? earliestTime;
    void updateEarliest(tz.TZDateTime time) {
      if (earliestTime == null || time.isBefore(earliestTime!)) {
        earliestTime = time;
      }
    }

    final displayTitle = habit.currentStreak > 0
        ? "${habit.title} 🔥 Streak: ${habit.currentStreak}"
        : habit.title;

    switch (habit.recurrenceType) {
      case 'CustomInterval':
        final intervalSec = habit.intervalSeconds > 0
            ? habit.intervalSeconds
            : 30;
        final scheduledTime = tz.TZDateTime.now(
          tz.local,
        ).add(Duration(seconds: intervalSec));

        log(
          "  -> Scheduling CustomInterval (1 slot): ID ${habit.notificationId} at $scheduledTime (interval: ${intervalSec}s)",
        );

        updateEarliest(scheduledTime);
        await _safeZonedScheduleWithWarning(
          id: habit.notificationId,
          title: displayTitle,
          body: motivationMessage,
          scheduledDate: scheduledTime,
          notificationDetails: platformDetails,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
        break;

      case 'Once':
        final scheduledTime = _nextInstanceOfTime(hour, minute);
        log(
          "  -> Scheduling Once: ID ${habit.notificationId} at $scheduledTime",
        );
        updateEarliest(scheduledTime);
        await _safeZonedScheduleWithWarning(
          id: habit.notificationId,
          title: displayTitle,
          body: motivationMessage,
          scheduledDate: scheduledTime,
          notificationDetails: platformDetails,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
        break;

      case 'Daily':
        final scheduledTime = _nextInstanceOfTime(hour, minute);
        log(
          "  -> Scheduling Daily: ID ${habit.notificationId} at $scheduledTime",
        );
        updateEarliest(scheduledTime);
        await _safeZonedScheduleWithWarning(
          id: habit.notificationId,
          title: displayTitle,
          body: motivationMessage,
          scheduledDate: scheduledTime,
          notificationDetails: platformDetails,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
        break;

      case 'Weekdays':
        log(
          "  -> Scheduling Weekdays: days 1-5, base ID: ${habit.notificationId}",
        );
        for (int day = 1; day <= 5; day++) {
          final scheduledTime = _nextInstanceOfDayOfWeekAndTime(
            day,
            hour,
            minute,
          );
          final id = habit.notificationId * 10 + day;
          log("    -> Day $day: ID $id at $scheduledTime");
          updateEarliest(scheduledTime);
          await _safeZonedScheduleWithWarning(
            id: id,
            title: displayTitle,
            body: motivationMessage,
            scheduledDate: scheduledTime,
            notificationDetails: platformDetails,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: payload,
          );
        }
        break;

      case 'Weekends':
        log(
          "  -> Scheduling Weekends: days 6-7, base ID: ${habit.notificationId}",
        );
        for (int day = 6; day <= 7; day++) {
          final scheduledTime = _nextInstanceOfDayOfWeekAndTime(
            day,
            hour,
            minute,
          );
          final id = habit.notificationId * 10 + day;
          log("    -> Day $day: ID $id at $scheduledTime");
          updateEarliest(scheduledTime);
          await _safeZonedScheduleWithWarning(
            id: id,
            title: displayTitle,
            body: motivationMessage,
            scheduledDate: scheduledTime,
            notificationDetails: platformDetails,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: payload,
          );
        }
        break;

      case 'CustomDays':
        log(
          "  -> Scheduling CustomDays: ${habit.customDays}, base ID: ${habit.notificationId}",
        );
        for (final day in habit.customDays) {
          final scheduledTime = _nextInstanceOfDayOfWeekAndTime(
            day,
            hour,
            minute,
          );
          final id = habit.notificationId * 10 + day;
          log("    -> Day $day: ID $id at $scheduledTime");
          updateEarliest(scheduledTime);
          await _safeZonedScheduleWithWarning(
            id: id,
            title: displayTitle,
            body: motivationMessage,
            scheduledDate: scheduledTime,
            notificationDetails: platformDetails,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: payload,
          );
        }
        break;

      case 'Hourly':
        final int interval = habit.hourlyInterval > 0
            ? habit.hourlyInterval
            : 2;
        log(
          "  -> Scheduling Hourly: interval $interval hours, base ID: ${habit.notificationId}",
        );
        int currentHour = hour;
        int slotIndex = 0;

        while (currentHour <= 22) {
          final scheduledTime = _nextInstanceOfTime(currentHour, minute);
          final id = habit.notificationId * 100 + slotIndex;
          log(
            "    -> Slot $slotIndex (hour $currentHour): ID $id at $scheduledTime",
          );

          updateEarliest(scheduledTime);
          await _safeZonedScheduleWithWarning(
            id: id,
            title: displayTitle,
            body: motivationMessage,
            scheduledDate: scheduledTime,
            notificationDetails: platformDetails,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: payload,
          );

          currentHour += interval;
          slotIndex++;
        }
        break;
    }

    if (earliestTime != null) {
      try {
        final box = Hive.isBoxOpen('settings_box_v1')
            ? Hive.box('settings_box_v1')
            : await Hive.openBox('settings_box_v1');
        await box.put(
          'interval_fire_time_${habit.id}',
          earliestTime!.toLocal().millisecondsSinceEpoch,
        );
        // Clear chain broken since we are rescheduling
        await box.delete('interval_chain_broken_${habit.id}');
        log("Saved earliest scheduled fire time: ${earliestTime!.toLocal()}");
      } catch (_) {}
    }
  }

  Future<void> snooze(
    Habit habit,
    int snoozeMinutes,
    String motivationMessage,
  ) async {
    if (kIsWeb) return;
    log(
      "⏰ [Snooze] Snoozing habit ID: ${habit.id} ('${habit.title}') for $snoozeMinutes minutes...",
    );
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDesc,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          styleInformation: BigTextStyleInformation(motivationMessage),
          actions: const <AndroidNotificationAction>[
            AndroidNotificationAction(
              'action_done',
              'Done',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              'action_snooze',
              'Snooze 10m',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              'action_skip',
              'Skip',
              showsUserInterface: true,
            ),
          ],
        );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );
    final int snoozeId = habit.notificationId + 999999;
    final scheduledTime = tz.TZDateTime.now(
      tz.local,
    ).add(Duration(minutes: snoozeMinutes));

    await _safeZonedSchedule(
      id: snoozeId,
      title: "${habit.title} (Snoozed)",
      body: motivationMessage,
      scheduledDate: scheduledTime,
      notificationDetails: platformDetails,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: '${habit.id}|$snoozeId',
    );
  }

  Future<void> cancelHabit(
    int baseId,
    String recurrenceType,
    int customDaysCount,
  ) async {
    if (kIsWeb) return;
    log("🚫 Canceling old notification instances for baseId: $baseId");
    await _notificationsPlugin.cancel(baseId);
    await _notificationsPlugin.cancel(baseId + 999999);

    if (recurrenceType == 'Weekdays' ||
        recurrenceType == 'Weekends' ||
        recurrenceType == 'CustomDays') {
      for (int i = 1; i <= 7; i++) {
        await _notificationsPlugin.cancel(baseId * 10 + i);
      }
    }

    if (recurrenceType == 'Hourly') {
      for (int slot = 0; slot < 24; slot++) {
        await _notificationsPlugin.cancel(baseId * 100 + slot);
      }
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfDayOfWeekAndTime(
    int dayOfWeek,
    int hour,
    int minute,
  ) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);
    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  static Future<void> showLocalPushBanner({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (kIsWeb) return;
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );
    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  static Future<void> rescheduleNextSingleOccurrence(String payload) async {
    if (kIsWeb) return;
    try {
      final parts = payload.split('|');
      if (parts.length < 2) return;
      final habitId = parts[0];

      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(HabitAdapter());
      }
      Box<Habit> box;
      if (Hive.isBoxOpen('habits_box_v1')) {
        box = Hive.box<Habit>('habits_box_v1');
      } else {
        await Hive.initFlutter();
        box = await Hive.openBox<Habit>('habits_box_v1');
      }

      final habit = box.get(habitId);

      // Driven by completion flow engine state now, bypass custom interval automatic loops
      if (habit != null &&
          habit.isEnabled &&
          habit.recurrenceType != 'CustomInterval') {
        final motivation = MotivationService().generateMessage(
          category: habit.category,
          personality: 'Friendly',
          streak: habit.currentStreak,
          time: DateTime.now(),
        );
        final ns = NotificationService();
        await ns.scheduleHabit(habit, motivation);
      }
    } catch (e) {
      debugPrint("Error rescheduling next occurrence: $e");
    }
  }
}
