import '../services/completion_service.dart';

/// Mon–Sun week helpers for prayer scheduling
class PrayerWeekUtils {
  PrayerWeekUtils._();

  static const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static DateTime weekStart(DateTime at) =>
      CompletionService.weekStartMonday(at);

  static DateTime weekEnd(DateTime at) =>
      weekStart(at).add(const Duration(days: 6));

  static String formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static DateTime? parseDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return null;
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  static bool isInCurrentWeek(String dateStr, [DateTime? at]) {
    final date = parseDate(dateStr);
    if (date == null) return false;
    final now = at ?? DateTime.now();
    final start = weekStart(now);
    final end = weekEnd(now);
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  /// Selectable days Mon–Sun from today through end of week
  static List<WeekDayOption> selectableDays(
    DateTime now, {
    Set<String> bookedDates = const {},
  }) {
    final start = weekStart(now);
    final today = DateTime(now.year, now.month, now.day);
    final options = <WeekDayOption>[];

    for (var i = 0; i < 7; i++) {
      final day = start.add(Duration(days: i));
      final dateStr = formatDate(day);
      final isPast = day.isBefore(today);
      options.add(
        WeekDayOption(
          dateStr: dateStr,
          dayLabel: dayLabels[i],
          isToday: dateStr == formatDate(now),
          isPast: isPast,
          isBooked: bookedDates.contains(dateStr),
        ),
      );
    }
    return options;
  }
}

class WeekDayOption {
  const WeekDayOption({
    required this.dateStr,
    required this.dayLabel,
    required this.isToday,
    required this.isPast,
    required this.isBooked,
  });

  final String dateStr;
  final String dayLabel;
  final bool isToday;
  final bool isPast;
  final bool isBooked;

  bool get isSelectable => !isPast && !isBooked;
}
