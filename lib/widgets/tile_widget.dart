// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';

class TileWidget extends StatefulWidget {
  final int value;
  final List<String>? movableDirections;
  final VoidCallback? onTap;
  final Function(String)? onDirectionalTap;
  final double size;
  final bool isSelected;
  final bool isMovable;
  final bool isTablet;
  final double? borderRadius;

  const TileWidget({
    super.key,
    required this.value,
    this.movableDirections,
    this.onTap,
    this.onDirectionalTap,
    this.size = 60,
    this.isSelected = false,
    this.isMovable = false,
    this.isTablet = false,
    this.borderRadius,
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
    if (!widget.isMovable &&
        (widget.movableDirections == null ||
            widget.movableDirections!.isEmpty)) {
      return Colors.grey[300]!;
    }

    final theme = Theme.of(context);

    if (widget.isSelected) {
      return theme.colorScheme.primary;
    }

    // Different shades based on movability
    if (widget.isMovable ||
        (widget.movableDirections != null &&
            widget.movableDirections!.isNotEmpty)) {
      return theme.colorScheme.primary.withOpacity(0.9);
    }

    return theme.colorScheme.primary.withOpacity(0.7);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMovableTile = widget.isMovable ||
        (widget.movableDirections != null &&
            widget.movableDirections!.isNotEmpty);

    // Check if value is double-digit for font size adjustment
    final bool isDoubleDigit = widget.value >= 10;

    // Check if value is triple-digit for additional adjustments
    final bool isTripleDigit = widget.value >= 100;

    // More responsive font size adjustments based on tile size and digits
    final double fontSize = isTripleDigit
        ? (widget.isTablet ? widget.size * 0.35 : widget.size * 0.32)
        : isDoubleDigit
            ? (widget.isTablet ? widget.size * 0.4 : widget.size * 0.36)
            : (widget.isTablet ? widget.size * 0.46 : widget.size * 0.42);

    // Adjust corner indicator visibility based on size - hide on very small tiles
    final bool showCornerIndicator = widget.size > 35 && isMovableTile;

    // Scale direction indicators based on tile size - smaller for smaller tiles
    final double directionIndicatorSize = widget.isTablet
        ? (widget.size > 65 ? 20 : 16)
        : (widget.size > 45 ? 16 : 12);

    // More responsive border radius calculation
    final double calculatedBorderRadius = widget.size > 65
        ? 20
        : (widget.size > 50 ? 16 : (widget.size > 35 ? 12 : 8));

    // Determine border radius: use provided value, or calculated based on size
    final double borderRadius = widget.borderRadius ?? calculatedBorderRadius;

    // Create gradient colors for the tile
    final primaryColor = _getTileColor();
    final secondaryColor = HSLColor.fromColor(primaryColor)
        .withLightness(
            (HSLColor.fromColor(primaryColor).lightness - 0.1).clamp(0.0, 1.0))
        .toColor();

    // Adjust shadow and highlight based on size
    final bool useSimplifiedShadow = widget.size < 45;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) {
          if (isMovableTile) {
            _controller.forward();
          }
        },
        onTapUp: (_) {
          if (isMovableTile && widget.onTap != null) {
            _controller.reverse();
            widget.onTap!();
          }
        },
        onTapCancel: () {
          if (isMovableTile) {
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
              gradient: isMovableTile
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
              color: isMovableTile ? null : _getTileColor(),
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: isMovableTile
                  ? (useSimplifiedShadow
                      ? [
                          BoxShadow(
                            color: primaryColor
                                .withOpacity(widget.isSelected ? 0.4 : 0.2),
                            blurRadius: widget.isSelected ? 8 : 4,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [
                          // Outer shadow
                          BoxShadow(
                            color: primaryColor.withOpacity(
                                widget.isSelected || _isHovered ? 0.5 : 0.3),
                            blurRadius:
                                widget.isSelected ? 16 : (_isHovered ? 10 : 6),
                            spreadRadius:
                                widget.isSelected ? 2 : (_isHovered ? 1 : 0),
                            offset: Offset(0,
                                widget.isSelected ? 6 : (_isHovered ? 4 : 3)),
                          ),
                          // Inner highlight for 3D effect
                          BoxShadow(
                            color: Colors.white.withOpacity(0.5),
                            blurRadius: 3,
                            spreadRadius: -2,
                            offset: const Offset(-1, -1),
                          ),
                        ])
                  : null,
              border: !isMovableTile
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
                  if (isMovableTile)
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
                  if (isMovableTile)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(borderRadius),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white10,
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.7],
                          ),
                        ),
                      ),
                    ),

                  // Tile number
                  Center(
                    child: Text(
                      widget.value.toString(),
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        letterSpacing: isDoubleDigit ? -1.0 : -0.5,
                        color: isMovableTile ? Colors.white : Colors.grey[700],
                        shadows: isMovableTile
                            ? [
                                Shadow(
                                  offset: const Offset(1, 1),
                                  blurRadius: 2,
                                  color: Colors.black.withOpacity(0.3),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                  // Note: Directional indicators have been removed
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
