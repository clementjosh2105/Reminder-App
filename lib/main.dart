import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme.dart';
import 'core/config/firebase_config.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/firebase_notification_service.dart';
import 'services/motivation_service.dart';
import 'services/admob_service.dart';
import 'repositories/habit_repository.dart';
import 'providers/settings_provider.dart';
import 'providers/habit_provider.dart';
import 'screens/splash_screen.dart';

// ---------------------------------------------------------------------------
// Global service references - set once in main() before runApp().
// Providers read these directly; no override plumbing needed.
// ---------------------------------------------------------------------------
late final StorageService gStorageService;
late final NotificationService gNotificationService;
late final FirebaseNotificationService gFirebaseNotificationService;
late final AdMobService gAdMobService;
late final HabitRepository gHabitRepository;

void main() {
  // Catch synchronous errors thrown inside the Flutter framework itself.
  runZonedGuarded(_bootstrap, (error, stack) {
    debugPrint('🔴 Unhandled zone error: $error\n$stack');
    NotificationService.log('🔴 Unhandled zone error: $error\n$stack');
  });
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Show the real error message in release mode instead of blank white screen.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('🔴 FlutterError: ${details.exception}\n${details.stack}');
    NotificationService.log(
      '🔴 FlutterError: ${details.exception}\n${details.stack}',
    );
  };

  // Override the default red error widget with one that works in release builds.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  details.exception.toString(),
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  try {
    NotificationService.log('Bootstrap initialization started...');

    // 1. Storage - must succeed for the app to function.
    gStorageService = StorageService();
    NotificationService.log('Initializing StorageService (Hive database)...');
    await gStorageService.init();
    NotificationService.log('StorageService initialized successfully.');

    // 1b. Initialize Firebase Core
    try {
      NotificationService.log('Initializing Firebase Core...');
      await Firebase.initializeApp(options: FirebaseConfig.currentPlatform);
      NotificationService.log('Firebase Core initialized successfully.');
    } catch (e, st) {
      NotificationService.log('Firebase Core init failed (non-fatal): $e\n$st');
    }

    // 2. Notifications - Initialize Core Engine & Channels
    gNotificationService = NotificationService();
    bool permissionsGranted = false;
    try {
      NotificationService.log('Initializing NotificationService...');
      await gNotificationService.init();
      NotificationService.log(
        'NotificationService initialized. Requesting permissions...',
      );
      // AWAIT the permission response completely before moving forward
      await gNotificationService.requestPermissions();
      permissionsGranted = true;
      NotificationService.log(
        'Notification permissions requested successfully.',
      );
    } catch (e, st) {
      NotificationService.log(
        'NotificationService init failed (non-fatal): $e\n$st',
      );
    }

    // 2b. Initialize Firebase Messaging (FCM)
    try {
      NotificationService.log(
        'Initializing FirebaseNotificationService (FCM)...',
      );
      gFirebaseNotificationService = FirebaseNotificationService();
      await gFirebaseNotificationService.init();
      NotificationService.log('Firebase Messaging initialized successfully.');
    } catch (e, st) {
      NotificationService.log(
        'FirebaseNotificationService init failed (non-fatal): $e\n$st',
      );
    }

    // 3. AdMob - always non-fatal.
    gAdMobService = AdMobService();
    try {
      NotificationService.log('Initializing AdMobService...');
      await gAdMobService.init();
      NotificationService.log('AdMobService initialized.');
    } catch (e, st) {
      NotificationService.log('AdMobService init failed (non-fatal): $e\n$st');
    }

    // 4. Repository.
    gHabitRepository = HabitRepository(
      storageService: gStorageService,
      notificationService: gNotificationService,
      motivationService: MotivationService(),
      admobService: gAdMobService,
    );

    // 5. Reschedule existing reminders - only if the engine is ready.
    if (permissionsGranted) {
      try {
        NotificationService.log('Rescheduling all active habit reminders...');
        await gHabitRepository.rescheduleAllActiveReminders();
        NotificationService.log('Active reminders successfully rescheduled.');
      } catch (e, st) {
        NotificationService.log(
          'rescheduleAllActiveReminders failed (non-fatal): $e\n$st',
        );
      }
    } else {
      NotificationService.log(
        'Skipped scheduling active reminders: Permissions not ready.',
      );
    }

    NotificationService.log('Bootstrap completed. Running main application...');
    runApp(
      ProviderScope(
        overrides: [
          // Overrides the database storage hook layer
          storageServiceProvider.overrideWithValue(gStorageService),

          // Overrides the advertisement hook layer
          admobServiceProvider.overrideWithValue(gAdMobService),

          // Overrides the notifications hook layer
          notificationServiceProvider.overrideWithValue(gNotificationService),
        ],
        child: const MomentumApp(),
      ),
    );
  } catch (e, st) {
    NotificationService.log('🔴 CRITICAL BOOTSTRAP FAILURE: $e\n$st');
    debugPrint('🔴 CRITICAL BOOTSTRAP FAILURE: $e\n$st');
    runApp(BootstrapErrorApp(error: e, stackTrace: st));
  }
}

class MomentumApp extends ConsumerWidget {
  const MomentumApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    final themeMode = switch (settings.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    return MaterialApp(
      title: 'StreakMind',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}

class BootstrapErrorApp extends StatelessWidget {
  final Object error;
  final StackTrace stackTrace;

  const BootstrapErrorApp({
    super.key,
    required this.error,
    required this.stackTrace,
  });

  Future<void> _confirmAndResetData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Data?'),
        content: const Text(
          'This will permanently delete all Hive databases from disk to resolve corruption. '
          'All habits and streaks will be lost. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Hive.deleteBoxFromDisk('habits_box_v1');
        await Hive.deleteBoxFromDisk('settings_box_v1');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Hive storage cleared. Please close and restart the app manually.',
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to clear storage: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StreakMind Failure Screen',
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0F0F11),
        appBar: AppBar(
          title: const Text('Initialization Failure'),
          backgroundColor: const Color(0xFF16161A),
          elevation: 0,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 72,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Bootstrap Crash',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The application failed to launch. Inspect the system details below:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF16161A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.2),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EXCEPTION DETAILS:',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            error.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                          const Divider(height: 24, color: Colors.white10),
                          const Text(
                            'STACK TRACE:',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            stackTrace.toString(),
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF24242B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy Error Details'),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(
                        text: 'ERROR:\n$error\n\nSTACK TRACE:\n$stackTrace',
                      ),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Diagnostics copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade900,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text('Reset All Data & Reinstall'),
                  onPressed: () => _confirmAndResetData(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
