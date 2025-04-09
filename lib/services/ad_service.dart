// ignore_for_file: unused_field

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// A service class to manage all ad-related operations throughout the app
class AdService {
  // Singleton instance
  static final AdService _instance = AdService._internal();
  
  // Banner ad unit ID
  static const String _androidBannerAdUnitId = 'ca-app-pub-7624999264785512/8900511771';
  
  // Interstitial ad unit ID
  static const String _androidInterstitialAdUnitId = 'ca-app-pub-7624999264785512/8540175852';
  
  // Test ad unit IDs for development (Google sample test IDs)
  static const String _testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  
  // Set to false for production ads, true for test ads
  // TEMPORARY: Using test ads to debug Amazon App Store integration
  final bool _useTestAds = false;
  
  // Private interstitial ad instance - using nullable to handle loading state
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoading = false;
  bool _isInitialized = false;
  
  // Get the current banner ad unit ID based on platform and test mode
  String get bannerAdUnitId {
    if (_useTestAds) return _testBannerAdUnitId;
    if (Platform.isAndroid) return _androidBannerAdUnitId;
    // Default to Android as a fallback
    return _androidBannerAdUnitId;
  }
  
  // Get the current interstitial ad unit ID based on platform and test mode
  String get interstitialAdUnitId {
    if (_useTestAds) return _testInterstitialAdUnitId;
    if (Platform.isAndroid) return _androidInterstitialAdUnitId;
    // Default to Android as a fallback
    return _androidInterstitialAdUnitId;
  }
  
  // Factory constructor to return the singleton instance
  factory AdService() {
    return _instance;
  }
  
  // Private internal constructor
  AdService._internal();
  
  /// Initialize the mobile ads SDK
  Future<void> initialize() async {
    debugPrint('📱 Initializing AdMob SDK...');
    
    // Enable verbose logging in debug mode
    MobileAds.instance.setAppMuted(false);
    MobileAds.instance.setAppVolume(1.0);
    
    // Initialize with request configuration
    MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        testDeviceIds: ['D0FDC8F32A5D6D81AB3767DFBCFCBB5C'], // Add the test device ID from logs
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
        tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.unspecified,
        maxAdContentRating: MaxAdContentRating.g,
      ),
    );
    
    try {
      debugPrint('📱 Calling MobileAds.instance.initialize()...');
      await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('✅ Mobile Ads initialization successful!');
      
      // Preload an interstitial ad for later use
      preloadInterstitialAd();
    } catch (e) {
      debugPrint('⚠️ Error initializing Mobile Ads: $e');
      // Still mark as initialized to prevent further initialization attempts
      _isInitialized = true;
    }
  }
  
  /// Check if ads are available (SDK initialized)
  bool isAdAvailable() {
    return _isInitialized;
  }
  
  /// Load an interstitial ad in the background
  Future<void> preloadInterstitialAd() async {
    if (!_isInitialized) return;

    if (_interstitialAd != null) {
      await _interstitialAd?.dispose();
      _interstitialAd = null;
    }

    if (_isInterstitialAdLoading) return;
    
    _isInterstitialAdLoading = true;

    try {
      await InterstitialAd.load(
        adUnitId: interstitialAdUnitId,
        request: AdRequest(
          nonPersonalizedAds: true,
          contentUrl: 'https://theabhiraj.github.io',
          keywords: ['puzzle', 'game', 'brain', 'education'],
        ),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            debugPrint('Interstitial ad loaded');
            _interstitialAd = ad;
            _isInterstitialAdLoading = false;

            // Set full screen callback
            _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (InterstitialAd ad) {
                debugPrint('Ad dismissed fullscreen content.');
                _isInterstitialAdLoading = false;
                ad.dispose();
                _interstitialAd = null;
                // Preload next interstitial ad
                preloadInterstitialAd();
              },
              onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
                debugPrint('Ad failed to show fullscreen content: ${error.message}');
                _isInterstitialAdLoading = false;
                ad.dispose();
                _interstitialAd = null;
                // Try preloading again
                preloadInterstitialAd();
              },
            );
          },
          onAdFailedToLoad: (LoadAdError error) {
            debugPrint('Interstitial ad failed to load: ${error.message}');
            _isInterstitialAdLoading = false;
            _interstitialAd = null;
            // Adaptive retry strategy based on error code
            int retryDelay = 60; // Default 1 minute
            if (error.code == 3) { // No fill
              retryDelay = 120; // 2 minutes for no fill errors
            } else if (error.code == 1) { // Network error
              retryDelay = 30; // 30 seconds for network errors
            }
            // Retry after delay
            Future.delayed(Duration(seconds: retryDelay), () => preloadInterstitialAd());
          },
        ),
      );
    } catch (e) {
      debugPrint('Error loading interstitial ad: $e');
      _isInterstitialAdLoading = false;
      _interstitialAd = null;
      // Short retry for unexpected errors
      Future.delayed(Duration(seconds: 30), () => preloadInterstitialAd());
    }
  }
  
  /// Show the preloaded interstitial ad
  /// Returns true if ad was shown, false otherwise
  Future<bool> showInterstitialAd() async {
    if (_interstitialAd == null) {
      preloadInterstitialAd(); // Try to load for next time
      return false;
    }
    
    try {
      await _interstitialAd!.show();
      _interstitialAd = null; // Set to null since the ad will be disposed in callback
      return true;
    } catch (e) {
      debugPrint('Error showing interstitial ad: $e');
      _interstitialAd?.dispose();
      _interstitialAd = null;
      preloadInterstitialAd(); // Try to load for next time
      return false;
    }
  }
  
  /// Create a banner ad widget for placement in the UI
  Widget createBannerAd({
    required AdSize adSize,
    required String adPlacement,
  }) {
    return BannerAdWidget(
      adUnitId: bannerAdUnitId,
      adSize: adSize,
      adPlacement: adPlacement,
    );
  }
}

