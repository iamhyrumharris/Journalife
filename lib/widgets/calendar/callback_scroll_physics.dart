import 'package:flutter/material.dart';
import 'dart:math' as math;

enum OverscrollDirection { top, bottom }

class CallbackScrollPhysics extends BouncingScrollPhysics {
  final Function(double overscrollAmount, OverscrollDirection direction)? onOverscroll;
  final VoidCallback? onOverscrollEnd;
  
  const CallbackScrollPhysics({
    super.parent,
    this.onOverscroll,
    this.onOverscrollEnd,
  });

  @override
  CallbackScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return CallbackScrollPhysics(
      parent: buildParent(ancestor),
      onOverscroll: onOverscroll,
      onOverscrollEnd: onOverscrollEnd,
    );
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // Call the parent implementation first
    final result = super.applyPhysicsToUserOffset(position, offset);
    
    // Detect overscroll conditions
    final isAtTop = position.pixels <= position.minScrollExtent;
    final isAtBottom = position.pixels >= position.maxScrollExtent;
    
    if (isAtTop && offset > 0) {
      // Overscrolling at top (pulling down)
      final overscrollAmount = math.max(0.0, position.minScrollExtent - (position.pixels - offset));
      if (overscrollAmount > 0) {
        onOverscroll?.call(overscrollAmount, OverscrollDirection.top);
      }
    } else if (isAtBottom && offset < 0) {
      // Overscrolling at bottom (pulling up)
      final overscrollAmount = math.max(0.0, (position.pixels - offset) - position.maxScrollExtent);
      if (overscrollAmount > 0) {
        onOverscroll?.call(overscrollAmount, OverscrollDirection.bottom);
      }
    }
    
    return result;
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    // Detect if we're ending an overscroll
    final isOverscrolled = position.pixels < position.minScrollExtent || 
                          position.pixels > position.maxScrollExtent;
    
    if (isOverscrolled) {
      onOverscrollEnd?.call();
    }
    
    return super.createBallisticSimulation(position, velocity);
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    // Always accept user offset to ensure overscroll detection works
    return true;
  }
}