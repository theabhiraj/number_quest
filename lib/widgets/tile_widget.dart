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

class _TileWidgetState extends State<TileWidget> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
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
      return theme.colorScheme.primary.withOpacity(0.8);
    }
    
    if (_isPressed) {
      return theme.colorScheme.primary.withOpacity(0.7);
    }

    // Different shades based on movability
    if (widget.isMovable ||
        (widget.movableDirections != null &&
            widget.movableDirections!.isNotEmpty)) {
      return theme.colorScheme.primary.withOpacity(_isHovered ? 0.95 : 0.9);
    }

    return theme.colorScheme.primary.withOpacity(0.7);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMovableTile = widget.isMovable ||
        (widget.movableDirections != null &&
            widget.movableDirections!.isNotEmpty);

    // Check if value is double-digit or triple-digit for font size adjustment
    final bool isDoubleDigit = widget.value >= 10;
    final bool isTripleDigit = widget.value >= 100;
    final bool isQuadDigit = widget.value >= 1000; // For very large grids

    // Determine if this is a very small tile (for large grids like 8x8, 10x10)
    final bool isVerySmallTile = widget.size < 35;
    final bool isSmallTile = widget.size < 45 && !isVerySmallTile;
    final bool isMediumTile = widget.size >= 45 && widget.size < 60;
    final bool isLargeTile = widget.size >= 60;

    // More responsive font size adjustments based on tile size and digits
    final double fontSize = isQuadDigit
        ? (isVerySmallTile 
            ? widget.size * 0.32
            : (isSmallTile 
                ? widget.size * 0.34 
                : (widget.isTablet ? widget.size * 0.36 : widget.size * 0.35)))
        : isTripleDigit
            ? (isVerySmallTile 
                ? widget.size * 0.36
                : (isSmallTile 
                    ? widget.size * 0.38 
                    : (widget.isTablet ? widget.size * 0.42 : widget.size * 0.40)))
            : isDoubleDigit
                ? (isVerySmallTile 
                    ? widget.size * 0.42
                    : (isSmallTile 
                        ? widget.size * 0.44 
                        : (widget.isTablet ? widget.size * 0.48 : widget.size * 0.46)))
                : (isVerySmallTile 
                    ? widget.size * 0.48
                    : (isSmallTile 
                        ? widget.size * 0.50 
                        : (widget.isTablet ? widget.size * 0.54 : widget.size * 0.52)));

    // Dynamic border radius based on tile size
    final double calculatedBorderRadius = isVerySmallTile
        ? 6
        : (isSmallTile
            ? 8
            : (isMediumTile ? 10 : (isLargeTile ? 14 : 12)));

    // Determine border radius: use provided value, or calculated based on size
    final double borderRadius = widget.borderRadius ?? calculatedBorderRadius;

    // Create gradient colors for the tile with more vibrant colors for smaller tiles
    final primaryColor = _getTileColor();
    final HSLColor hslColor = HSLColor.fromColor(primaryColor);
    
    // For very small tiles, make colors more vibrant to stand out
    final HSLColor adjustedHSLColor = isVerySmallTile || isSmallTile
        ? hslColor.withSaturation((hslColor.saturation + 0.1).clamp(0.0, 1.0))
        : hslColor;
    
    final secondaryColor = adjustedHSLColor
        .withLightness((adjustedHSLColor.lightness - (isVerySmallTile ? 0.08 : 0.1)).clamp(0.0, 1.0))
        .toColor();

    // Simplified effects for very small tiles
    final bool useSimplifiedShadow = isVerySmallTile || isSmallTile;

    return AspectRatio(
      aspectRatio: 1.0, // Force perfect square aspect ratio
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: (_) {
            if (isMovableTile) {
              setState(() => _isPressed = true);
            }
          },
          onTapUp: (_) {
            if (isMovableTile && widget.onTap != null) {
              setState(() => _isPressed = false);
              widget.onTap!();
            }
          },
          onTapCancel: () {
            if (isMovableTile) {
              setState(() => _isPressed = false);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              gradient: isMovableTile
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primaryColor,
                        secondaryColor,
                      ],
                      stops: isVerySmallTile ? const [0.4, 0.9] : const [0.3, 1.0],
                    )
                  : null,
              color: isMovableTile ? null : _getTileColor(),
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: isMovableTile
                  ? (useSimplifiedShadow
                      ? [
                          BoxShadow(
                            color: primaryColor
                                .withOpacity(isVerySmallTile 
                                    ? (widget.isSelected ? 0.3 : 0.15)
                                    : (widget.isSelected ? 0.4 : 0.2)),
                            blurRadius: isVerySmallTile 
                                ? (widget.isSelected ? 3 : 2) 
                                : (widget.isSelected ? 4 : 3),
                            spreadRadius: widget.isSelected ? 0.5 : 0,
                            offset: Offset(0, isVerySmallTile ? 1 : 1.5),
                          )
                        ]
                      : [
                          // Outer shadow - reduced for small tiles
                          BoxShadow(
                            color: primaryColor.withOpacity(
                                isVerySmallTile 
                                    ? 0.25
                                    : (widget.isSelected || _isHovered ? 0.4 : 0.25)),
                            blurRadius: isVerySmallTile
                                ? (widget.isSelected ? 4 : 2)
                                : (widget.isSelected ? 12 : (_isHovered ? 8 : 5)),
                            spreadRadius: isVerySmallTile
                                ? 0
                                : (widget.isSelected ? 1 : (_isHovered ? 0.5 : 0)),
                            offset: Offset(0,
                                isVerySmallTile
                                    ? 1
                                    : (widget.isSelected ? 4 : (_isHovered ? 3 : 2))),
                          )
                        ])
                  : null,
            ),
            child: Stack(
              children: [
                // Center number with improved readability for smaller tiles
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: EdgeInsets.all(isVerySmallTile ? 2.0 : 4.0),
                      child: Text(
                        widget.value.toString(),
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                          color: isMovableTile
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                          letterSpacing: isQuadDigit
                              ? (isVerySmallTile ? -1.4 : -1.2)
                              : isTripleDigit 
                                  ? (isVerySmallTile ? -1.0 : -0.8)
                                  : isDoubleDigit 
                                      ? (isVerySmallTile ? -0.6 : -0.4) 
                                      : 0,
                          height: 0.9,
                          shadows: isMovableTile && !isVerySmallTile
                              ? [
                                  Shadow(
                                    color: Colors.black26,
                                    blurRadius: 1,
                                    offset: const Offset(0, 1),
                                  )
                                ]
                              : isMovableTile && isVerySmallTile 
                                  ? [
                                      Shadow(
                                        color: Colors.black38,
                                        blurRadius: 0.5,
                                        offset: const Offset(0, 0.5),
                                      )
                                    ]
                                  : null,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),

                // Add a subtle highlight effect at the top (simplified for small tiles)
                if (isMovableTile)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: widget.size * (isVerySmallTile ? 0.2 : (isSmallTile ? 0.22 : 0.25)),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(borderRadius),
                          topRight: Radius.circular(borderRadius),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(isVerySmallTile ? 0.15 : (isSmallTile ? 0.15 : 0.18)),
                            Colors.white.withOpacity(0.0),
                          ],
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
