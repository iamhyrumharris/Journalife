import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ImageDimensions {
  final double width;
  final double height;
  
  ImageDimensions({required this.width, required this.height});
  
  double get aspectRatio {
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      return 1.0; // Default to square aspect ratio for invalid dimensions
    }
    return width / height;
  }
  
  bool get isPortrait => height > width;
  bool get isLandscape => width > height;
  bool get isSquare => (width - height).abs() < 10; // Allow small tolerance
}

class ImageDimensionLoader {
  static final Map<String, ImageDimensions> _cache = {};
  
  /// Load image dimensions from file path
  static Future<ImageDimensions?> loadFromFile(File file) async {
    try {
      final path = file.path;
      
      // Check cache first
      if (_cache.containsKey(path)) {
        return _cache[path];
      }
      
      // Check if file is HEIC format
      final isHeic = path.toLowerCase().endsWith('.heic') || 
                     path.toLowerCase().endsWith('.heif');
      
      if (isHeic) {
        // For HEIC files, return a default dimension since Flutter can't decode them directly
        debugPrint('HEIC format detected, using default dimensions for: $path');
        final dimensions = ImageDimensions(
          width: 1000.0, // Default width
          height: 1000.0, // Default height (square aspect ratio)
        );
        _cache[path] = dimensions;
        return dimensions;
      }
      
      // Load image and get dimensions for supported formats
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      
      final dimensions = ImageDimensions(
        width: image.width.toDouble(),
        height: image.height.toDouble(),
      );
      
      // Cache the result
      _cache[path] = dimensions;
      
      image.dispose();
      
      return dimensions;
    } catch (e) {
      debugPrint('Error loading image dimensions from $file: $e');
      // Return default dimensions as fallback
      final dimensions = ImageDimensions(
        width: 1000.0,
        height: 1000.0,
      );
      _cache[file.path] = dimensions;
      return dimensions;
    }
  }
  
  /// Get cached dimensions or return default
  static ImageDimensions? getCached(String filePath) {
    return _cache[filePath];
  }
  
  /// Calculate display height for given width while preserving aspect ratio
  static double calculateDisplayHeight(ImageDimensions dimensions, double displayWidth) {
    if (!displayWidth.isFinite || displayWidth <= 0 || 
        !dimensions.aspectRatio.isFinite || dimensions.aspectRatio <= 0) {
      return displayWidth; // Fallback to square
    }
    return displayWidth / dimensions.aspectRatio;
  }
  
  /// Estimate average photo height for layout calculations
  static double estimateAverageHeight(List<ImageDimensions> dimensions, double displayWidth) {
    if (dimensions.isEmpty || !displayWidth.isFinite || displayWidth <= 0) {
      return displayWidth; // Default to square if no dimensions available
    }
    
    double totalHeight = 0;
    int validCount = 0;
    
    for (final dim in dimensions) {
      final height = calculateDisplayHeight(dim, displayWidth);
      if (height.isFinite && height > 0) {
        totalHeight += height;
        validCount++;
      }
    }
    
    if (validCount == 0) {
      return displayWidth; // Fallback to square
    }
    
    final averageHeight = totalHeight / validCount;
    return averageHeight.isFinite && averageHeight > 0 ? averageHeight : displayWidth;
  }
  
  /// Clear cache (useful for memory management)
  static void clearCache() {
    _cache.clear();
  }
}