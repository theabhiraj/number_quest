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

  @override
  void initState() {
    super.initState();
    _gridAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
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
  }

  @override
  void dispose() {
    _gridAnimationController.dispose();
    _selectionAnimController.dispose();
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

    // Calculate optimal tile size based on grid size and screen size
    final Size screenSize = MediaQuery.of(context).size;
    final double availableWidth = screenSize.width - 80; // Account for padding
    final double availableHeight =
        screenSize.height - 300; // Adjust for app bar and other UI elements

    // More adaptive tile sizing based on both width and height constraints
    final double maxTileWidth = availableWidth / maxColumns;
    final double maxTileHeight = availableHeight / widget.grid.length;
    final double maxTileSize = math.min(maxTileWidth, maxTileHeight);

    // Adjust tile size based on grid size
    final double tileSize =
        math.max(math.min(maxTileSize * 0.92, 80), 50); // Minimum size of 50

    // Adjust spacing based on grid size
    final double spacing = tileSize > 60 ? 8 : 4;

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
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.15),
                blurRadius: 25,
                spreadRadius: 8,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.1),
              width: 2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
                        child: Container(
              padding: EdgeInsets.all(spacing + 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                    theme.colorScheme.surface,
                    theme.colorScheme.surface.withOpacity(0.92),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Background grid pattern
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.05,
                      child: CustomPaint(
                        painter: GridPatternPainter(
                          gridSize: maxColumns,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),

                  // The actual puzzle grid - wrapped in Center to prevent overflow
                  Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(widget.grid.length, (rowIndex) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                                widget.grid[rowIndex].length, (colIndex) {
                              final tileValue = widget.grid[rowIndex][colIndex];
                              final isSelectedTile = _selectedRow == rowIndex &&
                                  _selectedCol == colIndex;

                              if (tileValue == 0) {
                                // Empty space
                                return _buildEmptyCell(
                                  rowIndex,
                                  colIndex,
                                  tileSize,
                                  spacing,
                                  adjacentEmptyPositions,
                                  theme,
                                );
                              } else {
                                // Number tile
                                return _buildTileCell(
                                  rowIndex,
                                  colIndex,
                                  tileValue,
                                  tileSize,
                                  spacing,
                                  isSelectedTile,
                                  theme,
                                );
                              }
                            }),
                          );
                        }),
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

  Widget _buildTileCell(
    int rowIndex,
    int colIndex,
    int tileValue,
    double tileSize,
    double spacing,
    bool isSelectedTile,
    ThemeData theme,
  ) {
    final movableDirections = _getMovableDirections(rowIndex, colIndex);
    final adjacentEmptyPositions =
        _getAdjacentEmptyPositions(rowIndex, colIndex);

    // Optional: Animate selected tiles
    Widget tileWidget = Padding(
      padding: EdgeInsets.all(spacing / 2),
      child: GestureDetector(
        onTap: () => _handleTileTap(rowIndex, colIndex),
        onPanStart: (details) => _handleDragStart(rowIndex, colIndex, details),
        onPanUpdate: (details) => _handleDragUpdate(
            rowIndex, colIndex, details, adjacentEmptyPositions),
        onPanEnd: (_) => _handleDragEnd(rowIndex, colIndex),
        child: TileWidget(
          value: tileValue,
          movableDirections: movableDirections,
          onTap: () => _handleTileTap(rowIndex, colIndex),
          onDirectionalTap: (direction) {
            // Not used for numbered tiles
          },
          size: tileSize,
          isSelected: isSelectedTile,
                        ),
                      ),
                    );

    // Apply pulsating animation to selected tile
    if (isSelectedTile) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: child,
          );
        },
        child: tileWidget,
      );
    }

    return tileWidget;
  }

  Widget _buildEmptyCell(
    int rowIndex,
    int colIndex,
    double tileSize,
    double spacing,
    Map<String, List<int>> adjacentEmptyPositions,
    ThemeData theme,
  ) {
    // Find if this empty cell is adjacent to the selected tile
    String? direction;
    if (_selectedRow != null && _selectedCol != null) {
      for (final entry in adjacentEmptyPositions.entries) {
        final List<int> pos = entry.value;
        if (pos[0] == rowIndex && pos[1] == colIndex) {
          direction = entry.key;
          break;
        }
      }
    }

    final bool isAdjacent = direction != null;

    return Padding(
      padding: EdgeInsets.all(spacing / 2),
      child: SizedBox(
        width: tileSize,
        height: tileSize,
        child: isAdjacent
            ? Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    splashColor: theme.colorScheme.primary.withOpacity(0.3),
                    onTap: () {
                      if (direction != null) {
                        _handleEmptyTileTap(rowIndex, colIndex, direction);
                      }
                    },
                    child: Center(
                      child: Icon(
                        _getDirectionIcon(direction),
                        color: theme.colorScheme.primary.withOpacity(0.5),
                        size: tileSize / 3,
                      ),
                    ),
                  ),
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withOpacity(0.05),
                    width: 1.5,
                    style: BorderStyle.solid,
            ),
          ),
        ),
      ),
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
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final double cellSize = size.width / gridSize;

    // Draw vertical lines
    for (int i = 1; i < gridSize; i++) {
      final x = cellSize * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (int i = 1; i < gridSize; i++) {
      final y = cellSize * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
