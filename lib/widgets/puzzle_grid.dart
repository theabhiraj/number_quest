// ignore_for_file: unused_local_variable

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
  late AnimationController _selectionAnimController;
  late Animation<double> _pulseAnimation;
  DateTime? _lastDragTime;
  bool _initialRender = true;

  @override
  void initState() {
    super.initState();
    _gridAnimationController = AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 800), // Increased for smoother animation
    );

    _gridScaleAnimation = CurvedAnimation(
      parent: _gridAnimationController,
      curve: Curves.easeOutBack,
    );

    // Add pulsating animation for selected tile
    _selectionAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _selectionAnimController,
        curve: Curves.easeInOut,
      ),
    );

    _selectionAnimController.repeat(reverse: true);
    _gridAnimationController.forward();
    
    // Set initial render to true (new)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _initialRender = false;
      });
    });
  }

  @override
  void dispose() {
    _gridAnimationController.dispose();
    _selectionAnimController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PuzzleGrid oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Clear selection when the grid changes (on reset or new puzzle)
    if (oldWidget.grid != widget.grid) {
      setState(() {
        _selectedRow = null;
        _selectedCol = null;
        _dragStart = null;
        _lastDragTime = null; // Reset drag timer when grid changes
      });
    }
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
      // Not a movable tile, clear any existing selection
      setState(() {
        _selectedRow = null;
        _selectedCol = null;
        _lastDragTime = null; // Reset drag timer on tap
      });
      return;
    }

    // If the tile is already selected, deselect it
    if (_selectedRow == row && _selectedCol == col) {
      setState(() {
        _selectedRow = null;
        _selectedCol = null;
        _lastDragTime = null; // Reset drag timer on tap
      });
      return;
    }

    // Otherwise, show selection to let user choose direction or slide
    setState(() {
      _selectedRow = row;
      _selectedCol = col;
      _lastDragTime = null; // Reset drag timer on tap
    });
  }

  void _handleEmptyTileTap(int row, int col, String direction) {
    if (_selectedRow != null && _selectedCol != null) {
      widget.onTileTap(_selectedRow!, _selectedCol!, direction: direction);

      // Clear selection
      setState(() {
        _selectedRow = null;
        _selectedCol = null;
        _lastDragTime = null; // Reset drag timer
      });
    }
  }

  void _handleDragStart(int row, int col, DragStartDetails details) {
    final movableDirections = _getMovableDirections(row, col);
    if (movableDirections.isEmpty) return;

    // Set initial selected position and drag start for tracking movement
    setState(() {
      _selectedRow = row;
      _selectedCol = col;
      _dragStart = details.localPosition;
    });
  }

  void _handleDragUpdate(int row, int col, DragUpdateDetails details,
      Map<String, List<int>> adjacentEmptyPositions) {
    if (_selectedRow == null || _selectedCol == null || _dragStart == null)
      return;

    // Calculate the drag direction and distance
    final dragVector = details.localPosition - _dragStart!;
    final dragDistance = dragVector.distance;

    // If the drag is too small, do nothing
    if (dragDistance < 8) // Increased threshold to prevent accidental slides
      return;

    // Track the current time
    final now = DateTime.now();

    // Add a cooldown period to prevent rapid multiple slides
    if (_lastDragTime != null) {
      final timeSinceLastDrag = now.difference(_lastDragTime!);
      if (timeSinceLastDrag.inMilliseconds < 200) {
        // 200ms cooldown
        return;
      }
    }

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

    // Get the current adjacent empty positions for wherever the selected tile is now
    Map<String, List<int>> currentAdjacentEmptyPos =
        _getAdjacentEmptyPositions(_selectedRow!, _selectedCol!);

    // Check if this direction is valid for this tile
    if (currentAdjacentEmptyPos.containsKey(dragDirection)) {
      // Get the position of the empty tile in the direction we're moving
      List<int> emptyPos = currentAdjacentEmptyPos[dragDirection]!;

      // Move the tile in the drag direction
      widget.onTileTap(_selectedRow!, _selectedCol!, direction: dragDirection);

      // Update selection to track the moved tile (which is now at the empty position)
      setState(() {
        // Update the selected position to where the empty tile was
        _selectedRow = emptyPos[0];
        _selectedCol = emptyPos[1];

        // Reset drag start to the current position for continuous movement
        _dragStart = details.localPosition;
      });

      // Update the last drag time
      _lastDragTime = now;
    }
  }

  // Add pan end handler to clean up selection when touch is released
  void _handleDragEnd(int row, int col, DragEndDetails details) {
    // Reset the drag time tracker
    _lastDragTime = null;

    // Clear selection and drag start state when touch is released
    setState(() {
      _selectedRow = null;
      _selectedCol = null;
      _dragStart = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final ThemeData theme = Theme.of(context);
    final bool isTablet = screenSize.shortestSide > 600;
    
    // Calculate grid size (use the maximum of rows or columns)
    int gridSize = math.max(_getMaxColumns(), widget.grid.length);
    
    // Determine if this is a large grid (6x6 or larger)
    final bool isLargeGrid = gridSize >= 6;
    final bool isVeryLargeGrid = gridSize >= 8;
    
    // Calculate appropriate padding for container based on grid size
    final double containerPaddingValue = isTablet
        ? (isVeryLargeGrid ? 8.0 : 12.0)
        : (isVeryLargeGrid ? 4.0 : (isLargeGrid ? 6.0 : 8.0));
    
    // Calculate appropriate padding between tiles based on grid size
    final double tilePadding = isTablet
        ? (isVeryLargeGrid ? 2.0 : (isLargeGrid ? 3.0 : 4.0))
        : (isVeryLargeGrid ? 1.0 : (isLargeGrid ? 1.5 : 2.0));
    
    // Calculate available space for the grid, accounting for padding
    final double maxAvailableWidth = screenSize.width - (containerPaddingValue * 2);
    final double maxAvailableHeight = screenSize.height * 0.7; // Use 70% of height max
    
    // Determine the smaller dimension to create a square grid area
    final double availableGridArea = math.min(maxAvailableWidth, maxAvailableHeight);
    
    // Calculate a consistent square tile size
    double calculatedTileSize = (availableGridArea / gridSize) - (tilePadding * 2);
    
    // Apply minimum size constraints to ensure readability
    if (isVeryLargeGrid) {
      calculatedTileSize = math.max(calculatedTileSize, isTablet ? 45.0 : 28.0);
    } else if (isLargeGrid) {
      calculatedTileSize = math.max(calculatedTileSize, isTablet ? 55.0 : 35.0);
    } else {
      calculatedTileSize = math.max(calculatedTileSize, isTablet ? 65.0 : 45.0);
    }
    
    // Ensure tiles are square
    final double finalTileSize = calculatedTileSize;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate total grid size including padding
        final double totalWidth = (gridSize * (finalTileSize + (tilePadding * 2))) + (containerPaddingValue * 2);
        final double totalHeight = (widget.grid.length * (finalTileSize + (tilePadding * 2))) + (containerPaddingValue * 2);
        
        // Use the same dimensions for width and height to ensure a square grid
        final double containerSize = math.min(
          math.min(totalWidth, constraints.maxWidth),
          math.min(totalHeight, constraints.maxHeight)
        );
        
        // Always use the consistent size by returning an AnimatedContainer with fixed dimensions
        return Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: containerSize,
            height: containerSize,
            child: AnimatedScale(
              scale: _initialRender ? 1.0 : _gridScaleAnimation.value,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: Container(
                width: containerSize,
                height: containerSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isTablet ? 24 : 16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      spreadRadius: 0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    width: 1.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                margin: EdgeInsets.zero,
                padding: EdgeInsets.all(containerPaddingValue),
                child: Stack(
                  children: [
                    // Background grid pattern
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.05,
                        child: CustomPaint(
                          painter: GridPatternPainter(
                            gridSize: gridSize,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),

                    Center(
                      child: AspectRatio(
                        aspectRatio: gridSize / widget.grid.length,
                        child: Padding(
                          padding: EdgeInsets.all(isVeryLargeGrid ? 4.0 : (isLargeGrid ? 6.0 : 8.0)),
                          child: GridView.builder(
                            physics: NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: gridSize,
                              crossAxisSpacing: tilePadding * 2,
                              mainAxisSpacing: tilePadding * 2,
                              childAspectRatio: 1.0,
                            ),
                            itemCount: widget.grid.length * gridSize,
                            itemBuilder: (context, index) {
                              final rowIndex = index ~/ gridSize;
                              final colIndex = index % gridSize;
                              
                              // If rowIndex is out of range, return empty SizedBox
                              if (rowIndex >= widget.grid.length) {
                                return const SizedBox();
                              }
                              
                              final row = widget.grid[rowIndex];
                              
                              // If colIndex is out of range for this row, return rock placeholder
                              if (colIndex >= row.length) {
                                // Return rock placeholder
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(
                                        isLargeGrid ? (isTablet ? 10 : 8) : (isTablet ? 14 : 10)),
                                    border: Border.all(
                                      color: Colors.grey[900]!,
                                      width: 1.0,
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.grey[700]!,
                                        Colors.grey[900]!,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(isLargeGrid ? 0.2 : 0.3),
                                        blurRadius: isLargeGrid ? 2 : 3,
                                        spreadRadius: 0,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      // Rock texture pattern
                                      Positioned.fill(
                                        child: Opacity(
                                          opacity: 0.1,
                                          child: CustomPaint(
                                            painter: RockPatternPainter(),
                                          ),
                                        ),
                                      ),
                                      // Highlights and shadows for 3D effect
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    isLargeGrid ? (isTablet ? 8 : 6) : (isTablet ? 12 : 8)),
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Colors.white
                                                    .withOpacity(0.15),
                                                Colors.transparent,
                                                Colors.black.withOpacity(0.2),
                                              ],
                                              stops: const [0.0, 0.5, 1.0],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              
                              final value = row[colIndex];
                              final bool isSelected = _selectedRow == rowIndex && _selectedCol == colIndex;
                              final bool isMovable = _getMovableDirections(rowIndex, colIndex).isNotEmpty;
                              final Map<String, List<int>> adjacentEmptyPos = isMovable
                                  ? _getAdjacentEmptyPositions(rowIndex, colIndex)
                                  : {};
                              
                              // Get adjacent empty positions for the selected tile
                              Map<String, List<int>> selectedTileAdjacentEmptyPositions = {};
                              if (_selectedRow != null && _selectedCol != null) {
                                selectedTileAdjacentEmptyPositions =
                                    _getAdjacentEmptyPositions(_selectedRow!, _selectedCol!);
                              }

                              // Check if this empty cell is adjacent to the selected tile
                              String? directionFromSelected;
                              if (value == 0 && _selectedRow != null && _selectedCol != null) {
                                for (final entry in selectedTileAdjacentEmptyPositions.entries) {
                                  final List<int> pos = entry.value;
                                  if (pos[0] == rowIndex && pos[1] == colIndex) {
                                    directionFromSelected = entry.key;
                                    break;
                                  }
                                }
                              }

                              final bool isAdjacentEmpty = directionFromSelected != null;
                              
                              if (value == 0) {
                                // Empty space
                                return Container(
                                  decoration: isAdjacentEmpty
                                      ? BoxDecoration(
                                          color: theme.colorScheme.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                              isLargeGrid ? (isTablet ? 10 : 8) : (isTablet ? 14 : 10)),
                                          border: Border.all(
                                            color: theme.colorScheme.primary.withOpacity(0.3),
                                            width: isLargeGrid ? 1.5 : 2,
                                            style: BorderStyle.solid,
                                          ),
                                        )
                                      : BoxDecoration(
                                          color: theme.colorScheme.surfaceVariant,
                                          borderRadius: BorderRadius.circular(
                                              isLargeGrid ? (isTablet ? 10 : 8) : (isTablet ? 14 : 10)),
                                          border: Border.all(
                                            color: theme.colorScheme.outline.withOpacity(0.3),
                                            width: 1.0,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.1),
                                              blurRadius: 2,
                                              spreadRadius: 0,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                  child: isAdjacentEmpty
                                      ? Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                                isLargeGrid ? (isTablet ? 8 : 6) : (isTablet ? 12 : 8)),
                                            splashColor: theme.colorScheme.primary.withOpacity(0.3),
                                            onTap: () {
                                              if (directionFromSelected != null) {
                                                _handleEmptyTileTap(
                                                    rowIndex, colIndex, directionFromSelected);
                                              }
                                            },
                                            child: Center(
                                              child: Icon(
                                                _getDirectionIcon(directionFromSelected),
                                                color: theme.colorScheme.primary.withOpacity(0.6),
                                                size: isLargeGrid ? finalTileSize / 2.8 : finalTileSize / 2.5,
                                                shadows: [
                                                  Shadow(
                                                    color: Colors.black.withOpacity(0.2),
                                                    blurRadius: 3,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        )
                                      : null,
                                );
                              } else {
                                // Regular tile
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                        isLargeGrid ? (isTablet ? 10 : 8) : (isTablet ? 14 : 10)),
                                    boxShadow: [
                                      if (isSelected)
                                        BoxShadow(
                                          color: Colors.black.withOpacity(isLargeGrid ? 0.15 : 0.2),
                                          blurRadius: isLargeGrid ? 6 : 8,
                                          spreadRadius: isLargeGrid ? 0 : 1,
                                          offset: const Offset(0, 3),
                                        ),
                                    ],
                                  ),
                                  child: AnimatedBuilder(
                                    animation: _selectionAnimController,
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: isSelected
                                            ? (isLargeGrid ? 1.0 + (_pulseAnimation.value - 1.0) * 0.7 : _pulseAnimation.value)
                                            : 1.0,
                                        child: child,
                                      );
                                    },
                                    child: GestureDetector(
                                      onTap: () => _handleTileTap(rowIndex, colIndex),
                                      onPanStart: (details) => _handleDragStart(rowIndex, colIndex, details),
                                      onPanUpdate: (details) {
                                        // If this is the current selected tile, use it for updates
                                        if (_selectedRow == rowIndex && _selectedCol == colIndex) {
                                          _handleDragUpdate(rowIndex, colIndex, details, adjacentEmptyPos);
                                        } else if (_selectedRow != null && _selectedCol != null) {
                                          // Otherwise, use the currently selected tile for updates
                                          _handleDragUpdate(_selectedRow!, _selectedCol!, details, adjacentEmptyPos);
                                        }
                                      },
                                      onPanEnd: (details) => _handleDragEnd(rowIndex, colIndex, details),
                                      child: TileWidget(
                                        value: value,
                                        isMovable: isMovable,
                                        isSelected: isSelected,
                                        isTablet: isTablet,
                                        size: finalTileSize,
                                        borderRadius: isLargeGrid ? (isTablet ? 10 : 8) : (isTablet ? 14 : 10),
                                        movableDirections: _getMovableDirections(rowIndex, colIndex),
                                        onTap: () => _handleTileTap(rowIndex, colIndex),
                                        onDirectionalTap: (direction) {
                                          if (adjacentEmptyPos.containsKey(direction)) {
                                            widget.onTileTap(rowIndex, colIndex, direction: direction);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getDirectionIcon(String? direction) {
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

// Custom painter for the grid background pattern
class GridPatternPainter extends CustomPainter {
  final int gridSize;
  final Color color;

  GridPatternPainter({
    required this.gridSize,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5 // Thinner lines
      ..style = PaintingStyle.stroke;

    // Ensure we don't divide by zero
    if (gridSize <= 0) return;

    final double cellWidth = size.width / gridSize;
    final double cellHeight = size.height / gridSize;

    // Draw vertical lines
    for (int i = 1; i < gridSize; i++) {
      final x = cellWidth * i;
      if (x <= size.width) {
        // Check to prevent drawing outside bounds
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
    }

    // Draw horizontal lines - use actual row count if available
    final rowCount =
        gridSize; // Use gridSize if we don't know the actual row count
    for (int i = 1; i < rowCount; i++) {
      final y = cellHeight * i;
      if (y <= size.height) {
        // Check to prevent drawing outside bounds
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom painter for the rock texture pattern
class RockPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[800]!
      ..style = PaintingStyle.fill;

    final double cellWidth = size.width / 10;
    final double cellHeight = size.height / 10;

    for (int i = 0; i < 10; i++) {
      for (int j = 0; j < 10; j++) {
        if (i.isEven && j.isEven || i.isOdd && j.isOdd) {
          canvas.drawRect(
            Rect.fromLTRB(i * cellWidth, j * cellHeight, (i + 1) * cellWidth,
                (j + 1) * cellHeight),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}