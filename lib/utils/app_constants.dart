import 'package:intl/intl.dart';

/// Centralized application constants and utilities
class AppConstants {
  /// UUID for visitor mode - centralized so we can easily change it if needed
  static const String visitorUserId = '00000000-0000-0000-0000-000000000000';
}

/// Centralized date formatting utilities
class DateUtils {
  /// Standard date format: yyyy/mm/dd
  static final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');
  
  /// Standard datetime format: yyyy/mm/dd HH:mm
  static final DateFormat _dateTimeFormat = DateFormat('yyyy/MM/dd HH:mm');
  
  /// Format DateTime to standard date string (yyyy/mm/dd)
  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }
  
  /// Format DateTime to standard datetime string (yyyy/mm/dd HH:mm)
  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime);
  }
  
  /// Format date string to standard format (yyyy/mm/dd)
  /// Used for parsing ISO strings from APIs like Supabase
  static String formatDateString(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return formatDate(date);
    } catch (e) {
      return 'Invalid date';
    }
  }
  
  /// Format datetime string to standard format (yyyy/mm/dd HH:mm)
  /// Used for parsing ISO strings from APIs like Supabase
  static String formatDateTimeString(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return formatDateTime(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
  }
} 