// ignore_for_file: unused_field, unused_local_variable

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/puzzle.dart';
import '../services/connectivity_service.dart';
import 'puzzle_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _database =
      FirebaseDatabase.instance.ref().child('numberquests/puzzles');
  List<Puzzle> _puzzles = [];
  bool _isLoading = true;
  bool _isOffline = false;
  Map<int, bool> _unlockedLevels = {};
  late AnimationController _animationController;
  late Animation<double> _staggeredAnimation;
  Timer? _connectivityCheckTimer;
  final ConnectivityService _connectivityService = ConnectivityService();

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _staggeredAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuad,
    );

    _loadPuzzles();
    _loadUnlockedLevels();

    // Start periodic connectivity checks
    _connectivityCheckTimer = Timer.periodic(const Duration(seconds: 30),
        (_) => _connectivityService.checkConnectionAndShowDialog());
  }

  @override
  void dispose() {
    _animationController.dispose();
    _connectivityCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPuzzles() async {
    setState(() {
      _isLoading = true;
      _isOffline = false;
    });

    try {
      // First try to load from Firebase
      await _fetchPuzzlesFromFirebase();
    } catch (e) {
      developer.log('Firebase error: $e', name: 'HomeScreen');

      // If Firebase fails, try to load from cache
      await _loadPuzzlesFromCache();
    }
  }

  Future<void> _fetchPuzzlesFromFirebase() async {
    try {
      // Check connectivity before fetching puzzles
      final isConnected = await _connectivityService.checkConnection();
      if (!isConnected) {
        // Show dialog that requires internet connection
        _connectivityService.checkConnectionAndShowDialog();
        throw Exception('No internet connection');
      }

      final snapshot = await _database.get();
      if (!mounted) return;

      if (snapshot.exists) {
        setState(() {
          _puzzles = [];
          final Map<dynamic, dynamic> values = snapshot.value as Map;
          values.forEach((key, value) {
            try {
              _puzzles.add(Puzzle.fromJson(Map<String, dynamic>.from(value)));
            } catch (e) {
              developer.log('Error parsing puzzle: $e', name: 'HomeScreen');
            }
          });

          // Sort puzzles by their level
          _sortPuzzles();

          // Save puzzles to cache for offline use
          _savePuzzlesToCache();

          _isLoading = false;
        });
      } else {
        developer.log('No puzzles found in database', name: 'HomeScreen');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('No puzzles found. Please check your database.')));
        }
      }
    } catch (e) {
      developer.log('Database error: $e', name: 'HomeScreen');
      throw e; // Rethrow to trigger cache loading
    }
  }

  Future<void> _loadPuzzlesFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final puzzlesJson = prefs.getString('cached_puzzles');

      if (!mounted) return;

      if (puzzlesJson != null) {
        setState(() {
          _isOffline = true;
          _puzzles = [];

          // Decode and parse the cached puzzles
          final List<dynamic> puzzlesList = jsonDecode(puzzlesJson);
          for (var puzzleMap in puzzlesList) {
            try {
              _puzzles
                  .add(Puzzle.fromJson(Map<String, dynamic>.from(puzzleMap)));
            } catch (e) {
              developer.log('Error parsing cached puzzle: $e',
                  name: 'HomeScreen');
            }
          }

          // Sort puzzles by their level
          _sortPuzzles();

          _isLoading = false;
        });

        if (mounted) {
          _showOfflineDialog();
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _showNoInternetDialog();
        }
      }
    } catch (e) {
      developer.log('Cache error: $e', name: 'HomeScreen');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load cached puzzles: ${e.toString()}')),
        );
      }
    }
  }

  void _showOfflineDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Working offline with cached puzzles.'),
        duration: Duration(seconds: 3),
      ),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Prevent dialog dismiss on back button
        child: AlertDialog(
          title: Wrap(
            spacing: 8,
            children: const [
              Icon(Icons.signal_wifi_connected_no_internet_4,
                  color: Colors.red),
              Text('No Internet Connection'),
            ],
          ),
          content: const Text(
            'Please connect to the internet to access the latest puzzles and leaderboards.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final hasInternet =
                    await _connectivityService.checkConnection();
                if (hasInternet) {
                  Navigator.of(context).pop();
                  _refreshPuzzles();
                } else {
                  // Vibrate or show feedback that internet is still unavailable
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Still no internet connection. Please check your settings.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Check Again'),
            ),
          ],
        ),
      ),
    );
  }

  void _showNoInternetDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Prevent dialog dismiss on back button
        child: AlertDialog(
          title: Wrap(
            spacing: 8,
            children: const [
              Icon(Icons.signal_wifi_connected_no_internet_4,
                  color: Colors.red),
              Text('No Internet Connection'),
            ],
          ),
          content: const Text(
            'Please connect to the internet to use Number Quest. The app requires an internet connection to download puzzles.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                final hasInternet =
                    await _connectivityService.checkConnection();
                if (hasInternet) {
                  Navigator.of(context).pop();
                  _refreshPuzzles();
                } else {
                  // Vibrate or show feedback that internet is still unavailable
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Still no internet connection. Please check your settings.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Check Again'),
            ),
          ],
        ),
      ),
    );
  }

  void _sortPuzzles() {
    // Sort puzzles by their level (extracted from title)
    _puzzles.sort((a, b) {
      // Extract level number from title (assuming format "Level X: ...")
      final levelA = _extractLevelNumber(a.title);
      final levelB = _extractLevelNumber(b.title);
      return levelA.compareTo(levelB);
    });
  }

  Future<void> _savePuzzlesToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert puzzles to JSON and save to SharedPreferences
      final List<Map<String, dynamic>> puzzlesList =
          _puzzles.map((puzzle) => puzzle.toJson()).toList();

      await prefs.setString('cached_puzzles', jsonEncode(puzzlesList));
      developer.log('Puzzles saved to cache', name: 'HomeScreen');
    } catch (e) {
      developer.log('Error saving puzzles to cache: $e', name: 'HomeScreen');
    }
  }

  Future<void> _refreshPuzzles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check connectivity before refreshing puzzles
      final isConnected = await _connectivityService.checkConnection();
      if (!isConnected) {
        // Show dialog that requires internet connection
        await _connectivityService.checkConnectionAndShowDialog();
        throw Exception('No internet connection');
      }

      await _fetchPuzzlesFromFirebase();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to refresh. Using cached puzzles.'),
            backgroundColor: Colors.orange,
          ),
        );
        await _loadPuzzlesFromCache();
      }
    }
  }

  Future<void> _loadUnlockedLevels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Get unlocked levels from SharedPreferences
      final unlockedJson = prefs.getString('unlocked_levels');

      if (unlockedJson != null) {
        final Map<String, dynamic> decodedMap = jsonDecode(unlockedJson);
        _unlockedLevels = {};
        decodedMap.forEach((key, value) {
          _unlockedLevels[int.parse(key)] = value;
        });
      } else {
        // By default, only level 1 is unlocked
        setState(() {
          _unlockedLevels = {1: true};
        });
      }
    } catch (e) {
      developer.log('Error loading unlocked levels: $e', name: 'HomeScreen');
      // By default, only level 1 is unlocked
      setState(() {
        _unlockedLevels = {1: true};
      });
    }
  }

  // Mark the level as completed in user preferences
  Future<void> markLevelCompleted(int levelNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // First get current unlocked levels
      Map<int, bool> currentUnlocked = {};

      // Load existing unlocked levels
      final unlockedJson = prefs.getString('unlocked_levels');
      if (unlockedJson != null) {
        final Map<String, dynamic> decodedMap = jsonDecode(unlockedJson);
        decodedMap.forEach((key, value) {
          currentUnlocked[int.parse(key)] = value;
        });
      }

      // Mark this level as completed/unlocked
      currentUnlocked[levelNumber] = true;

      // Also unlock the next level
      currentUnlocked[levelNumber + 1] = true;

      // Save back to preferences
      final encodedMap = jsonEncode(
          currentUnlocked.map((key, value) => MapEntry(key.toString(), value)));

      await prefs.setString('unlocked_levels', encodedMap);

      // Update in-memory state if mounted
      if (mounted) {
        setState(() {
          _unlockedLevels = currentUnlocked;
        });
      }

      // Set the next level to play for the resume button
      await prefs.setInt('next_level_to_play', levelNumber + 1);
    } catch (e) {
      debugPrint('Error marking level completed: $e');
    }
  }

  // Extract level number from puzzle title
  int _extractLevelNumber(String title) {
    // Try to find a pattern like "Level X" or just a number at the beginning
    final levelRegex = RegExp(r'Level\s*(\d+)|^(\d+)');
    final match = levelRegex.firstMatch(title);

    if (match != null) {
      // Get the first non-null group (either the level number after "Level" or the number at the beginning)
      final levelStr = match.group(1) ?? match.group(2) ?? '0';
      return int.tryParse(levelStr) ?? 0;
    }

    return 0; // Default to level 0 if no level found
  }

  void _navigateToPuzzle(Puzzle puzzle) async {
    // Define customPrimary and customSecondary here
    const customPrimary = Color(0xFF5B4CFF);
    const customSecondary = Color(0xFF52C9DF);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PuzzleScreen(
          puzzle: puzzle,
          customPrimary: customPrimary,
          customSecondary: customSecondary,
          onLevelComplete: () {
            // Mark this level as completed in user preferences
            markLevelCompleted(_extractLevelNumber(puzzle.title));
          },
        ),
      ),
    );

    // After returning from the puzzle screen
    if (mounted) {
      // Always refresh puzzles list to ensure unlocked levels are updated
      await _refreshPuzzles();

      // Check if result is 'next' to navigate to the next level
      if (result == 'next') {
        // Find the next puzzle
        int currentIndex = _puzzles.indexWhere((p) => p.id == puzzle.id);
        if (currentIndex != -1 && currentIndex < _puzzles.length - 1) {
          // Small delay to ensure UI is updated before navigating
          await Future.delayed(const Duration(milliseconds: 100));
          // Navigate to the next puzzle
          _navigateToPuzzle(_puzzles[currentIndex + 1]);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const customPrimary = Color(0xFF5B4CFF);
    const customSecondary = Color(0xFF52C9DF);

    // Get screen size for responsive design
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;
    final isMediumScreen = screenSize.width >= 360 && screenSize.width < 600;
    final isTablet = screenSize.width >= 600;

    // Find the next unlocked level for the resume button
    int? nextLevelToPlay;
    if (_puzzles.isNotEmpty) {
      for (final puzzle in _puzzles) {
        final levelNumber = _extractLevelNumber(puzzle.title);
        final isUnlocked = _unlockedLevels[levelNumber] ?? false;

        if (isUnlocked) {
          if (nextLevelToPlay == null || levelNumber > nextLevelToPlay) {
            nextLevelToPlay = levelNumber;
          }
        }
      }
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshPuzzles,
        color: customPrimary,
        backgroundColor: Colors.white,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [
            SliverAppBar(
              expandedHeight: isTablet ? 220 : (isMediumScreen ? 190 : 170),
              pinned: true,
              elevation: 0,
              backgroundColor: customPrimary,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  'No. Quest',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    fontSize: 24,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3.0,
                        color: Color.fromARGB(100, 0, 0, 0),
                      ),
                    ],
                  ),
                ),
                centerTitle: true,
                titlePadding: const EdgeInsets.only(bottom: 16),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background gradient for the app bar
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF7669FF), // Lighter shade
                            Color(0xFF5B4CFF), // Main color
                            Color(0xFF4F40E3), // Darker shade
                          ],
                          stops: [0.0, 0.6, 1.0],
                        ),
                      ),
                    ),
                    // Enhanced pattern overlay
                    Positioned.fill(
                      child: ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.15),
                              Colors.white.withOpacity(0.05),
                            ],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.srcOver,
                        child: Opacity(
                          opacity: 0.1,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment.center,
                                radius: 1.0,
                                colors: [
                                  Colors.white.withOpacity(0.4),
                                  Colors.white.withOpacity(0.1),
                                ],
                                stops: const [0.2, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Decorative numbers pattern with improved styling
                    Positioned.fill(
                      child: ShaderMask(
                        shaderCallback: (rect) {
                          return LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.white.withAlpha(40)
                            ],
                          ).createShader(rect);
                        },
                        blendMode: BlendMode.dstIn,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            5,
                            (index) => Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: isTablet
                                    ? (70 + (index * 12))
                                    : (50 + (index * 10)),
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.15),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // App title decorative element
                    Positioned(
                      top: isTablet ? 75 : 55,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 25 : 20,
                            vertical: isTablet ? 10 : 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.grid_3x3,
                                color: Colors.white,
                                size: isTablet ? 28 : 24,
                              ),
                              SizedBox(width: isTablet ? 10 : 8),
                              const Text(
                                'PUZZLES',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  letterSpacing: 1.5,
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
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_puzzles.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.assignment_outlined,
                            size: 50,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No Puzzles Available',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Check back later for new challenges',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _refreshPuzzles,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: customPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    // Add a "Resume" button at the top if there's a next level to play
                    if (index == 0 && nextLevelToPlay != null) {
                      // Find the puzzle for the next level
                      final resumePuzzle = _puzzles.firstWhere(
                        (puzzle) =>
                            _extractLevelNumber(puzzle.title) ==
                            nextLevelToPlay,
                        orElse: () => _puzzles.first,
                      );

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                        child: GestureDetector(
                          onTap: () {
                            _navigateToPuzzle(resumePuzzle);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  customPrimary.withOpacity(0.9),
                                  customSecondary.withOpacity(0.9),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: customPrimary.withOpacity(0.3),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.play_circle_filled_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Resume Level $nextLevelToPlay',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    // Adjust index for puzzle items if we added the resume button
                    final puzzleIndex =
                        nextLevelToPlay != null ? index - 1 : index;
                    if (puzzleIndex >= _puzzles.length || puzzleIndex < 0)
                      return null;

                    // Start the animation once the levels are being built
                    if (index == (nextLevelToPlay != null ? 1 : 0)) {
                      _animationController.forward();
                    }

                    final puzzle = _puzzles[puzzleIndex];
                    final levelNumber = _extractLevelNumber(puzzle.title);
                    final isUnlocked = _unlockedLevels[levelNumber] ?? false;

                    // Create a staggered animation delay based on index
                    final Animation<double> itemAnimation = Tween<double>(
                      begin: 0.0,
                      end: 1.0,
                    ).animate(
                      CurvedAnimation(
                        parent: _animationController,
                        curve: Interval(
                          0.1 *
                              (puzzleIndex % 10) /
                              10, // Stagger based on index
                          0.1 * (puzzleIndex % 10) / 10 + 0.5,
                          curve: Curves.easeOut,
                        ),
                      ),
                    );

                    return AnimatedBuilder(
                      animation: itemAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, 10 * (1 - itemAnimation.value)),
                          child: Opacity(
                            opacity: itemAnimation.value,
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: puzzleIndex == 0 ? 20 : 12,
                          bottom: 4,
                        ),
                        child: LevelCard(
                          puzzle: puzzle,
                          isLocked: !isUnlocked,
                          onTap: () {
                            if (!isUnlocked) {
                              // Show locked level message with enhanced styling
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(
                                        Icons.lock_outline,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Complete Level ${levelNumber - 1} to unlock this level',
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.orange.shade800,
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                              return;
                            }

                            _navigateToPuzzle(puzzle);
                          },
                          customPrimary: customPrimary,
                          customSecondary: customSecondary,
                        ),
                      ),
                    );
                  },
                  childCount: _puzzles.isEmpty
                      ? 0
                      : (_puzzles.length + (nextLevelToPlay != null ? 1 : 0)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class LevelCard extends StatefulWidget {
  final Puzzle puzzle;
  final VoidCallback onTap;
  final Color customPrimary;
  final Color customSecondary;
  final bool isLocked;

  const LevelCard({
    super.key,
    required this.puzzle,
    required this.onTap,
    required this.customPrimary,
    required this.customSecondary,
    this.isLocked = false,
  });

  @override
  State<LevelCard> createState() => _LevelCardState();
}

class _LevelCardState extends State<LevelCard>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  double _userBestTime = double.infinity;
  bool _isLoading = true;
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserBestTime();

    // Add pulse animation for locked levels
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isLocked) {
      _animController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LevelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update animation state if lock status changes
    if (widget.isLocked != oldWidget.isLocked) {
      if (widget.isLocked) {
        _animController.repeat(reverse: true);
      } else {
        _animController.stop();
      }
    }
  }

  Future<void> _loadUserBestTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _userBestTime =
              prefs.getDouble('user_best_time_${widget.puzzle.id}') ??
                  double.infinity;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user best time: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatTime(double time) {
    if (time == double.infinity) {
      return '00:00:00'; // Show 00:00:00 instead of placeholder
    }
    if (time == 0) {
      return '00:00:00';
    }

    final totalSeconds = time.floor();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    // Format milliseconds with 2 decimal places for precise display
    final milliseconds = ((time - totalSeconds) * 100).round();

    // Format as minutes:seconds:milliseconds to match the puzzle screen format
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}:${milliseconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive design
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;
    final isMediumScreen = screenSize.width >= 360 && screenSize.width < 600;
    final isTablet = screenSize.width >= 600;

    // Extract level number from title
    final levelRegex = RegExp(r'Level\s*(\d+)|^(\d+)');
    final match = levelRegex.firstMatch(widget.puzzle.title);
    final levelText =
        match != null ? match.group(1) ?? match.group(2) ?? '?' : '?';

    // Check if this is a 3-digit level
    final isThreeDigit = levelText.length == 3;

    // Determine background card color
    final cardColor = widget.isLocked ? Colors.grey[100] : Colors.white;

    // Create border gradient for unlocked cards
    final borderGradient = widget.isLocked
        ? null
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.customPrimary.withOpacity(0.6),
              widget.customSecondary.withOpacity(0.6),
            ],
          );

    // Adjust sizes based on screen size
    final circleSize = isTablet ? 50.0 : (isMediumScreen ? 42.0 : 38.0);
    final levelFontSize = isTablet
        ? 22.0
        : (isMediumScreen ? 20.0 : (isThreeDigit ? 16.0 : 18.0));
    final titleFontSize = isTablet ? 19.0 : (isMediumScreen ? 17.0 : 15.0);
    final userTimeFontSize = isTablet ? 14.0 : (isMediumScreen ? 12.0 : 11.0);
    final bestTimeFontSize = isTablet ? 17.0 : (isMediumScreen ? 15.0 : 13.0);
    final bestPlayerFontSize = isTablet ? 16.0 : (isMediumScreen ? 14.0 : 12.0);

    // Adjust spacings
    final horizontalPadding = isTablet ? 20.0 : (isMediumScreen ? 16.0 : 12.0);
    final verticalPadding = isTablet ? 18.0 : (isMediumScreen ? 14.0 : 12.0);
    final arrowSize = isTablet ? 40.0 : (isMediumScreen ? 36.0 : 30.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.isLocked
                  ? _pulseAnimation.value
                  : (_isHovering ? 1.03 : 1.0),
              child: child,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _isHovering && !widget.isLocked
                      ? widget.customPrimary.withAlpha(40)
                      : Colors.black.withAlpha(10),
                  blurRadius: _isHovering && !widget.isLocked ? 12 : 6,
                  spreadRadius: _isHovering && !widget.isLocked ? 2 : 0,
                  offset: Offset(0, _isHovering && !widget.isLocked ? 4 : 2),
                ),
              ],
              gradient: widget.isLocked
                  ? null
                  : _isHovering
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            Colors.white.withOpacity(0.95),
                          ],
                        )
                      : null,
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.isLocked
                      ? Colors.grey.withAlpha(100)
                      : _isHovering
                          ? widget.customPrimary.withAlpha(60)
                          : Colors.transparent,
                  width: 2,
                ),
                gradient:
                    borderGradient != null && _isHovering && !widget.isLocked
                        ? borderGradient
                        : null,
              ),
              child: Stack(
                children: [
                  // Main card content
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: verticalPadding),
                      child: Row(
                        children: [
                          // Level number circle with gradient
                          Container(
                            width: circleSize,
                            height: circleSize,
                            decoration: BoxDecoration(
                              gradient: widget.isLocked
                                  ? LinearGradient(
                                      colors: [
                                        Colors.grey.shade400,
                                        Colors.grey.shade500,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : LinearGradient(
                                      colors: [
                                        widget.customPrimary,
                                        widget.customSecondary,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.isLocked
                                      ? Colors.grey.withAlpha(60)
                                      : widget.customPrimary.withAlpha(60),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: isThreeDigit
                                      ? EdgeInsets.symmetric(
                                          horizontal: isTablet ? 4.0 : 2.0)
                                      : const EdgeInsets.all(2.0),
                                  child: Text(
                                    levelText,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isThreeDigit
                                          ? (isTablet
                                              ? 18.0
                                              : (isMediumScreen ? 16.0 : 14.0))
                                          : levelFontSize,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                              width:
                                  isTablet ? 20 : (isMediumScreen ? 16 : 12)),

                          // Puzzle information
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // First row: Level title and User Best Time
                                Row(
                                  children: [
                                    // Level title
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        widget.puzzle.title,
                                        style: TextStyle(
                                          fontSize: titleFontSize,
                                          fontWeight: FontWeight.bold,
                                          color: widget.isLocked
                                              ? Colors.grey
                                              : widget.customPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),

                                    // Spacer to prevent overlapping
                                    SizedBox(width: isTablet ? 12 : 8),

                                    // User's Best Time with proper spacing
                                    if (!widget.isLocked)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.amber.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.person,
                                              size: 14,
                                              color: Colors.amber,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          _isLoading
                                              ? const SizedBox(
                                                  height: 14,
                                                  width: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.amber,
                                                  ),
                                                )
                                              : Text(
                                                  _formatTime(_userBestTime),
                                                  style: TextStyle(
                                                    fontSize: userTimeFontSize,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.amber,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                        ],
                                      ),
                                  ],
                                ),

                                SizedBox(height: isTablet ? 10 : 8),

                                // Second row: Global best time with player name
                                if (!widget.isLocked)
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: widget.customSecondary
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.emoji_events_outlined,
                                          size: 14,
                                          color: widget.customSecondary,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: RichText(
                                          overflow: TextOverflow.ellipsis,
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text: _formatTime(
                                                    widget.puzzle.bestTime),
                                                style: TextStyle(
                                                  fontSize: bestTimeFontSize,
                                                  fontWeight: FontWeight.w600,
                                                  color: widget.customSecondary,
                                                ),
                                              ),
                                              if (widget.puzzle.bestPlayerName
                                                      .isNotEmpty &&
                                                  widget.puzzle
                                                          .bestPlayerName !=
                                                      "Infinity" &&
                                                  widget.puzzle.bestTime !=
                                                      double.infinity)
                                                TextSpan(
                                                  text:
                                                      " (${widget.puzzle.bestPlayerName})",
                                                  style: TextStyle(
                                                    fontSize:
                                                        bestPlayerFontSize,
                                                    color: widget
                                                        .customSecondary
                                                        .withAlpha(240),
                                                    fontStyle: FontStyle.italic,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                // For locked levels
                                if (widget.isLocked)
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.lock,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Expanded(
                                        child: Text(
                                          "Locked - Complete previous level",
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),

                          // Add spacing before arrow icon to prevent overlapping
                          SizedBox(width: isTablet ? 12 : 8),

                          // Arrow icon with animation
                          Container(
                            width: arrowSize,
                            height: arrowSize,
                            decoration: BoxDecoration(
                              color: widget.isLocked
                                  ? Colors.grey.withAlpha(26)
                                  : _isHovering
                                      ? widget.customPrimary.withAlpha(50)
                                      : widget.customPrimary.withAlpha(26),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.isLocked
                                  ? Icons.lock
                                  : _isHovering
                                      ? Icons.arrow_forward_rounded
                                      : Icons.arrow_forward_ios_rounded,
                              size: _isHovering
                                  ? (isTablet ? 24 : 20)
                                  : (isTablet ? 20 : 16),
                              color: widget.isLocked
                                  ? Colors.grey
                                  : widget.customPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Display lock overlay if level is locked
                  if (widget.isLocked)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.grey.withOpacity(0.05),
                                Colors.grey.withOpacity(0.15),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
