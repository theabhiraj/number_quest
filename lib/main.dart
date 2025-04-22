// ignore_for_file: unused_import, duplicate_ignore, unused_local_variable

import 'dart:async';
// ignore: unused_import
import 'dart:convert';
import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'models/puzzle.dart';
import 'services/connectivity_service.dart';
import 'services/ad_service.dart';

// Global navigator key to access context from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set orientation to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style to transparent to prevent black screen
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  // Initialize ad service with retries
  bool adsInitialized = false;
  int attempts = 0;

  debugPrint('📱 Starting ad initialization process...');

  while (!adsInitialized && attempts < 3) {
    try {
      debugPrint('📱 Ad initialization attempt ${attempts + 1}...');
      await AdService().initialize();
      adsInitialized = true;
      debugPrint(
          '✅ Ad initialization successful after ${attempts + 1} attempts');
    } catch (e) {
      attempts++;
      debugPrint('❌ Ad initialization attempt $attempts failed: $e');
      // Wait before retrying
      if (attempts < 3) {
        final retryDelay = math.pow(2, attempts).toInt();
        debugPrint('⏳ Waiting $retryDelay seconds before retrying...');
        await Future.delayed(Duration(seconds: retryDelay));
      }
    }
  }

  if (!adsInitialized) {
    debugPrint(
        '⚠️ Failed to initialize ads after $attempts attempts. Continuing without ads.');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const MyApp());
  } catch (e) {
    debugPrint('❌ Failed to initialize Firebase: $e');
    runApp(const ErrorApp());
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ConnectivityService _connectivityService = ConnectivityService();

  @override
  void initState() {
    super.initState();
    // Initialize connectivity service with navigatorKey
    _connectivityService.initialize(navigatorKey);
  }

  @override
  Widget build(BuildContext context) {
    // Modern color palette with improved primary color
    const customPrimary = Color(0xFF5B4CFF);
    const customSecondary = Color(0xFF52C9DF);
    const customAccent = Color(0xFFFF6B8B);
    const customBackground = Color(0xFFF8F9FC);

    return MaterialApp(
      title: 'No. Quest',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // Set the navigator key
      theme: ThemeData(
        primaryColor: customPrimary,
        scaffoldBackgroundColor: customBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: customPrimary,
          secondary: customSecondary,
          tertiary: customAccent,
          surface: customBackground,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        // Use Google Fonts for modern typography
        textTheme: GoogleFonts.montserratTextTheme(
          ThemeData.light().textTheme,
        ),
        // Card theme
        cardTheme: CardTheme(
          elevation: 2,
          shadowColor: customPrimary.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        // Button themes
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),
        iconTheme: IconThemeData(
          color: customPrimary,
          size: 24,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isLoading = true;
  bool _hasInternet = true;
  final ConnectivityService _connectivityService = ConnectivityService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // Reduced from 1500ms
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOutBack),
      ),
    );

    // Start animation immediately
    _animationController.forward();

    // Check for cached puzzles and internet connection after short delay
    // This allows the splash screen to display
    Future.delayed(const Duration(milliseconds: 300), () {
      _checkConnection();
    });
  }

  Future<void> _checkConnection() async {
    try {
      // First check for connectivity
      _hasInternet = await _connectivityService.checkConnection();

      // If no internet, see if we have cached puzzles
      if (!_hasInternet) {
        final prefs = await SharedPreferences.getInstance();
        final puzzlesJson = prefs.getString('cached_puzzles');

        if (puzzlesJson == null) {
          // No internet and no cached puzzles - show error after splash animation finishes
          _animationController.addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) {
              _connectivityService.checkConnectionAndShowDialog();
            }
          });
          return;
        }
      }

      // Simulate network delay - reduce to 1 second
      await Future.delayed(const Duration(seconds: 1));

      // Navigate to home screen after splash animation
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const HomeScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _hasInternet = false;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const customPrimary = Color(0xFF5B4CFF);
    const customSecondary = Color(0xFF52C9DF);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF7669FF), // Slightly lighter shade
              Color(0xFF5B4CFF), // Main color
              Color(0xFF4F40E3), // Darker shade for depth
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned.fill(
              child: Opacity(
                opacity: 0.07,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    backgroundBlendMode: BlendMode.screen,
                  ),
                ),
              ),
            ),

            // Decorative numbers floating randomly
            ...List.generate(6, (index) {
              final size = 20.0 + (index * 6.0);
              final posX = 50.0 +
                  (index * 40.0) % MediaQuery.of(context).size.width -
                  100;
              final posY = 100.0 +
                  (index * 60.0) % MediaQuery.of(context).size.height -
                  200;
              final opacity = 0.03 + (index % 3) * 0.01;

              return Positioned(
                left: posX,
                top: posY,
                child: Text(
                  '${(index % 9) + 1}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(opacity),
                    fontSize: size,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),

            // Main content
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo or App Title
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.white, Color(0xFFC4FFFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Icon(
                            Icons.grid_3x3,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      // App Title with gradient text
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Colors.white, Color(0xFFE2E8FF)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ).createShader(bounds),
                        child: const Text(
                          'No. Quest',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.5,
                            height: 1.1,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Developer credit with modern styling
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'com.abhiraj',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w300,
                            color: Colors.white70,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),

                      const SizedBox(height: 70),

                      // Loading indicator
                      if (_isLoading)
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Status message
                      AnimatedOpacity(
                        opacity: _isLoading ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _hasInternet
                                ? 'Loading puzzles...'
                                : 'No internet connection.',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'No. Quest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: Colors.red,
          centerTitle: true,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 80,
                ),
                SizedBox(height: 24),
                Text(
                  'Failed to initialize Firebase',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  'Please check your internet connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
