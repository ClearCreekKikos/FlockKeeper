// lib/shared/utils/date_helper.dart

import 'package:intl/intl.dart';

DateTime parseDateTimeSafe(dynamic value, [DateTime? fallback]) {
  if (value == null) return fallback ?? DateTime.now();
  final String dateStr = value.toString().trim();
  if (dateStr.isEmpty) return fallback ?? DateTime.now();

  // Sanitize double Z and space-separators
  final sanitizedStr = dateStr.replaceAll('ZZ', 'Z').replaceFirst(' ', 'T');

  try {
    return DateTime.parse(sanitizedStr);
  } catch (_) {
    // Attempt standard date-only parsing
    try {
      return DateFormat('yyyy-MM-dd').parse(sanitizedStr);
    } catch (_) {
      try {
        return DateFormat('yyyy-MM-dd HH:mm:ss').parse(sanitizedStr);
      } catch (_) {
        return fallback ?? DateTime.now();
      }
    }
  }
}
