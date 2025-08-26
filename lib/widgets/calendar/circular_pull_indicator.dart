import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

class CircularPullIndicator extends StatefulWidget {
  final double progress;
  final bool isLoading;
  final bool isTop;
  
  const CircularPullIndicator({
    super.key,
    required this.progress,
    required this.isLoading,
    required this.isTop,
  });

  @override
  State<CircularPullIndicator> createState() => _CircularPullIndicatorState();
}

class _CircularPullIndicatorState extends State<CircularPullIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  
  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    
    if (widget.isLoading) {
      _rotationController.repeat();
    }
  }
  
  @override
  void didUpdateWidget(CircularPullIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isLoading && !oldWidget.isLoading) {
      _rotationController.repeat();
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _rotationController.stop();
      _rotationController.value = 0;
    }
    
    if (widget.progress >= 1.0 && oldWidget.progress < 1.0) {
      HapticFeedback.lightImpact();
    }
  }
  
  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.progress == 0 && !widget.isLoading) {
      return const SizedBox.shrink();
    }
    
    final theme = Theme.of(context);
    final size = 40.0 + (widget.progress * 10.0);
    final opacity = math.min(widget.progress * 2, 1.0);
    
    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 150),
      child: Container(
        height: 80,
        alignment: Alignment.center,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          child: widget.isLoading
              ? RotationTransition(
                  turns: _rotationController,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                )
              : CustomPaint(
                  painter: CircularProgressPainter(
                    progress: widget.progress,
                    color: widget.progress >= 1.0
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withValues(alpha: 0.6),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: widget.progress >= 1.0
                          ? Icon(
                              Icons.check_circle,
                              size: size * 0.4,
                              color: theme.colorScheme.primary,
                            )
                          : Icon(
                              widget.isTop
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              size: size * 0.4,
                              color: theme.colorScheme.primary.withValues(alpha: 0.6),
                            ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  
  CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    canvas.drawCircle(center, radius - 2, backgroundPaint);
    
    final sweepAngle = 2 * math.pi * math.min(progress, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 2),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }
  
  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.color != color ||
           oldDelegate.backgroundColor != backgroundColor;
  }
}