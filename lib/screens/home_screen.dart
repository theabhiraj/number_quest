// ignore_for_file: unused_field

import 'dart:convert';
import 'dart:developer' as developer;

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/puzzle.dart';
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

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _staggeredAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuad,
    );

    _loadPuzzles();
    _loadUnlockedLevels();
  }

  @override
  void dispose() {
    _animationController.dispose();
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Working offline with cached puzzles.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No internet connection and no cached puzzles available.'),
              backgroundColor: Colors.red,
            ),
          );
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
      final completedLevelsJson = prefs.getString('completed_levels');

      if (completedLevelsJson != null) {
        final completedLevels = List<int>.from(jsonDecode(completedLevelsJson));
        _determineUnlockedLevels(completedLevels);
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

  void _determineUnlockedLevels(List<int> completedLevels) {
    final Map<int, bool> unlockedLevels = {};

    // Level 1 is always unlocked
    unlockedLevels[1] = true;

    // If player completed level N, unlock level N+1
    for (final level in completedLevels) {
      unlockedLevels[level] = true;
      unlockedLevels[level + 1] = true;
    }

    setState(() {
      _unlockedLevels = unlockedLevels;
    });
  }

  Future<void> markLevelCompleted(int levelNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completedLevelsJson = prefs.getString('completed_levels');

      final List<int> completedLevels = completedLevelsJson != null
          ? List<int>.from(jsonDecode(completedLevelsJson))
          : [];

      if (!completedLevels.contains(levelNumber)) {
        completedLevels.add(levelNumber);
        await prefs.setString('completed_levels', jsonEncode(completedLevels));
      }

      _determineUnlockedLevels(completedLevels);
    } catch (e) {
      developer.log('Error saving completed level: $e', name: 'HomeScreen');
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const customPrimary = Color(0xFF5B4CFF);
    const customSecondary = Color(0xFF52C9DF);

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
              expandedHeight: 180,
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
                      child: Image.network(
                        'https://www.transparenttextures.com/patterns/cubes.png',
                        repeat: ImageRepeat.repeat,
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
                              fontSize: 60 + (index * 10),
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
                      top: 55,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.grid_3x3,
                                color: Colors.white,
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Text(
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
            actions: [
              if (_isOffline)
                Padding(
                  padding: const EdgeInsets.only(right: 10.0),
                  child: Chip(
                    label: const Text('Offline'),
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    backgroundColor: Colors.orange.withOpacity(0.7),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
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
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        PuzzleScreen(
                                  puzzle: resumePuzzle,
                                  customPrimary: customPrimary,
                                  customSecondary: customSecondary,
                                  onLevelComplete: () {
                                    markLevelCompleted(nextLevelToPlay!);
                                  },
                                ),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                                transitionDuration:
                                    const Duration(milliseconds: 400),
                              ),
                            ).then((_) => _refreshPuzzles());
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
                          offset: Offset(0, 20 * (1 - itemAnimation.value)),
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

                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    PuzzleScreen(
                              puzzle: puzzle,
                              customPrimary: customPrimary,
                              customSecondary: customSecondary,
                              onLevelComplete: () {
                                markLevelCompleted(levelNumber);
                              },
                            ),
                            transitionsBuilder: (context, animation,
                                secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                                transitionDuration:
                                    const Duration(milliseconds: 400),
                          ),
                        ).then((_) => _refreshPuzzles());
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
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
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
      setState(() {
        _userBestTime = prefs.getDouble('user_best_time_${widget.puzzle.id}') ??
            double.infinity;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading user best time: $e');
      setState(() {
        _isLoading = false;
      });
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
    // Format milliseconds with just 1 decimal place to save space
    final milliseconds = ((time - totalSeconds) * 10).round();

    // Format as minutes:seconds.milliseconds for better space efficiency
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${milliseconds}';
  }

  @override
  Widget build(BuildContext context) {
    // Extract level number from title
    final levelRegex = RegExp(r'Level\s*(\d+)|^(\d+)');
    final match = levelRegex.firstMatch(widget.puzzle.title);
    final levelText =
        match != null ? match.group(1) ?? match.group(2) ?? '?' : '?';

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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                          // Level number circle with gradient
                    Container(
                            width: 42,
                            height: 42,
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
                        child: Text(
                          levelText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                          const SizedBox(width: 16),

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
                                          fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: widget.isLocked
                                        ? Colors.grey
                                        : widget.customPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              // User's Best Time (without name)
                              if (!widget.isLocked)
                                Expanded(
                                  flex: 1,
                                  child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                    children: [
                                            Container(
                                              padding: const EdgeInsets.all(3),
                                              decoration: BoxDecoration(
                                                color: Colors.amber
                                                    .withOpacity(0.1),
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
                                      Flexible(
                                        child: _isLoading
                                            ? const SizedBox(
                                                height: 14,
                                                width: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.amber,
                                                ),
                                              )
                                                  : Container(
                                                      constraints:
                                                          const BoxConstraints(
                                                              minWidth: 70),
                                                child: Text(
                                                        _formatTime(
                                                            _userBestTime),
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                    color: Colors.amber,
                                                  ),
                                                        overflow: TextOverflow
                                                            .visible,
                                                        softWrap: false,
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),

                                const SizedBox(height: 8),

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
                                            fontSize: 15,
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
                                              fontSize: 14,
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

                          // Arrow icon with animation
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 36,
                            height: 36,
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
                              size: _isHovering ? 20 : 16,
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
