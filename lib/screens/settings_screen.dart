import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/leaderboard_provider.dart';
import '../providers/social_provider.dart';
import 'auth_screen.dart';
import 'diagnostic_logs_screen.dart';
import 'friends_screen.dart';
import 'groups_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _confirmResetData(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Reset All Data"),
          content: const Text(
            "This action will delete all habits, streaks, history, and restore settings to default. This cannot be undone.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                // Clear Hive storage
                await ref.read(storageServiceProvider).clearAllData();

                // Reload habits state
                ref.read(habitNotifierProvider.notifier).loadHabits();

                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("All data has been reset successfully."),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text("Reset Everything"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final authState = ref.watch(authStateProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
        children: [
          // 1. Appearance / Theme
          const Text(
            "Appearance",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.palette_rounded),
              title: const Text("Theme Mode"),
              subtitle: Text(
                settings.themeMode[0].toUpperCase() +
                    settings.themeMode.substring(1),
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: DropdownButton<String>(
                value: settings.themeMode,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'system', child: Text("System")),
                  DropdownMenuItem(value: 'light', child: Text("Light")),
                  DropdownMenuItem(value: 'dark', child: Text("Dark")),
                ],
                onChanged: (val) {
                  if (val != null) {
                    settingsNotifier.setThemeMode(val);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            "Account",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          authState.when(
            loading: () => const Card(
              child: ListTile(
                leading: CircularProgressIndicator(),
                title: Text("Checking account"),
              ),
            ),
            error: (error, _) => Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline_rounded),
                title: const Text("Account unavailable"),
                subtitle: Text(error.toString()),
              ),
            ),
            data: (user) {
              if (user == null) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.account_circle_rounded),
                    title: const Text("Sign in"),
                    subtitle: const Text(
                      "Use Google or email to sync your score.",
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AuthScreen()),
                      );
                    },
                  ),
                );
              }

              return Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            user.photoURL != null && user.photoURL!.isNotEmpty
                            ? NetworkImage(user.photoURL!)
                            : null,
                        child: user.photoURL == null || user.photoURL!.isEmpty
                            ? const Icon(Icons.person_rounded)
                            : null,
                      ),
                      title: Text(user.displayName ?? "StreakMind user"),
                      subtitle: Text(user.email ?? "Signed in"),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.sync_rounded),
                      title: const Text("Sync Leaderboard Score"),
                      subtitle: const Text("Update your weekly ranking now"),
                      onTap: () async {
                        await ref
                            .read(leaderboardServiceProvider)
                            .syncCurrentUserScore(
                              ref.read(habitNotifierProvider),
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Score synced."),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout_rounded),
                      title: const Text("Sign out"),
                      onTap: () async {
                        await ref.read(settingsProvider.notifier).setOfflineMode(false);
                        await ref.read(authServiceProvider).signOut();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          const Text(
            "Community",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.people_rounded),
                  title: const Text("Friends"),
                  subtitle: const Text("Add friends and send messages"),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FriendsScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.groups_rounded),
                  title: const Text("Focus Groups"),
                  subtitle: const Text(
                    "Create or join private accountability groups",
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GroupsScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            "Privacy",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("Share Activity With Friends"),
                  subtitle: const Text(
                    "Show completed habits and streak milestones to friends",
                  ),
                  secondary: const Icon(Icons.visibility_rounded),
                  value: settings.shareActivityWithFriends,
                  onChanged: (value) async {
                    await settingsNotifier.setShareActivityWithFriends(value);
                    await ref
                        .read(socialServiceProvider)
                        .syncCurrentUserPublicProfile(
                          shareActivityWithFriends: value,
                          socialNotifications: settings.socialNotifications,
                          friendRequestMode: settings.friendRequestMode,
                        )
                        .catchError((_) {});
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text("Social Notifications"),
                  subtitle: const Text(
                    "Friend requests, messages, and challenge updates",
                  ),
                  secondary: const Icon(Icons.notifications_active_rounded),
                  value: settings.socialNotifications,
                  onChanged: (value) async {
                    await settingsNotifier.setSocialNotifications(value);
                    await ref
                        .read(socialServiceProvider)
                        .syncCurrentUserPublicProfile(
                          shareActivityWithFriends:
                              settings.shareActivityWithFriends,
                          socialNotifications: value,
                          friendRequestMode: settings.friendRequestMode,
                        )
                        .catchError((_) {});
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person_add_disabled_rounded),
                  title: const Text("Friend Requests"),
                  subtitle: Text(
                    settings.friendRequestMode == 'everyone'
                        ? 'Anyone with your email can send a request'
                        : 'New friend requests are blocked',
                  ),
                  trailing: DropdownButton<String>(
                    value: settings.friendRequestMode,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                        value: 'everyone',
                        child: Text('Everyone'),
                      ),
                      DropdownMenuItem(value: 'no_one', child: Text('No one')),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      await settingsNotifier.setFriendRequestMode(value);
                      await ref
                          .read(socialServiceProvider)
                          .syncCurrentUserPublicProfile(
                            shareActivityWithFriends:
                                settings.shareActivityWithFriends,
                            socialNotifications: settings.socialNotifications,
                            friendRequestMode: value,
                          )
                          .catchError((_) {});
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. Notifications
          const Text(
            "Notifications",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("Notification Sound"),
                  subtitle: const Text("Play alert sound for reminders"),
                  secondary: const Icon(Icons.volume_up_rounded),
                  value: settings.notificationSound,
                  onChanged: (val) {
                    settingsNotifier.setNotificationSound(val);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security_rounded),
                  title: const Text("Request Permissions"),
                  subtitle: const Text("Manually check notification access"),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    await ref
                        .read(notificationServiceProvider)
                        .requestPermissions();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Permissions requested."),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.snooze_rounded),
                  title: const Text("Snooze Duration"),
                  subtitle: Text(
                    "${settings.snoozeDuration} Minutes",
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: DropdownButton<int>(
                    value: settings.snoozeDuration,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 5, child: Text("5 Min")),
                      DropdownMenuItem(value: 10, child: Text("10 Min")),
                      DropdownMenuItem(value: 15, child: Text("15 Min")),
                      DropdownMenuItem(value: 30, child: Text("30 Min")),
                      DropdownMenuItem(value: 45, child: Text("45 Min")),
                      DropdownMenuItem(value: 60, child: Text("1 Hour")),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        settingsNotifier.setSnoozeDuration(val);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. AI Coach Personality
          const Text(
            "AI Coaching Settings",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.face_retouching_natural_rounded),
              title: const Text("Coach Personality"),
              subtitle: Text(
                settings.motivationPersonality == 'Strict'
                    ? 'Strict Coach'
                    : settings.motivationPersonality,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: DropdownButton<String>(
                value: settings.motivationPersonality,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'Friendly', child: Text("Friendly")),
                  DropdownMenuItem(
                    value: 'Strict',
                    child: Text("Strict Coach"),
                  ),
                  DropdownMenuItem(value: 'Funny', child: Text("Funny")),
                  DropdownMenuItem(
                    value: 'Professional',
                    child: Text("Professional"),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    settingsNotifier.setMotivationPersonality(val);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 4. Ads Config
          const Text(
            "Ad Settings",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: const Text("Show Ads"),
              subtitle: const Text(
                "Support app development with occasional ads",
              ),
              secondary: const Icon(Icons.ad_units_rounded),
              value: settings.showAds,
              onChanged: (val) {
                settingsNotifier.setShowAds(val);
              },
            ),
          ),
          const SizedBox(height: 24),

          // 4.5. Diagnostics Config
          const Text(
            "Diagnostics",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.terminal_rounded),
              title: const Text("System Diagnostic Console"),
              subtitle: const Text(
                "View logs, background jobs, and error tracks",
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DiagnosticLogsScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 40),

          // 5. Danger Zone
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red.shade800,
              elevation: 0,
              side: BorderSide(color: Colors.red.shade100),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text(
              "Reset All Data",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () => _confirmResetData(context, ref),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
