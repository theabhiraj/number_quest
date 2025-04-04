// ignore_for_file: unused_local_variable

import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/puzzle.dart';
import '../services/connectivity_service.dart';
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
  bool _isPlayerNameLoaded = false;
  Timer? _connectivityCheckTimer;
  final ConnectivityService _connectivityService = ConnectivityService();
  DateTime? _startTime; // Add start time tracking

  @override
  void initState() {
    super.initState();
    // Create a deep copy of the puzzle to work with
    _currentPuzzle = widget.puzzle.copyWith();

    // Setup animations with smoother transition
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(
          milliseconds: 800), // Increased from 600ms for smoother animation
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic, // Changed to a smoother curve
    );

    _animationController.forward();

    // Load user's best time from local storage
    _loadUserBestTime();
    _loadPlayerName();

    // Check connectivity when screen opens
    _connectivityService.checkConnectionAndShowDialog();

    // Start periodic connectivity checks
    _connectivityCheckTimer = Timer.periodic(const Duration(seconds: 30),
        (_) => _connectivityService.checkConnectionAndShowDialog());
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

  Future<void> _loadPlayerName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String savedName = prefs.getString('player_name') ?? "Unknown";
      setState(() {
        playerName = savedName;
        _isPlayerNameLoaded = true;
      });
    } catch (e) {
      debugPrint('Error loading player name: $e');
    }
  }

  Future<void> _savePlayerName(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('player_name', name);
      setState(() {
        playerName = name;
      });
    } catch (e) {
      debugPrint('Error saving player name: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _connectivityCheckTimer?.cancel();
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
        _startTime = DateTime.now();
      });
      _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
        if (_startTime != null) {
          final now = DateTime.now();
          final difference = now.difference(_startTime!);

          // Calculate total seconds with millisecond precision
          final totalSeconds = difference.inMilliseconds / 1000.0;

          setState(() {
            _elapsedSeconds = totalSeconds.floor();
            _elapsedMilliseconds = totalSeconds - _elapsedSeconds;
            _currentTime = totalSeconds;
          });
        }
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
    // Reset the puzzle state
    setState(() {
      _currentPuzzle = widget.puzzle.copyWith();
      _elapsedSeconds = 0;
      _elapsedMilliseconds = 0;
      _isPlaying = false;
      _startTime = null;

      // Cancel any active timer
      if (_timer != null && _timer!.isActive) {
        _timer!.cancel();
      }
    });

    // Use a small delay to allow the grid to be built with new state
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        // Force a rebuild of the grid by triggering a setState
        setState(() {});
      }
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

      final gridCopy = List<List<int>>.from(
        _currentPuzzle.grid.map((row) => List<int>.from(row)),
      );

      // Swap the tile with the empty space
      final temp = gridCopy[row][col];
      gridCopy[row][col] = 0;
      gridCopy[targetEmptyPos[0]][targetEmptyPos[1]] = temp;

      // Update the puzzle with the new grid
      setState(() {
        _currentPuzzle = _currentPuzzle.copyWith(grid: gridCopy);
      });

      // Check if puzzle is solved - always check in a microtask to avoid UI delays
      Future.microtask(() {
        if (_currentPuzzle.isSolved()) {
          _handlePuzzleSolved();
        }
      });
    }
  }

  Future<void> _handlePuzzleSolved() async {
    // Calculate the final time based on the start time for accuracy
    if (_startTime != null) {
      final endTime = DateTime.now();
      final difference = endTime.difference(_startTime!);
      _currentTime = difference.inMilliseconds / 1000.0;
      _elapsedSeconds = _currentTime.floor();
      _elapsedMilliseconds = _currentTime - _elapsedSeconds;
    }

    // Stop the timer
    _stopTimer();

    // Process game completion data first to ensure state is properly updated
    await _processCompletionData();

    // Show completion dialog after data processing
    if (mounted) {
      // Check if this run was a personal best
      final isPersonalBest =
          _currentTime < _userBestTime || (_userBestTime == double.infinity);

      // Get screen size for responsive sizing
      final size = MediaQuery.of(context).size;
      final isSmallScreen = size.width < 360 || size.height < 600;

      // Add a short delay to ensure UI is ready before showing dialog
      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted) return; // Safety check

      // Force a rebuild of the grid to clear any selections
      setState(() {});

      // Ensure the dialog is shown on the main thread
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext dialogContext) {
              // Force layout rebuild on dialog
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (dialogContext.mounted) {
                  // Trigger a small visual update to ensure proper rendering
                  Future.delayed(const Duration(milliseconds: 50), () {
                    if (dialogContext.mounted) {
                      (dialogContext as Element).markNeedsBuild();
                    }
                  });
                }
              });

              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 12,
                backgroundColor: Colors.white,
                // Use responsive inset padding based on screen size
                insetPadding: EdgeInsets.symmetric(
                  horizontal: size.width * (isSmallScreen ? 0.03 : 0.05),
                  vertical: size.height * (isSmallScreen ? 0.05 : 0.1),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: size.height * 0.8,
                    maxWidth: size.width * 0.9,
                  ),
                  child: SingleChildScrollView(
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.timer,
                                          color: widget.customPrimary,
                                          size: 30,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatTime(_elapsedSeconds,
                                              _elapsedMilliseconds),
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 30 : 36,
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                                color: Colors.amber
                                                    .withOpacity(0.7),
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
                                    color:
                                        widget.customSecondary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: widget.customSecondary
                                          .withOpacity(0.3),
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  'NEW RECORD!',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        widget.customSecondary,
                                                  ),
                                                ),
                                                if (playerName.isNotEmpty &&
                                                    playerName != "Unknown")
                                                  Text(
                                                    ' (${playerName})',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                      color: widget
                                                          .customSecondary
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

                              SizedBox(height: isSmallScreen ? 20 : 30),

                              // Action buttons in wrapped row to prevent overflow
                              Wrap(
                                alignment: WrapAlignment.spaceEvenly,
                                spacing: 8,
                                runSpacing: 12,
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

                              // Next Level button
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    // Pop dialog first
                                    Navigator.of(context).pop();

                                    // Pop current level and pass 'next' parameter to indicate next level should be loaded
                                    Navigator.of(context).pop('next');
                                  },
                                  icon: const Icon(Icons.arrow_forward_rounded),
                                  label: const Text(
                                    'Next Level',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: widget.customSecondary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: isSmallScreen ? 10 : 12,
                                    ),
                                  ),
                                ),
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
                  ),
                ),
              );
            },
          );
        }
      });
    }
  }

  Future<void> _processCompletionData() async {
    try {
      // Call the onLevelComplete callback if provided - call this first to update level status
      if (widget.onLevelComplete != null) {
        widget.onLevelComplete!();
      }

      // Update user's best time if this time is better
      bool isUserBestTime = false;
      if (_currentTime < _userBestTime || _userBestTime == double.infinity) {
        _userBestTime = _currentTime;
        await _saveUserBestTime(_currentTime);
        isUserBestTime = true;
      }

      if (_currentTime < _currentPuzzle.bestTime) {
        // Only ask for player name if we don't have one yet
        if (mounted && (playerName == "Unknown" || !_isPlayerNameLoaded)) {
          TextEditingController textController =
              TextEditingController(text: "");

          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Wrap(
                  spacing: 8,
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: widget.customSecondary,
                      size: 28,
                    ),
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
              _savePlayerName(playerName); // Save the name for future use
            }
          });
        }

        try {
          // Check connectivity before updating Firebase
          final isConnected = await _connectivityService.checkConnection();
          if (!isConnected) {
            // Show dialog that requires internet connection
            _connectivityService.checkConnectionAndShowDialog();
            return;
          }

          // Update Firebase database with new best time
          final databaseRef = FirebaseDatabase.instance
              .ref()
              .child('numberquests/puzzles/${_currentPuzzle.id}');

          // Convert current time to minutes for Firebase storage
          final minutesOnly = _currentTime / 60;

          await databaseRef.update(
              {'best_time': minutesOnly, 'best_player_name': playerName});

          if (mounted) {
            setState(() {
              _currentPuzzle = _currentPuzzle.copyWith(
                bestTime: _currentTime, // Keep the full time in local model
                bestPlayerName: playerName,
              );
            });
          }
        } catch (e) {
          // Just log the error, don't interrupt user experience with error messages
          debugPrint('Error updating database best time: $e');
        }
      }
    } catch (e) {
      debugPrint('Error in _processCompletionData: $e');
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

  // Format time for display with seconds and milliseconds
  String _formatTime(int seconds, double milliseconds) {
    // Extract minutes and seconds
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    // Format milliseconds with 2 decimal places for more precise display
    // Ensure we're rounding correctly to get accurate millisecond values
    final formattedMilliseconds =
        (milliseconds * 100).round().toString().padLeft(2, '0');

    // Format as minutes:seconds:milliseconds
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}:${formattedMilliseconds}';
  }

  // Format time for display in the UI header - no arguments version
  String _formatCurrentTime() {
    return _formatTime(_elapsedSeconds, _elapsedMilliseconds);
  }

  // Format time for display in best times section
  String _formatDisplayTime(double time) {
    if (time == double.infinity) {
      return '00:00:00';
    }

    final seconds = time.floor();
    final milliseconds = (time - seconds);
    return _formatTime(seconds, milliseconds);
  }

  void _showHint() {
    // Use hints array instead of hint property
    if (_currentPuzzle.hints.isEmpty) return;

    // Show a random hint
    final hint = _currentPuzzle
        .hints[DateTime.now().millisecond % _currentPuzzle.hints.length];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Wrap(
          spacing: 8,
          children: [
            Icon(Icons.lightbulb, color: widget.customSecondary),
            const Text('Hint'),
          ],
        ),
        content: Text(hint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text('Got it', style: TextStyle(color: widget.customPrimary)),
          ),
        ],
      ),
    );
  }

  void _checkSolution() {
    if (_currentPuzzle.isSolved()) {
      _handlePuzzleSolved();
    } else {
      // Show a message that the puzzle is not solved yet
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not solved yet. Keep trying!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Wrap(
          spacing: 8,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            const Text('Leave Puzzle?'),
          ],
        ),
        content: const Text('Your progress will be lost if you leave now.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Stay', style: TextStyle(color: widget.customPrimary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive design
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;
    final isMediumScreen = screenSize.width >= 360 && screenSize.width < 600;
    final isTablet = screenSize.width >= 600;

    // Calculate responsive padding and sizing
    final horizontalPadding = isTablet ? 24.0 : (isMediumScreen ? 16.0 : 12.0);
    final verticalPadding = isTablet ? 20.0 : (isMediumScreen ? 16.0 : 12.0);
    final titleFontSize = isTablet ? 28.0 : (isMediumScreen ? 24.0 : 20.0);
    final subtitleFontSize = isTablet ? 18.0 : (isMediumScreen ? 16.0 : 14.0);
    final buttonPadding = isTablet
        ? const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
        : (isMediumScreen
            ? const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 10));

    return WillPopScope(
      onWillPop: () async {
        if (_isPlaying) {
          _showExitConfirmation();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: widget.customPrimary,
          title: Row(
            children: [
              // CircleAvatar(
              //   backgroundColor: Colors.white.withOpacity(0.2),
              //   child: Text(
              //     _extractLevelNumber(_currentPuzzle.title).toString(),
              //     style: TextStyle(
              //       color: Colors.white,
              //       fontWeight: FontWeight.bold,
              //       fontSize: isTablet ? 16 : 14,
              //     ),
              //   ),
              // ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No. Quest',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 15,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              if (_isPlaying) {
                _showExitConfirmation();
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            // Timer display
            Container(
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 12 : 8),
              constraints: BoxConstraints(maxWidth: isTablet ? 200 : 160),
              child: Center(
                child: RichText(
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Time: ',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(
                        text: _formatCurrentTime(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          fontSize: isTablet ? 16 : 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Puzzle header with instructions and best times
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding / 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Instructions - use description instead of instructions
                    Padding(
                      padding: EdgeInsets.only(bottom: verticalPadding / 2),
                      child: Text(
                        _currentPuzzle.description,
                        style: TextStyle(
                          fontSize: subtitleFontSize,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    // Best times
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Global best time
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: widget.customSecondary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.emoji_events_outlined,
                                size: isTablet ? 18 : 14,
                                color: widget.customSecondary,
                              ),
                            ),
                            SizedBox(width: isTablet ? 8 : 4),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Best: ',
                                    style: TextStyle(
                                      fontSize: isTablet ? 15 : 13,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  TextSpan(
                                    text: _formatDisplayTime(
                                        _currentPuzzle.bestTime),
                                    style: TextStyle(
                                      fontSize: isTablet ? 15 : 13,
                                      fontWeight: FontWeight.w600,
                                      color: widget.customSecondary,
                                    ),
                                  ),
                                  if (_currentPuzzle
                                          .bestPlayerName.isNotEmpty &&
                                      _currentPuzzle.bestPlayerName !=
                                          "Infinity" &&
                                      _currentPuzzle.bestTime !=
                                          double.infinity)
                                    TextSpan(
                                      text:
                                          " (${_currentPuzzle.bestPlayerName})",
                                      style: TextStyle(
                                        fontSize: isTablet ? 14 : 12,
                                        color: widget.customSecondary
                                            .withOpacity(0.8),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // User's best time
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.person,
                                size: isTablet ? 18 : 14,
                                color: Colors.amber,
                              ),
                            ),
                            SizedBox(width: isTablet ? 8 : 4),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Your best: ',
                                    style: TextStyle(
                                      fontSize: isTablet ? 15 : 13,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  TextSpan(
                                    text: _formatDisplayTime(_userBestTime),
                                    style: TextStyle(
                                      fontSize: isTablet ? 15 : 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Puzzle grid (main content)
              Expanded(
                child: Center(
                  child: Container(
                    padding: EdgeInsets.all(horizontalPadding),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: PuzzleGrid(
                        grid: _currentPuzzle.grid,
                        onTileTap: _handleTileTap,
                      ),
                    ),
                  ),
                ),
              ),
              // Bottom control buttons
              Container(
                padding: EdgeInsets.all(horizontalPadding),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Reset button
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        'Reset',
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: buttonPadding,
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _resetPuzzle,
                    ),
                    // Hint button
                    ElevatedButton.icon(
                      icon: const Icon(Icons.lightbulb_outline),
                      label: Text(
                        'Hint',
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: buttonPadding,
                        backgroundColor:
                            widget.customSecondary.withOpacity(0.1),
                        foregroundColor: widget.customSecondary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _currentPuzzle.hints.isEmpty
                          ? null
                          : () => _showHint(),
                    ),
                    // Check button
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        'Check',
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: buttonPadding,
                        backgroundColor: widget.customPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _checkSolution(),
                    ),
                  ],
                ),
              ),
            ],
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
                  userBestTime.isEmpty || userBestTime == ""
                      ? "00:00:00"
                      : userBestTime,
                  style: TextStyle(
                    fontSize: 16, // Reduced font size
                    fontWeight: FontWeight.bold,
                    color: customColor,
                  ),
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
