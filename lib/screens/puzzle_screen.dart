// ignore_for_file: unused_local_variable

import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/puzzle.dart';
import '../widgets/puzzle_grid.dart';

class PuzzleScreen extends StatefulWidget {
  final Puzzle puzzle;
  final Color customPrimary;
  final Color customSecondary;
  final VoidCallback? onLevelComplete;

  const PuzzleScreen({
    super.key,
    required this.puzzle,
    required this.customPrimary,
    required this.customSecondary,
    this.onLevelComplete,
  });

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen>
    with SingleTickerProviderStateMixin {
  late Puzzle _currentPuzzle;
  bool _isPlaying = false;
  int _elapsedSeconds = 0;
  double _elapsedMilliseconds = 0;
  Timer? _timer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  double _currentTime = 0.0;
  double _userBestTime = double.infinity; // Track user's personal best time
  String playerName = "Unknown";

  @override
  void initState() {
    super.initState();
    // Create a deep copy of the puzzle to work with
    _currentPuzzle = widget.puzzle.copyWith();

    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _animationController.forward();

    // Load user's best time from local storage
    _loadUserBestTime();
  }

  Future<void> _loadUserBestTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userBestTime =
            prefs.getDouble('user_best_time_${_currentPuzzle.id}') ??
                double.infinity;
      });
    } catch (e) {
      // If there's an error loading the best time, just continue with infinity
      debugPrint('Error loading user best time: $e');
    }
  }

  Future<void> _saveUserBestTime(double time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('user_best_time_${_currentPuzzle.id}', time);
    } catch (e) {
      debugPrint('Error saving user best time: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (!_isPlaying) {
      setState(() {
        _isPlaying = true;
        _elapsedSeconds = 0;
        _elapsedMilliseconds = 0;
        _currentTime = 0.0;
      });
      _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
        setState(() {
          _elapsedMilliseconds += 0.01;
          if (_elapsedMilliseconds >= 1) {
            _elapsedSeconds++;
            _elapsedMilliseconds = 0;
          }
          _currentTime = _elapsedSeconds + _elapsedMilliseconds;
        });
      });
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isPlaying = false;
    });
  }

  void _resetPuzzle() {
    _stopTimer();
    setState(() {
      _currentPuzzle = widget.puzzle.copyWith();
      _elapsedSeconds = 0;
      _elapsedMilliseconds = 0;
      _currentTime = 0.0;
    });
  }

  void _handleTileTap(int row, int col, {String? direction}) {
    if (!_isPlaying) {
      _startTimer();
    }

    // Find all empty positions that are adjacent to the tapped tile
    List<List<int>> adjacentEmptyPositions = [];
    Map<String, List<int>> directionMap = {};

    // Check Up
    if (row > 0 &&
        row - 1 < _currentPuzzle.grid.length &&
        col < _currentPuzzle.grid[row - 1].length &&
        _currentPuzzle.grid[row - 1][col] == 0) {
      List<int> pos = [row - 1, col];
      adjacentEmptyPositions.add(pos);
      directionMap['up'] = pos;
    }

    // Check Down
    if (row + 1 < _currentPuzzle.grid.length &&
        col < _currentPuzzle.grid[row + 1].length &&
        _currentPuzzle.grid[row + 1][col] == 0) {
      List<int> pos = [row + 1, col];
      adjacentEmptyPositions.add(pos);
      directionMap['down'] = pos;
    }

    // Check Left
    if (col > 0 && _currentPuzzle.grid[row][col - 1] == 0) {
      List<int> pos = [row, col - 1];
      adjacentEmptyPositions.add(pos);
      directionMap['left'] = pos;
    }

    // Check Right
    if (col + 1 < _currentPuzzle.grid[row].length &&
        _currentPuzzle.grid[row][col + 1] == 0) {
      List<int> pos = [row, col + 1];
      adjacentEmptyPositions.add(pos);
      directionMap['right'] = pos;
    }

    // If there are any adjacent empty positions, move the tile
    if (adjacentEmptyPositions.isNotEmpty) {
      List<int> targetEmptyPos;

      // If a direction was specified and it's valid, use that direction
      if (direction != null && directionMap.containsKey(direction)) {
        targetEmptyPos = directionMap[direction]!;
      } else {
        // Otherwise use the first empty position found
        targetEmptyPos = adjacentEmptyPositions.first;
      }

      setState(() {
        final gridCopy = List<List<int>>.from(
          _currentPuzzle.grid.map((row) => List<int>.from(row)),
        );

        // Swap the tile with the empty space
        final temp = gridCopy[row][col];
        gridCopy[row][col] = 0;
        gridCopy[targetEmptyPos[0]][targetEmptyPos[1]] = temp;

        _currentPuzzle = _currentPuzzle.copyWith(grid: gridCopy);

        // Check if puzzle is solved
        if (_currentPuzzle.isSolved()) {
          _handlePuzzleSolved();
        }
      });
    }
  }

  Future<void> _handlePuzzleSolved() async {
    _stopTimer();

    try {
      // Update best time in Firebase
      final databaseRef = FirebaseDatabase.instance
          .ref()
          .child('numberquests/puzzles/${_currentPuzzle.id}');

      // Set final time in seconds
      _currentTime = _elapsedSeconds + _elapsedMilliseconds;

      // Update user's best time if this time is better
      bool isUserBestTime = false;
      if (_currentTime < _userBestTime || _userBestTime == double.infinity) {
        _userBestTime = _currentTime;
        await _saveUserBestTime(_currentTime);
        isUserBestTime = true;
      }

      // Call the onLevelComplete callback if provided
      if (widget.onLevelComplete != null) {
        widget.onLevelComplete!();
      }

      if (_currentTime < _currentPuzzle.bestTime) {
        // Ask for player name
        if (mounted) {
          TextEditingController textController =
              TextEditingController(text: "");

          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Row(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: widget.customSecondary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Text('New Record!'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Congratulations! You set a new record time.',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Enter your name (max 7 letters):',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: textController,
                      autofocus: true,
                      maxLength: 7,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: widget.customPrimary.withAlpha(179),
                          ),
                        ),
                        hintText: "Your name",
                        counterText: '',
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(textController.text);
                    },
                    child: Text(
                      'Submit',
                      style: TextStyle(color: widget.customPrimary),
                    ),
                  ),
                ],
                actionsPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              );
            },
          ).then((value) {
            // Get player name from dialog
            if (value != null && value.isNotEmpty) {
              playerName = value;
            }
          });
        }

        await databaseRef.update(
            {'best_time': _currentTime, 'best_player_name': playerName});

        setState(() {
          _currentPuzzle = _currentPuzzle.copyWith(
            bestTime: _currentTime,
            bestPlayerName: playerName,
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Congratulations! You set a new record time!'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else if (isUserBestTime && mounted) {
        // If only beat personal best, show a different message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You set a new personal best time!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update best time: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // Show completion dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          // Check if this run was a personal best
          final isPersonalBest = _currentTime < _userBestTime ||
              (_userBestTime == _currentTime &&
                  _userBestTime != double.infinity);

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 12,
            backgroundColor: Colors.white,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // Main dialog content
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 70, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      const Text(
                        'Puzzle Solved!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Level completed text
                      Text(
                        'You completed Level ${_extractLevelNumber(_currentPuzzle.title)}!',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Time container
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: widget.customPrimary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            // YOUR TIME label
                            Text(
                              'YOUR TIME',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                                color: widget.customPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Time value
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.timer,
                                  color: widget.customPrimary,
                                  size: 30,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatTime(
                                      _elapsedSeconds, _elapsedMilliseconds),
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: widget.customPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Personal best badge if achieved
                      if (isPersonalBest)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.amber.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.star,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'PERSONAL BEST!',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber,
                                      ),
                                    ),
                                    Text(
                                      'You beat your previous best time',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.amber.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Record badge if achieved
                      if (_currentTime < _currentPuzzle.bestTime)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: widget.customSecondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: widget.customSecondary.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: widget.customSecondary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.emoji_events,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'NEW RECORD!',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: widget.customSecondary,
                                          ),
                                        ),
                                        if (playerName.isNotEmpty &&
                                            playerName != "Unknown")
                                          Text(
                                            ' (${playerName})',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              fontStyle: FontStyle.italic,
                                              color: widget.customSecondary
                                                  .withOpacity(0.8),
                                            ),
                                          ),
                                      ],
                                    ),
                                    Text(
                                      'You beat the previous best time',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: widget.customSecondary
                                            .withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 30),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Play Again button
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _resetPuzzle();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: Text(
                                'Play Again',
                                style: TextStyle(
                                  color: widget.customPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),

                          // Back to List button
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.of(context)
                                  .pop(); // Go back to the puzzle list
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.customPrimary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            child: const Text(
                              'Back to List',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Medal icon positioned on top
                Positioned(
                  top: -40,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: widget.customPrimary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.workspace_premium,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
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

  String _formatTime(int seconds, double milliseconds) {
    // Calculate total seconds including the fractional part
    final totalSeconds = seconds + milliseconds;

    // Extract minutes and seconds
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    // Format milliseconds with just 1 decimal place to save space
    final formattedMilliseconds =
        (milliseconds * 10).round().toString().padLeft(1, '0');

    // Format as minutes:seconds.milliseconds for better space efficiency
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}.${formattedMilliseconds}';
  }

  @override
  Widget build(BuildContext context) {
    final levelNumber = _extractLevelNumber(_currentPuzzle.title);

    return WillPopScope(
      onWillPop: () async {
        if (_isPlaying) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                  const SizedBox(width: 8),
                  const Text('Leave Puzzle?'),
                ],
              ),
              content:
                  const Text('Your progress will be lost if you leave now.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Stay',
                      style: TextStyle(color: widget.customPrimary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Leave'),
                ),
              ],
            ),
          );
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: null,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () async {
              if (_isPlaying) {
                final shouldPop = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red),
                        const SizedBox(width: 8),
                        const Text('Leave Puzzle?'),
                      ],
                    ),
                    content: const Text(
                        'Your progress will be lost if you leave now.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text('Stay',
                            style: TextStyle(color: widget.customPrimary)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Leave'),
                      ),
                    ],
                  ),
                );
                if (shouldPop ?? false) {
                  if (mounted) Navigator.of(context).pop();
                }
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  widget.customPrimary.withAlpha(26), // ~0.1 opacity
                  Colors.white,
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Timer card only at the top
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Timer card - only the current running time
                        Expanded(
                          child: TimerCard(
                            time: _formatTime(
                                _elapsedSeconds, _elapsedMilliseconds),
                            isRunning: _isPlaying,
                            customPrimary: widget.customPrimary,
                            onReset: _resetPuzzle,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Puzzle title
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    child: Text(
                      _currentPuzzle.title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: widget.customPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Puzzle description
                  if (_currentPuzzle.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 2),
                      child: Text(
                        _currentPuzzle.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Puzzle grid - increase the space allocated to the grid
                  Expanded(
                    flex:
                        6, // Increase flex for more space since we removed hints
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        child: PuzzleGrid(
                          grid: _currentPuzzle.grid,
                          onTileTap: _handleTileTap,
                        ),
                      ),
                    ),
                  ),

                  // Best times section below the grid
                  Padding(
                    padding: const EdgeInsets.fromLTRB(1, 2, 16, 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Section header
                        Row(
                          children: [
                            Icon(
                              Icons.timer,
                              color: widget.customPrimary.withOpacity(0.7),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "BEST TIMES",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                                color: widget.customPrimary.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Time cards
                        SizedBox(
                          height: 70,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Best time card
                              Expanded(
                                child: BestTimeCard(
                                  bestTime: _formatTime(
                                    _currentPuzzle.bestTime.floor(),
                                    _currentPuzzle.bestTime % 1,
                                  ),
                                  customSecondary: widget.customSecondary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              // User's best time card
                              Expanded(
                                child: UserBestTimeCard(
                                  userBestTime: _userBestTime != double.infinity
                                      ? _formatTime(
                                          _userBestTime.floor(),
                                          _userBestTime % 1,
                                        )
                                      : "",
                                  customColor: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

class TimerCard extends StatelessWidget {
  final String time;
  final bool isRunning;
  final Color customPrimary;
  final VoidCallback onReset;

  const TimerCard({
    super.key,
    required this.time,
    required this.isRunning,
    required this.customPrimary,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      height: 60, // Reduced height
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13), // ~0.05 opacity
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: customPrimary.withAlpha(51), // ~0.2 opacity
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.timer,
            color: customPrimary,
            size: 20, // Slightly reduced
          ),
          const SizedBox(width: 8),
          // Expanded makes the text use the available space
          Expanded(
            child: Text(
              time,
              style: TextStyle(
                fontSize: 20, // Slightly reduced
                fontWeight: FontWeight.bold,
                color: customPrimary,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isRunning) ...[
            const SizedBox(width: 8),
            Container(
              width: 8, // Slightly reduced
              height: 8, // Slightly reduced
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withAlpha(128), // ~0.5 opacity
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(width: 16), // Increased spacing before restart button
          // Restart button
          GestureDetector(
            onTap: onReset,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: customPrimary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.refresh,
                color: customPrimary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BestTimeCard extends StatelessWidget {
  final String bestTime;
  final Color customSecondary;

  const BestTimeCard({
    super.key,
    required this.bestTime,
    required this.customSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      height: 70, // Reduced height
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13), // ~0.05 opacity
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: customSecondary.withAlpha(51), // ~0.2 opacity
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Use min size
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "WORLD BEST",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: customSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2), // Reduced spacing
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emoji_events_outlined,
                color: customSecondary,
                size: 18, // Reduced size
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  bestTime,
                  style: TextStyle(
                    fontSize: 16, // Reduced font size
                    fontWeight: FontWeight.bold,
                    color: customSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class UserBestTimeCard extends StatelessWidget {
  final String userBestTime;
  final Color customColor;

  const UserBestTimeCard({
    super.key,
    required this.userBestTime,
    required this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      height: 70, // Reduced height
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13), // ~0.05 opacity
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: customColor.withAlpha(51), // ~0.2 opacity
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Use min size
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "YOUR BEST",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: customColor,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2), // Reduced spacing
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.star_outline_rounded,
                color: customColor,
                size: 18, // Reduced size
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  userBestTime.isEmpty ? "No Time Yet" : userBestTime,
                  style: TextStyle(
                    fontSize: 16, // Reduced font size
                    fontWeight: FontWeight.bold,
                    color: customColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