/// A widget to display a banner ad with built-in error handling and loading states
class BannerAdWidget extends StatefulWidget {
  final String adUnitId;
  final AdSize adSize;
  final String adPlacement;
  
  const BannerAdWidget({
    super.key,
    required this.adUnitId,
    required this.adSize,
    required this.adPlacement,
  });
  
  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  int _retryAttempt = 0;
  
  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }
  
  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
  
  void _loadBannerAd() {
    final adService = AdService();
    final isTestAd = adService._useTestAds;
    debugPrint('🔍 Attempting to load banner ad with ID: ${isTestAd ? "TEST_AD" : widget.adUnitId} for placement: ${widget.adPlacement}');
    
    _bannerAd = BannerAd(
      adUnitId: widget.adUnitId,
      size: widget.adSize,
      request: const AdRequest(
        nonPersonalizedAds: true,
        keywords: ['game', 'puzzle', 'brain', 'education'],
      ),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          debugPrint('✅ Banner ad loaded successfully for placement: ${widget.adPlacement}');
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
              _retryAttempt = 0; // Reset retry counter on success
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Banner ad failed to load for placement: ${widget.adPlacement} - (${error.code}) ${error.message}');
          ad.dispose();
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
            });
          }
          
          // Adaptive retry strategy with exponential backoff, up to 5 retries
          if (_retryAttempt < 5) {
            int retryDelay = math.min(30 * math.pow(2, _retryAttempt).toInt(), 300); // Starts at 30s, caps at 5min
            
            // Shorter delay for network errors
            if (error.code == 1) retryDelay = math.min(15 * math.pow(1.5, _retryAttempt).toInt(), 120);
            
            _retryAttempt++;
            
            Future.delayed(Duration(seconds: retryDelay), () {
              if (mounted) {
                _loadBannerAd();
              }
            });
          }
        },
        onAdOpened: (ad) {
          debugPrint('👆 Banner ad opened for placement: ${widget.adPlacement}');
        },
        onAdClosed: (ad) {
          debugPrint('👇 Banner ad closed for placement: ${widget.adPlacement}');
        },
      ),
    );
    
    _bannerAd!.load();
  }
  
  @override
  Widget build(BuildContext context) {
    if (_bannerAd == null || !_isAdLoaded) {
      // Return an empty container with the same size as the ad would be
      // to prevent layout shifts when the ad loads
      return Container(
        width: widget.adSize.width.toDouble(),
        height: widget.adSize.height.toDouble(),
        color: Colors.transparent,
      );
    }
    
    return Container(
      width: widget.adSize.width.toDouble(),
      height: widget.adSize.height.toDouble(),
      alignment: Alignment.center,
      child: AdWidget(ad: _bannerAd!),
    );
  }
} 