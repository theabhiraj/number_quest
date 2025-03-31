import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tile_widget.dart';

class PuzzleGrid extends StatefulWidget {
  final List<List<int>> grid;
  final Function(int, int, {String? direction}) onTileTap;

  const PuzzleGrid({
    super.key,
    required this.grid,
    required this.onTileTap,
  });

  @override
  State<PuzzleGrid> createState() => _PuzzleGridState();
}

class _PuzzleGridState extends State<PuzzleGrid> with TickerProviderStateMixin {
  int? _selectedRow;
  int? _selectedCol;
  Offset? _dragStart;
  late AnimationController _gridAnimationController;
  late Animation<double> _gridScaleAnimation;

  @override
  void initState() {
    super.initState();
    _gridAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _gridScaleAnimation = CurvedAnimation(
      parent: _gridAnimationController,
      curve: Curves.easeOutBack,
    );

    _gridAnimationController.forward();
  }

  @override
  void dispose() {
    _gridAnimationController.dispose();
    super.dispose();
  }

  List<String> _getMovableDirections(int row, int col) {
    List<String> directions = [];

    // Check Up
    if (row > 0 &&
        row - 1 < widget.grid.length &&
        col < widget.grid[row - 1].length &&
        widget.grid[row - 1][col] == 0) {
      directions.add('up');
    }

    // Check Down
    if (row + 1 < widget.grid.length &&
        col < widget.grid[row + 1].length &&
        widget.grid[row + 1][col] == 0) {
      directions.add('down');
    }

    // Check Left
    if (col > 0 && widget.grid[row][col - 1] == 0) {
      directions.add('left');
    }

    // Check Right
    if (col + 1 < widget.grid[row].length && widget.grid[row][col + 1] == 0) {
      directions.add('right');
    }

    return directions;
  }

  Map<String, List<int>> _getAdjacentEmptyPositions(int row, int col) {
    Map<String, List<int>> positions = {};

    // Check Up
    if (row > 0 &&
        row - 1 < widget.grid.length &&
        col < widget.grid[row - 1].length &&
        widget.grid[row - 1][col] == 0) {
      positions['up'] = [row - 1, col];
    }

    // Check Down
    if (row + 1 < widget.grid.length &&
        col < widget.grid[row + 1].length &&
        widget.grid[row + 1][col] == 0) {
      positions['down'] = [row + 1, col];
    }

    // Check Left
    if (col > 0 && widget.grid[row][col - 1] == 0) {
      positions['left'] = [row, col - 1];
    }

    // Check Right
    if (col + 1 < widget.grid[row].length && widget.grid[row][col + 1] == 0) {
      positions['right'] = [row, col + 1];
    }

    return positions;
  }

  int _getMaxColumns() {
    int maxCols = 0;
    for (var row in widget.grid) {
      if (row.length > maxCols) maxCols = row.length;
    }
    return maxCols;
  }

  void _handleTileTap(int row, int col) {
    final movableDirections = _getMovableDirections(row, col);

    if (movableDirections.isEmpty) {
      // Not a movable tile
      return;
    }

    // Always show selection, regardless of number of directions
    setState(() {
      _selectedRow = row;
      _selectedCol = col;
    });
  }

  void _handleEmptyTileTap(int row, int col, String direction) {
    if (_selectedRow != null && _selectedCol != null) {
      widget.onTileTap(_selectedRow!, _selectedCol!, direction: direction);
      setState(() {
        _selectedRow = null;
        _selectedCol = null;
      });
    }
  }

  void _handleDragStart(int row, int col, DragStartDetails details) {
    final movableDirections = _getMovableDirections(row, col);
    if (movableDirections.isEmpty) return;

    setState(() {
      _selectedRow = row;
      _selectedCol = col;
      _dragStart = details.localPosition;
    });
  }

  void _handleDragUpdate(int row, int col, DragUpdateDetails details,
      Map<String, List<int>> adjacentEmptyPositions) {
    if (_selectedRow != row || _selectedCol != col || _dragStart == null)
      return;

    // Calculate the drag direction and distance
    final dragVector = details.localPosition - _dragStart!;
    final dragDistance = dragVector.distance;

    // If the drag is too small, do nothing
    if (dragDistance < 10) return;

    // Determine the primary drag direction
    final dragAngle = math.atan2(dragVector.dy, dragVector.dx);
    String? dragDirection;

    // Convert angle to direction
    if (dragAngle.abs() < math.pi / 4) {
      dragDirection = 'right';
    } else if (dragAngle.abs() > 3 * math.pi / 4) {
      dragDirection = 'left';
    } else if (dragAngle > 0) {
      dragDirection = 'down';
    } else {
      dragDirection = 'up';
    }

    // Check if this direction is valid for this tile
    if (adjacentEmptyPositions.containsKey(dragDirection)) {
      // Move the tile
      widget.onTileTap(row, col, direction: dragDirection);
      setState(() {
        _selectedRow = null;
        _selectedCol = null;
        _dragStart = null;
      });
    }
  }

