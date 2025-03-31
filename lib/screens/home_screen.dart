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

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseReference _database =
      FirebaseDatabase.instance.ref().child('numberquests/puzzles');
  List<Puzzle> _puzzles = [];
  bool _isLoading = true;
  bool _isOffline = false;
  Map<int, bool> _unlockedLevels = {};

  @override
  void initState() {
    super.initState();
    _loadPuzzles();
    _loadUnlockedLevels();
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

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 150,
            pinned: true,
            backgroundColor: customPrimary,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Number Quest',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  fontSize: 22,
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
                          Color(0xFF6E60FF), // Slightly lighter shade
                          Color(0xFF5B4CFF), // Main color
                        ],
                      ),
                    ),
                  ),
                  // Overlay pattern
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.15,
                      child: Image.network(
                        'https://www.transparenttextures.com/patterns/cubes.png',
                        repeat: ImageRepeat.repeat,
                      ),
                    ),
                  ),
                  // Decorative numbers pattern
                  Positioned.fill(
                    child: ShaderMask(
                      shaderCallback: (rect) {
                        return LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.white.withAlpha(25)
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
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _refreshPuzzles,
                tooltip: 'Refresh puzzles',
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Puzzles Available',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.grey[700],
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
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final puzzleIndex = index;
                  if (puzzleIndex >= _puzzles.length) return null;

                  final puzzle = _puzzles[puzzleIndex];
                  final levelNumber = _extractLevelNumber(puzzle.title);
                  final isUnlocked = _unlockedLevels[levelNumber] ?? false;

                  return Padding(
                    padding: EdgeInsets.only(
                      left: 4,
                      right: 4,
                      top: index == 0 ? 16 : 8,
                      bottom: 4,
                    ),
                    child: LevelCard(
                      puzzle: puzzle,
                      isLocked: !isUnlocked,
                      onTap: () {
                        if (!isUnlocked) {
                          // Show locked level message
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Complete Level ${levelNumber - 1} to unlock this level'),
                              backgroundColor: Colors.orange,
                              duration: const Duration(seconds: 2),
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
                          ),
                        ).then((_) => _refreshPuzzles());
                      },
                      customPrimary: customPrimary,
                      customSecondary: customSecondary,
                    ),
                  );
                },
                childCount: _puzzles.length,
              ),
            ),
        ],
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

class _LevelCardState extends State<LevelCard> {
  bool _isHovering = false;
  double _userBestTime = double.infinity;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserBestTime();
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
      return ''; // Return empty string instead of 'Unsolved'
    }
    if (time == 0) {
      return '--:--';
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

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          transform: _isHovering && !widget.isLocked
              ? (Matrix4.identity()..scale(1.03))
              : Matrix4.identity(),
          margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
          decoration: BoxDecoration(
            color: widget.isLocked ? Colors.grey[200] : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _isHovering && !widget.isLocked
                    ? widget.customPrimary.withAlpha(51) // ~0.2 opacity
                    : Colors.black.withAlpha(13), // ~0.05 opacity
                blurRadius: _isHovering && !widget.isLocked ? 12 : 8,
                spreadRadius: _isHovering && !widget.isLocked ? 2 : 0,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: widget.isLocked
                  ? Colors.grey.withAlpha(100)
                  : _isHovering
                      ? widget.customPrimary.withAlpha(128) // ~0.5 opacity
                      : Colors.transparent,
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    // Level number circle
                    Container(
                      width: 36,
                      height: 36,
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
                                ? Colors.grey.withAlpha(77)
                                : widget.customPrimary
                                    .withAlpha(77), // ~0.3 opacity
                            blurRadius: 8,
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
                    const SizedBox(width: 12),
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
                                    fontSize: 16,
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
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Icon(
                                        Icons.person,
                                        size: 14,
                                        color: Colors.amber,
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
                                            : Padding(
                                                padding: const EdgeInsets.only(
                                                    right: 4),
                                                child: Text(
                                                  _formatTime(_userBestTime),
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.amber,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          // Second row: Global best time with player name
                          if (!widget.isLocked)
                            Row(
                              children: [
                                Icon(
                                  Icons.emoji_events_outlined,
                                  size: 14,
                                  color: widget.customSecondary,
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
                                            widget.puzzle.bestPlayerName !=
                                                "Infinity" &&
                                            widget.puzzle.bestTime !=
                                                double.infinity)
                                          TextSpan(
                                            text:
                                                " (${widget.puzzle.bestPlayerName})",
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: widget.customSecondary
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
                                Icon(
                                  Icons.lock,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "Locked - Complete previous level",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Arrow icon
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: widget.isLocked
                            ? Colors.grey.withAlpha(26)
                            : widget.customPrimary
                                .withAlpha(26), // ~0.1 opacity
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isLocked
                            ? Icons.lock
                            : Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: widget.isLocked
                            ? Colors.grey
                            : widget.customPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // Display lock overlay if level is locked
              if (widget.isLocked)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.grey.withOpacity(0.1),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
