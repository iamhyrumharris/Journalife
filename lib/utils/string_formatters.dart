class StringFormatters {
  static String formatLocationForMetadata(String fullLocation, {int maxLength = 12}) {
    if (fullLocation.isEmpty) return '';
    
    // Extract street name (text before first comma)
    final parts = fullLocation.split(',');
    String streetName = parts.first.trim();
    
    // Apply ellipsis if exceeds maxLength
    if (streetName.length > maxLength) {
      return '${streetName.substring(0, maxLength - 1)}…';
    }
    
    return streetName;
  }
}