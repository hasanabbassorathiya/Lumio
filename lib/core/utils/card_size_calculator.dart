import '../platform/platform_detector.dart';
import '../services/service_locator.dart';

/// Card size calculation utility
/// Dynamically calculate card count and size based on available width, adapting to all platforms
class CardSizeCalculator {
  /// Card spacing
  static double get spacing => PlatformDetector.isMobile ? 6.0 : 7.0;
  
  /// Card aspect ratio (W:H) - unified ratio regardless of EPG
  /// Higher values result in wider cards, lower values in taller cards
  /// Adjusted to a moderate ratio to ensure EPG visibility
  // static double get aspectRatio => PlatformDetector.isMobile ? 0.85 : 1;
  static double aspectRatio() {
    if (PlatformDetector.isMobile) {
      return 0.85;
    } else if (PlatformDetector.isTV) {
      return 0.9;
    } else {
      return 1;
    }
  }

  
  /// Calculate cards per row (for channel page Grid)
  static int calculateCardsPerRow(double availableWidth) {
    int cardsPerRow;
    String mode;
    
    if (PlatformDetector.isMobile) {
      // Mobile: determine landscape or portrait based on width
      if (availableWidth > 700) {
        // Landscape mode - show more cards
        mode = 'Landscape';
        if (availableWidth > 900) {
          cardsPerRow = 10;
        } else if (availableWidth > 800) {
          cardsPerRow = 9;
        } else {
          cardsPerRow = 9;
        }
      } else {
        // Portrait mode
        mode = 'Portrait';
        if (availableWidth > 450) {
          cardsPerRow = 6;
        } else if (availableWidth > 350) {
          cardsPerRow = 5;
        } else if (availableWidth > 250) {
          cardsPerRow = 4;
        } else {
          cardsPerRow = 3;
        }
      }
      ServiceLocator.log.d('Channel page card calculation - Mobile $mode: Width=${availableWidth.toStringAsFixed(1)}px, per row=$cardsPerRow cards', tag: 'CardSize');
      return cardsPerRow;
    } else if (PlatformDetector.isTV) {
      // TV side channel page: moderate card count to ensure EPG readability
      // if (availableWidth > 1400) return 9;
      // if (availableWidth > 1200) return 8;
      // if (availableWidth > 1000) return 7;
      // if (availableWidth > 800) return 6;
      if (availableWidth > 1800) {
        cardsPerRow = 11;
      } else if (availableWidth > 1600) {
        cardsPerRow = 12;
      } else if (availableWidth > 1400) {
        cardsPerRow = 9;
      } else if (availableWidth > 1200) {
        cardsPerRow = 9;
      } else if (availableWidth > 1000) {
        cardsPerRow = 8;
      } else if (availableWidth > 800) {
        cardsPerRow = 8;
      } else if (availableWidth > 780) {
        cardsPerRow = 7;
      } else if (availableWidth > 750) {
        cardsPerRow = 7;
      } else if (availableWidth > 700) {
        cardsPerRow = 6;
      } else if (availableWidth > 600) {
        cardsPerRow = 6;
      } else {
        cardsPerRow = 5;
      }
      ServiceLocator.log.d('Channel page card calculation - TV side: Width=${availableWidth.toStringAsFixed(1)}px, per row=$cardsPerRow cards', tag: 'CardSize');
      return cardsPerRow;
    } else {
      // Windows/Desktop: moderate card count
      if (availableWidth > 1800) {
        cardsPerRow = 13;
      } else if (availableWidth > 1600) {
        cardsPerRow = 12;
      } else if (availableWidth > 1400) {
        cardsPerRow = 11;
      } else if (availableWidth > 1200) {
        cardsPerRow = 10;
      } else if (availableWidth > 1000) {
        cardsPerRow = 9;
      } else if (availableWidth > 800) {
        cardsPerRow = 7;
      } else if (availableWidth > 780) {
        cardsPerRow = 6;
      } else if (availableWidth > 750) {
        cardsPerRow = 5;
      } else if (availableWidth > 725) {
        cardsPerRow = 5;
      } else if (availableWidth > 700) {
        cardsPerRow = 5;
      } else if (availableWidth > 600) {
        cardsPerRow = 4;
      } else {
        cardsPerRow = 3;
      }
      ServiceLocator.log.d('Channel page card calculation - Desktop side: Width=${availableWidth.toStringAsFixed(1)}px, per row=$cardsPerRow cards', tag: 'CardSize');
      return cardsPerRow;
    }
  }
  
