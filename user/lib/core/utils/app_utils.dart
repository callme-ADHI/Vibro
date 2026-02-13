// VIBRO Utility Functions
import 'package:intl/intl.dart';

class AppUtils {
  AppUtils._();

  /// Format timestamp to readable string
  static String formatTimestamp(DateTime dateTime, {bool showTime = true}) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      if (showTime) {
        return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
      } else {
        return DateFormat('MMM dd, yyyy').format(dateTime);
      }
    }
  }

  /// Format confidence percentage
  static String formatConfidence(double confidence) {
    return '${(confidence * 100).toStringAsFixed(0)}%';
  }

  /// Format battery percentage
  static String formatBattery(int percentage) {
    return '$percentage%';
  }

  /// Get confidence color indicator
  static String getConfidenceLevel(double confidence) {
    if (confidence >= 0.70) return 'high';
    if (confidence >= 0.50) return 'medium';
    return 'low';
  }

  /// Validate phone number (basic validation)
  static bool isValidPhoneNumber(String phone) {
    final regex = RegExp(r'^\+?[1-9]\d{1,14}$');
    return regex.hasMatch(phone.replaceAll(RegExp(r'[\s-]'), ''));
  }

  /// Validate username
  static bool isValidUsername(String username) {
    return username.length >= 3 && username.length <= 25;
  }

  /// Generate UUID-like identifier
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Calculate total training samples
  static int calculateTrainingSamples(int originalClips) {
    const int augmentedSamplesPerClip = 10;
    const int extraBaseSamples = 10;
    return (originalClips * augmentedSamplesPerClip) + extraBaseSamples;
  }

  /// Truncate text with ellipsis
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
