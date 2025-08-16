import 'package:flutter/material.dart';

enum LayoutType {
  mobile,
  tablet,
  desktop,
}

class ResponsiveBreakpoints {
  ResponsiveBreakpoints._();

  // Breakpoint values
  static const double mobileBreakpoint = 480;
  static const double tabletBreakpoint = 1024;
  static const double maxContainerWidth = 1200;

  /// Determines the current layout type based on screen width
  static LayoutType getLayoutType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return getLayoutTypeFromWidth(width);
  }

  /// Determines layout type from a specific width value
  static LayoutType getLayoutTypeFromWidth(double width) {
    if (width <= mobileBreakpoint) {
      return LayoutType.mobile;
    } else if (width <= tabletBreakpoint) {
      return LayoutType.tablet;
    } else {
      return LayoutType.desktop;
    }
  }

  /// Returns true if the current layout is mobile
  static bool isMobile(BuildContext context) {
    return getLayoutType(context) == LayoutType.mobile;
  }

  /// Returns true if the current layout is tablet
  static bool isTablet(BuildContext context) {
    return getLayoutType(context) == LayoutType.tablet;
  }

  /// Returns true if the current layout is desktop
  static bool isDesktop(BuildContext context) {
    return getLayoutType(context) == LayoutType.desktop;
  }

  /// Returns true if the layout is tablet or larger
  static bool isTabletUp(BuildContext context) {
    final layoutType = getLayoutType(context);
    return layoutType == LayoutType.tablet || layoutType == LayoutType.desktop;
  }

  /// Returns true if the layout is desktop or larger
  static bool isDesktopUp(BuildContext context) {
    return getLayoutType(context) == LayoutType.desktop;
  }

  /// Gets the appropriate photo collage constraints for the current layout
  static BoxConstraints getPhotoCollageConstraints(LayoutType layoutType) {
    switch (layoutType) {
      case LayoutType.mobile:
        return const BoxConstraints();
      case LayoutType.tablet:
        return const BoxConstraints(maxWidth: 500);
      case LayoutType.desktop:
        return const BoxConstraints(maxWidth: 300, minWidth: 300);
    }
  }

  /// Gets the main axis direction for the entry layout
  static Axis getEntryLayoutAxis(LayoutType layoutType) {
    return layoutType == LayoutType.desktop ? Axis.horizontal : Axis.vertical;
  }

  /// Gets the flex value for the photo section in desktop layout
  static int getPhotoFlex(LayoutType layoutType) {
    return layoutType == LayoutType.desktop ? 0 : 1;
  }

  /// Gets the flex value for the content section in desktop layout
  static int getContentFlex(LayoutType layoutType) {
    return layoutType == LayoutType.desktop ? 1 : 1;
  }

  /// Gets appropriate spacing between photo and content sections
  static double getSectionSpacing(LayoutType layoutType) {
    switch (layoutType) {
      case LayoutType.mobile:
        return 0; // No spacing needed in mobile
      case LayoutType.tablet:
        return 0; // No spacing needed in tablet (still vertical)
      case LayoutType.desktop:
        return 24; // Horizontal spacing in desktop
    }
  }

  /// Gets the maximum container width for very large screens
  static double getMaxContainerWidth() {
    return maxContainerWidth;
  }

  /// Responsive padding based on layout type
  static EdgeInsets getContentPadding(LayoutType layoutType) {
    switch (layoutType) {
      case LayoutType.mobile:
        return const EdgeInsets.fromLTRB(24, 16, 24, 24);
      case LayoutType.tablet:
        return const EdgeInsets.fromLTRB(32, 24, 32, 32);
      case LayoutType.desktop:
        return const EdgeInsets.fromLTRB(24, 24, 24, 24);
    }
  }
}