  void _handleDragEnd(int row, int col) {
    setState(() {
      _dragStart = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxColumns = _getMaxColumns();
    final theme = Theme.of(context);

    // Calculate optimal tile size based on grid size
    final Size screenSize = MediaQuery.of(context).size;
    final double availableWidth = screenSize.width - 80; // Account for padding
    final double maxTileSize = availableWidth / maxColumns;

    // Adjust tile size based on grid size
    final double tileSize = maxColumns > 4 ? maxTileSize * 0.9 : 75;

    // Adjust spacing based on grid size
    final double spacing = maxColumns > 4 ? 6 : 10;

    // Get adjacent empty positions for the selected tile
    Map<String, List<int>> adjacentEmptyPositions = {};
    if (_selectedRow != null && _selectedCol != null) {
      adjacentEmptyPositions =
          _getAdjacentEmptyPositions(_selectedRow!, _selectedCol!);
    }

    return GestureDetector(
      // Cancel selection when tapping outside
      onTap: () {
        if (_selectedRow != null) {
          setState(() {
            _selectedRow = null;
            _selectedCol = null;
          });
        }
      },
      child: ScaleTransition(
        scale: _gridScaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.15),
                blurRadius: 25,
                spreadRadius: 6,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 7,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.15),
              width: 2.5,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(maxColumns > 4
                ? 12.0
                : 20.0), // Reduce padding for larger grids
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: maxColumns,
                childAspectRatio: 1,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
              ),
              itemCount: widget.grid.length * maxColumns,
              itemBuilder: (context, index) {
                final int row = index ~/ maxColumns;
                final int col = index % maxColumns;

                // Check if this position exists in the irregular grid
                if (row >= widget.grid.length ||
                    col >= widget.grid[row].length) {
                  return const SizedBox(); // Empty space for non-existent positions
                }

                final value = widget.grid[row][col];

                // Empty tile (0)
                if (value == 0) {
                  // Check if this empty tile is adjacent to the selected tile
                  String? foundDirection;
                  adjacentEmptyPositions.forEach((direction, position) {
                    if (position[0] == row && position[1] == col) {
                      foundDirection = direction;
                    }
                  });

                  if (foundDirection != null) {
                    // Show a styled indicator on this empty tile
                    return TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.8, end: 1.0),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: child,
                        );
                      },
                      child: GestureDetector(
                        onTap: () =>
                            _handleEmptyTileTap(row, col, foundDirection!),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                theme.colorScheme.secondary.withOpacity(0.9),
                                theme.colorScheme.secondary,
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.secondary
                                    .withOpacity(0.5),
                                spreadRadius: 2,
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              _getDirectionIcon(foundDirection!),
                              color: Colors.white,
                              // Scale icon based on grid size
                              size: maxColumns > 4 ? 24 : 36,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 3,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  } else {
                    // Regular empty tile with improved styling
                    return Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius:
                            BorderRadius.circular(maxColumns > 4 ? 12 : 18),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.25),
                          width: 1.5,
                        ),
                      ),
                    );
                  }
                }

                // Handle tile
                bool isSelected = _selectedRow == row && _selectedCol == col;
                final movableDirections = _getMovableDirections(row, col);

                return Hero(
                  tag: 'tile_${row}_${col}_$value',
                  child: GestureDetector(
                    onPanStart: (details) =>
                        _handleDragStart(row, col, details),
                    onPanUpdate: (details) => _handleDragUpdate(
                        row, col, details, adjacentEmptyPositions),
                    onPanEnd: (_) => _handleDragEnd(row, col),
                    child: TileWidget(
                      value: value,
                      movableDirections: movableDirections,
                      onTap: () => _handleTileTap(row, col),
                      onDirectionalTap:
                          (direction) {}, // Not used in this approach
                      size: tileSize, // Use dynamic size
                      isSelected: isSelected,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  IconData _getDirectionIcon(String direction) {
    switch (direction) {
      case 'up':
        return Icons.arrow_upward_rounded;
      case 'down':
        return Icons.arrow_downward_rounded;
      case 'left':
        return Icons.arrow_back_rounded;
      case 'right':
        return Icons.arrow_forward_rounded;
      default:
        return Icons.touch_app_rounded;
    }
  }
}
