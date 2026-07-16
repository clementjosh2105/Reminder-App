import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';
import 'habit_provider.dart';

class SettingsState {
  final String themeMode;
  final bool notificationSound;
  final String motivationPersonality;
  final bool completedOnboarding;
  final bool showAds;
  final int snoozeDuration;
  final bool shareActivityWithFriends;
  final bool socialNotifications;
  final String friendRequestMode;

  SettingsState({
    required this.themeMode,
    required this.notificationSound,
    required this.motivationPersonality,
    required this.completedOnboarding,
    required this.showAds,
    required this.snoozeDuration,
    required this.shareActivityWithFriends,
    required this.socialNotifications,
    required this.friendRequestMode,
  });

  SettingsState copyWith({
    String? themeMode,
    bool? notificationSound,
    String? motivationPersonality,
    bool? completedOnboarding,
    bool? showAds,
    int? snoozeDuration,
    bool? shareActivityWithFriends,
    bool? socialNotifications,
    String? friendRequestMode,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      notificationSound: notificationSound ?? this.notificationSound,
      motivationPersonality:
          motivationPersonality ?? this.motivationPersonality,
      completedOnboarding: completedOnboarding ?? this.completedOnboarding,
      showAds: showAds ?? this.showAds,
      snoozeDuration: snoozeDuration ?? this.snoozeDuration,
      shareActivityWithFriends:
          shareActivityWithFriends ?? this.shareActivityWithFriends,
      socialNotifications: socialNotifications ?? this.socialNotifications,
      friendRequestMode: friendRequestMode ?? this.friendRequestMode,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final StorageService _storageService;

  SettingsNotifier(this._storageService)
    : super(
        SettingsState(
          themeMode: _storageService.getThemeMode(),
          notificationSound: _storageService.getNotificationSound(),
          motivationPersonality: _storageService.getMotivationPersonality(),
          completedOnboarding: _storageService.hasCompletedOnboarding(),
          showAds: _storageService.getShowAds(),
          snoozeDuration: _storageService.getSnoozeDuration(),
          shareActivityWithFriends: _storageService
              .getShareActivityWithFriends(),
          socialNotifications: _storageService.getSocialNotifications(),
          friendRequestMode: _storageService.getFriendRequestMode(),
        ),
      );

  Future<void> setThemeMode(String themeMode) async {
    await _storageService.setThemeMode(themeMode);
    state = state.copyWith(themeMode: themeMode);
  }

  Future<void> setNotificationSound(bool enabled) async {
    await _storageService.setNotificationSound(enabled);
    state = state.copyWith(notificationSound: enabled);
  }

  Future<void> setMotivationPersonality(String personality) async {
    await _storageService.setMotivationPersonality(personality);
    state = state.copyWith(motivationPersonality: personality);
  }

  Future<void> completeOnboarding() async {
    await _storageService.setCompletedOnboarding(true);
    state = state.copyWith(completedOnboarding: true);
  }

  Future<void> setShowAds(bool enabled) async {
    await _storageService.setShowAds(enabled);
    state = state.copyWith(showAds: enabled);
  }

  Future<void> setSnoozeDuration(int minutes) async {
    await _storageService.setSnoozeDuration(minutes);
    state = state.copyWith(snoozeDuration: minutes);
  }

  Future<void> setShareActivityWithFriends(bool enabled) async {
    await _storageService.setShareActivityWithFriends(enabled);
    state = state.copyWith(shareActivityWithFriends: enabled);
  }

  Future<void> setSocialNotifications(bool enabled) async {
    await _storageService.setSocialNotifications(enabled);
    state = state.copyWith(socialNotifications: enabled);
  }

  Future<void> setFriendRequestMode(String mode) async {
    await _storageService.setFriendRequestMode(mode);
    state = state.copyWith(friendRequestMode: mode);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    final storage = ref.watch(storageServiceProvider);
    return SettingsNotifier(storage);
  },
);
