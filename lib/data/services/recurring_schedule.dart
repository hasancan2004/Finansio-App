import '../database/app_database.dart';

class RecurringSchedule {
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static int _clampDayOfMonth(int year, int month, int desiredDay) {
    final lastDay = DateTime(year, month + 1, 0).day;
    if (desiredDay < 1) return 1;
    if (desiredDay > lastDay) return lastDay;
    return desiredDay;
  }

  static bool isDueOn(RecurringRule r, DateTime day, DateTime startDateOnly) {
    switch (r.frequency) {
      case "daily":
        final diffDays = day.difference(startDateOnly).inDays;
        return diffDays >= 0 && diffDays % r.interval == 0;

      case "weekly":
        final dow = r.dayOfPeriod;
        if (dow == null) return false;

        if (day.weekday != dow) return false;

        final diffDays = day.difference(startDateOnly).inDays;
        if (diffDays < 0) return false;

        final diffWeeks = diffDays ~/ 7;
        return diffWeeks % r.interval == 0;

      case "monthly":
        final dom = r.dayOfPeriod;
        if (dom == null) return false;

        final targetDay = _clampDayOfMonth(day.year, day.month, dom);
        if (day.day != targetDay) return false;

        // ✅ Eksik eksi (-) ve çarpı (*) operatörleri eklendi
        final diffMonths = (day.year - startDateOnly.year) * 12 + (day.month - startDateOnly.month);

        return diffMonths >= 0 && diffMonths % r.interval == 0;

      default:
        return false;
    }
  }

  static DateTime? lastRunDateOnly(RecurringRule r) {
    if (r.lastGeneratedAt == null) return null;
    return dateOnly(r.lastGeneratedAt!);
  }

  static DateTime? nextRunDateOnly(RecurringRule r, {DateTime? now}) {
    final currentNow = now ?? DateTime.now();
    final today = dateOnly(currentNow);
    final start = dateOnly(r.startDate);

    final base = today.isBefore(start) ? start : today;

    final last = lastRunDateOnly(r);
    DateTime cursor = base;
    if (last != null && last == today) {
      cursor = today.add(const Duration(days: 1));
    }

    // ✅ Çarpı (*) operatörü düzeltildi (31 * 60 = ~5 yıl)
    final int maxDays = (r.frequency == "monthly") ? (31 * 60) : 400;
    for (int i = 0; i <= maxDays; i++) {
      final d = cursor.add(Duration(days: i));
      if (d.isBefore(start)) continue;
      if (isDueOn(r, d, start)) return d;
    }
    return null;
  }
}