  /// Calculate home screen cards per row (requires more smaller cards)
  static int calculateHomeCardsPerRow(double availableWidth) {
    int cardsPerRow;
    String mode;
    
    if (PlatformDetector.isMobile) {
      // Mobile: determine landscape or portrait based on width
      if (availableWidth > 700) {
        // Landscape mode - show more cards
        mode = 'Landscape';
        if (availableWidth > 900) {
          cardsPerRow = 10;
        } else if (availableWidth > 800) {
          cardsPerRow = 9;
        } else {
          cardsPerRow = 9;
        }
      } else {
        // Portrait mode
        mode = 'Portrait';
        if (availableWidth > 450) {
          cardsPerRow = 5;
        } else if (availableWidth > 350) {
          cardsPerRow = 4;
        } else if (availableWidth > 250) {
          cardsPerRow = 4;
        } else {
          cardsPerRow = 3;
        }
      }
      ServiceLocator.log.d('Home screen card calculation - Mobile $mode: Width=${availableWidth.toStringAsFixed(1)}px, per row=$cardsPerRow cards', tag: 'CardSize');
      return cardsPerRow;
    } else if (PlatformDetector.isTV) {
      // TV side home screen: full width ~1800px, moderate card count
      if (availableWidth > 1800) {
        cardsPerRow = 13;
      } else if (availableWidth > 1600) {
        cardsPerRow = 12;
      } else if (availableWidth > 1400) {
        cardsPerRow = 11;
      } else if (availableWidth > 1200) {
        cardsPerRow = 10;
      } else if (availableWidth > 1000) {
        cardsPerRow = 9;
      } else if (availableWidth > 800) {
        cardsPerRow = 7;
      } else if (availableWidth > 780) {
        cardsPerRow = 6;
      } else if (availableWidth > 750) {
        cardsPerRow = 6;
      } else if (availableWidth > 700) {
        cardsPerRow = 6;
      } else if (availableWidth > 600) {
        cardsPerRow = 5;
      } else {
        cardsPerRow = 5;
      }
      ServiceLocator.log.d('Home screen card calculation - TV side: Width=${availableWidth.toStringAsFixed(1)}px, per row=$cardsPerRow cards', tag: 'CardSize');
      return cardsPerRow;
    } else {
      // Windows home screen
      if (availableWidth > 1800) {
        cardsPerRow = 13;
      } else if (availableWidth > 1600) {
        cardsPerRow = 12;
      } else if (availableWidth > 1400) {
        cardsPerRow = 11;
      } else if (availableWidth > 1200) {
        cardsPerRow = 10;
      } else if (availableWidth > 1000) {
        cardsPerRow = 9;
      } else if (availableWidth > 800) {
        cardsPerRow = 7;
      } else if (availableWidth > 780) {
        cardsPerRow = 6;
      } else if (availableWidth > 750) {
        cardsPerRow = 5;
      } else if (availableWidth > 700) {
        cardsPerRow = 5;
      } else if (availableWidth > 600) {
        cardsPerRow = 4;
      } else {
        cardsPerRow = 5;
      }
      ServiceLocator.log.d('Home screen card calculation - Desktop side: Width=${availableWidth.toStringAsFixed(1)}px, per row=$cardsPerRow cards', tag: 'CardSize');
      return cardsPerRow;
    }
  }
  
  /// Calculate card width
  static double calculateCardWidth(double availableWidth) {
    final cardsPerRow = calculateCardsPerRow(availableWidth);
    final totalSpacing = (cardsPerRow + 1) * spacing;
    return (availableWidth - totalSpacing) / cardsPerRow;
  }
  
  /// Calculate card height
  static double calculateCardHeight(double availableWidth) {
    return calculateCardWidth(availableWidth) / aspectRatio();
  }
  
  /// Get GridView crossAxisCount
  static int getGridCrossAxisCount(double availableWidth) {
    return calculateCardsPerRow(availableWidth);
  }
  
  /// Get GridView childAspectRatio
  static double getGridChildAspectRatio() {
    return aspectRatio();
  }
  
  /// Get GridView crossAxisSpacing
  static double getGridCrossAxisSpacing() {
    return spacing;
  }
  
  /// Get GridView mainAxisSpacing
  static double getGridMainAxisSpacing() {
    return spacing;
  }
}
