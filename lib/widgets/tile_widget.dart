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
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.02).animate(
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
      return theme.colorScheme.primary.withOpacity(0.85);
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
        ? widget.size * 0.35
        : isDoubleDigit
            ? widget.size * 0.4
            : widget.size * 0.45;

    // Adjust corner indicator visibility based on size
    final bool showCornerIndicator = widget.size > 40 && isMovable;

    // Scale direction indicators based on tile size
    final double directionIndicatorSize = widget.size > 50 ? 16 : 12;

    // Adjust border radius based on size
    final double borderRadius =
        widget.size > 60 ? 20 : (widget.size > 40 ? 16 : 12);

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
                        _getTileColor().withOpacity(1.0),
                        _getTileColor().withOpacity(0.8),
                      ],
                    )
                  : null,
              color: isMovable ? null : _getTileColor(),
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: isMovable
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(
                            widget.isSelected || _isHovered ? 0.5 : 0.25),
                        blurRadius: widget.isSelected || _isHovered ? 12 : 6,
                        spreadRadius: widget.isSelected || _isHovered ? 2 : 0,
                        offset:
                            Offset(0, widget.isSelected || _isHovered ? 5 : 3),
                      ),
                    ]
                  : null,
              border: !isMovable
                  ? Border.all(color: Colors.grey[400]!, width: 1)
                  : widget.isSelected
                      ? Border.all(color: Colors.white, width: 2.0)
                      : null,
            ),
            child: Stack(
              children: [
                // Subtle pattern overlay for texture (only on movable tiles)
                if (isMovable)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(borderRadius),
                      child: Opacity(
                        opacity: 0.07,
                        child: Image.network(
                          'https://www.transparenttextures.com/patterns/cubes.png',
                          repeat: ImageRepeat.repeat,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                // Main number
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

                // Directional indicators (when selected or hovered)
                if (_isHovered && isMovable && widget.size > 40)
                  ...widget.movableDirections.map((direction) {
                    Alignment alignment;
                    IconData icon;

                    switch (direction) {
                      case 'up':
                        alignment = Alignment.topCenter;
                        icon = Icons.arrow_drop_up;
                        break;
                      case 'down':
                        alignment = Alignment.bottomCenter;
                        icon = Icons.arrow_drop_down;
                        break;
                      case 'left':
                        alignment = Alignment.centerLeft;
                        icon = Icons.arrow_left;
                        break;
                      case 'right':
                        alignment = Alignment.centerRight;
                        icon = Icons.arrow_right;
                        break;
                      default:
                        alignment = Alignment.center;
                        icon = Icons.touch_app;
                    }

                    return Align(
                      alignment: alignment,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.4),
                          shape: BoxShape.circle,
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

                // Bottom right corner decoration (tile number as small indicator)
                if (showCornerIndicator)
                  Positioned(
                    right: widget.size > 60 ? 6 : 4,
                    bottom: widget.size > 60 ? 4 : 2,
                    child: Container(
                      width: widget.size > 60 ? 16 : 12,
                      height: widget.size > 60 ? 16 : 12,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.4),
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
                      child: Center(
                        child: Text(
                          widget.value.toString(),
                          style: TextStyle(
                            fontSize: widget.size > 60 ? 9 : 7,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
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
    );
  }
}
