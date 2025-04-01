// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';

class TileWidget extends StatefulWidget {
  final int value;
  final List<String> movableDirections;
  final VoidCallback onTap;
  final Function(String) onDirectionalTap;
  final double size;
  final bool isSelected;

  const TileWidget({
    super.key,
    required this.value,
    required this.movableDirections,
    required this.onTap,
    required this.onDirectionalTap,
    this.size = 60,
    this.isSelected = false,
  });

  @override
  State<TileWidget> createState() => _TileWidgetState();
}

class _TileWidgetState extends State<TileWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.01).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getTileColor() {
    if (widget.movableDirections.isEmpty) {
      return Colors.grey[300]!;
    }

    final theme = Theme.of(context);

    if (widget.isSelected) {
      return theme.colorScheme.primary;
    }

    // Different shades based on movability
    if (widget.movableDirections.isNotEmpty) {
      return theme.colorScheme.primary.withOpacity(0.9);
    }

    return theme.colorScheme.primary.withOpacity(0.7);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMovable = widget.movableDirections.isNotEmpty;

    // Check if value is double-digit for font size adjustment
    final bool isDoubleDigit = widget.value >= 10;

    // Check if value is triple-digit for additional adjustments
    final bool isTripleDigit = widget.value >= 100;

    // Adjust font size based on number of digits
    final double fontSize = isTripleDigit
        ? widget.size * 0.34
        : isDoubleDigit
            ? widget.size * 0.38
            : widget.size * 0.44;

    // Adjust corner indicator visibility based on size
    final bool showCornerIndicator = widget.size > 40 && isMovable;

    // Scale direction indicators based on tile size
    final double directionIndicatorSize = widget.size > 50 ? 18 : 14;

    // Adjust border radius based on size
    final double borderRadius =
        widget.size > 60 ? 20 : (widget.size > 40 ? 16 : 12);

    // Create gradient colors for the tile
    final primaryColor = _getTileColor();
    final secondaryColor = HSLColor.fromColor(primaryColor)
        .withLightness(
            (HSLColor.fromColor(primaryColor).lightness - 0.1).clamp(0.0, 1.0))
        .toColor();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) {
          if (isMovable) {
            _controller.forward();
          }
        },
        onTapUp: (_) {
          if (isMovable) {
            _controller.reverse();
            widget.onTap();
          }
        },
        onTapCancel: () {
          if (isMovable) {
            _controller.reverse();
          }
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: _rotateAnimation.value,
                child: child,
              ),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              gradient: isMovable
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primaryColor,
                        secondaryColor,
                      ],
                      stops: const [0.3, 1.0],
                    )
                  : null,
              color: isMovable ? null : _getTileColor(),
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: isMovable
                  ? [
                      // Outer shadow
                      BoxShadow(
                        color: primaryColor.withOpacity(
                            widget.isSelected || _isHovered ? 0.5 : 0.3),
                        blurRadius:
                            widget.isSelected ? 16 : (_isHovered ? 10 : 6),
                        spreadRadius:
                            widget.isSelected ? 2 : (_isHovered ? 1 : 0),
                        offset: Offset(
                            0, widget.isSelected ? 6 : (_isHovered ? 4 : 3)),
                      ),
                      // Inner highlight for 3D effect
                      BoxShadow(
                        color: Colors.white.withOpacity(0.5),
                        blurRadius: 3,
                        spreadRadius: -2,
                        offset: const Offset(-1, -1),
                      ),
                    ]
                  : null,
              border: !isMovable
                  ? Border.all(color: Colors.grey[400]!, width: 1)
                  : widget.isSelected
                      ? Border.all(
                          color: Colors.white.withOpacity(0.8), width: 3.0)
                      : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Stack(
                children: [
                  // Subtle pattern overlay for texture (only on movable tiles)
                  if (isMovable)
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.04,
                        child: Image.network(
                          'https://www.transparenttextures.com/patterns/cubes.png',
                          repeat: ImageRepeat.repeat,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                  // Subtle inner lighting effect for depth
                  if (isMovable)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.2),
                              Colors.transparent,
                              Colors.black.withOpacity(0.1),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),

                  // Main number with improved styling
                  Center(
                    child: Text(
                      widget.value.toString(),
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        letterSpacing: isDoubleDigit ? -1.0 : -0.5,
                        color: isMovable ? Colors.white : Colors.grey[700],
                        shadows: isMovable
                            ? [
                                Shadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 3,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),

                  // Directional indicators with improved styling
                  if ((_isHovered || widget.isSelected) &&
                      isMovable &&
                      widget.size > 40)
                    ...widget.movableDirections.map((direction) {
                      Alignment alignment;
                      IconData icon;

                      switch (direction) {
                        case 'up':
                          alignment = Alignment.topCenter;
                          icon = Icons.arrow_drop_up_rounded;
                          break;
                        case 'down':
                          alignment = Alignment.bottomCenter;
                          icon = Icons.arrow_drop_down_rounded;
                          break;
                        case 'left':
                          alignment = Alignment.centerLeft;
                          icon = Icons.arrow_left_rounded;
                          break;
                        case 'right':
                          alignment = Alignment.centerRight;
                          icon = Icons.arrow_right_rounded;
                          break;
                        default:
                          alignment = Alignment.center;
                          icon = Icons.touch_app_rounded;
                      }

                      return Align(
                        alignment: alignment,
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 2,
                                spreadRadius: 0,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.all(widget.size > 60 ? 3 : 2),
                          child: Icon(
                            icon,
                            color: Colors.white,
                            size: directionIndicatorSize,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                  // Visual indicator for movable tiles
                  if (isMovable && !widget.isSelected && showCornerIndicator)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: widget.size > 70 ? 10 : 8,
                        height: widget.size > 70 ? 10 : 8,
                        decoration: BoxDecoration(
                          color: widget.movableDirections.length > 1
                              ? Colors.greenAccent
                              : Colors.amber,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 2,
                              spreadRadius: 0,
                              offset: const Offset(0, 1),
                            ),
                          ],
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
