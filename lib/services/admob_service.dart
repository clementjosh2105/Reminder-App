import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/config/admob_config.dart';
import 'notification_service.dart';

class AdMobService {
  bool _isInitialized = false;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;

  bool get isInitialized => _isInitialized;

  // Initialize the Mobile Ads SDK
  Future<void> init() async {
    if (kIsWeb) {
      NotificationService.log("AdMobService skipped on Web.");
      return;
    }
    if (_isInitialized) return;
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      NotificationService.log("AdMob SDK initialized successfully.");
      // Preload the first interstitial ad
      _loadInterstitialAd();
    } catch (e) {
      NotificationService.log("Failed to initialize Google Mobile Ads SDK: $e");
    }
  }

  // Helper to create and load a banner ad
  BannerAd createBannerAd({
    required AdSize size,
    required VoidCallback onAdLoaded,
    required Function(Ad, LoadAdError) onAdFailedToLoad,
  }) {
    return BannerAd(
      adUnitId: AdMobConfig.androidBannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          NotificationService.log("AdMob Banner Loaded successfully.");
          onAdLoaded();
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          NotificationService.log("AdMob Banner failed to load: $error");
          ad.dispose();
          onAdFailedToLoad(ad, error);
        },
      ),
    );
  }

  // Preload an interstitial ad
  void _loadInterstitialAd() {
    if (_isInterstitialLoading || _interstitialAd != null) return;
    _isInterstitialLoading = true;

    try {
      InterstitialAd.load(
        adUnitId: AdMobConfig.androidInterstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            NotificationService.log("AdMob Interstitial Ad Loaded.");
            _interstitialAd = ad;
            _isInterstitialLoading = false;

            _interstitialAd!.fullScreenContentCallback =
                FullScreenContentCallback(
                  onAdDismissedFullScreenContent: (InterstitialAd ad) {
                    NotificationService.log("AdMob Interstitial Dismissed.");
                    ad.dispose();
                    _interstitialAd = null;
                    // Preload the next one
                    _loadInterstitialAd();
                  },
                  onAdFailedToShowFullScreenContent:
                      (InterstitialAd ad, AdError error) {
                        NotificationService.log(
                          "AdMob Interstitial Failed to show: $error",
                        );
                        ad.dispose();
                        _interstitialAd = null;
                        _loadInterstitialAd();
                      },
                );
          },
          onAdFailedToLoad: (LoadAdError error) {
            NotificationService.log(
              "AdMob Interstitial failed to load: $error",
            );
            _isInterstitialLoading = false;
            _interstitialAd = null;
          },
        ),
      );
    } catch (e, st) {
      NotificationService.log(
        "AdMob _loadInterstitialAd threw exception: $e\n$st",
      );
      _isInterstitialLoading = false;
      _interstitialAd = null;
    }
  }

  // Show Interstitial ad "occasionally"
  // E.g., triggers with a probability check (like 30% chance) when completing tasks
  // Returns true if the ad was shown, false otherwise
  bool showInterstitialAd({bool force = false, VoidCallback? onDismissed}) {
    if (!_isInitialized) {
      onDismissed?.call();
      return false;
    }

    if (_interstitialAd == null) {
      _loadInterstitialAd();
      onDismissed?.call();
      return false;
    }

    // Occasional trigger check (30% probability) unless forced
    const double triggerChance = 0.30;
    final bool shouldShow = force || (Random().nextDouble() < triggerChance);

    if (shouldShow) {
      _interstitialAd!.show();
      onDismissed?.call();
      return true;
    } else {
      NotificationService.log(
        "Skipping Interstitial this time for user experience flow.",
      );
      onDismissed?.call();
      return false;
    }
  }

  // Dispose active ads
  void dispose() {
    _interstitialAd?.dispose();
  }
}
