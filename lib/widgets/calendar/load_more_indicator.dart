import 'package:flutter/material.dart';
import 'dart:math' as math;

class LoadMoreIndicator extends StatelessWidget {
  final bool isTop;
  final bool isLoading;
  final double pullProgress;
  final VoidCallback? onRefresh;

  const LoadMoreIndicator({
    super.key,
    required this.isTop,
    required this.isLoading,
    required this.pullProgress,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    if (pullProgress == 0 && !isLoading) {
      return const SizedBox.shrink();
    }

    final opacity = math.min(pullProgress, 1.0);
    final iconRotation = pullProgress >= 1.0 ? math.pi : 0.0;
    
    String text;
    if (isLoading) {
      text = 'Loading...';
    } else if (pullProgress >= 1.0) {
      text = isTop ? 'Release to load earlier months' : 'Release to load later months';
    } else {
      text = isTop ? 'Pull to load earlier months' : 'Pull to load later months';
    }

    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 150),
      child: Container(
        height: 80,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              )
            else
              AnimatedRotation(
                turns: iconRotation / (2 * math.pi),
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isTop ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 20,
                  color: pullProgress >= 1.0 
                    ? theme.colorScheme.primary 
                    : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
            const SizedBox(width: 12),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 14,
                fontWeight: pullProgress >= 1.0 ? FontWeight.w600 : FontWeight.normal,
                color: pullProgress >= 1.0 
                  ? theme.colorScheme.primary 
                  : (isDark ? Colors.white70 : Colors.black87),
              ),
              child: Text(text),
            ),
          ],
        ),
      ),
    );
  }
}