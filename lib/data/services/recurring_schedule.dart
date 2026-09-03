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

        final diffMonths =
            (day.year - startDateOnly.year) * 12 + (day.month - startDateOnly.month);

        return diffMonths >= 0 && diffMonths % r.interval == 0;

      default:
        return false;
    }
  }

  /// Son çalıştığı tarih (dateOnly) — yoksa null
  static DateTime? lastRunDateOnly(RecurringRule r) {
    if (r.lastGeneratedAt == null) return null;
    return dateOnly(r.lastGeneratedAt!);
  }

  /// Bir sonraki çalışacağı tarih (dateOnly). Bulamazsa null.
  ///
  /// Not: Performans için ileriye doğru sınırlı tarıyoruz.
  /// daily/weekly için 400 gün, monthly için 5 yıl (60 ay) yeterli.
  static DateTime? nextRunDateOnly(RecurringRule r, {DateTime? now}) {
    final _now = now ?? DateTime.now();
    final today = dateOnly(_now);
    final start = dateOnly(r.startDate);

    // Kural daha başlamadıysa: start'tan itibaren ararız
    final base = today.isBefore(start) ? start : today;

    // Eğer bugün zaten üretildiyse, yarından başla
    final last = lastRunDateOnly(r);
    DateTime cursor = base;
    if (last != null && last == today) {
      cursor = today.add(const Duration(days: 1));
    }

    // Tarama limiti
    final int maxDays = (r.frequency == "monthly") ? (31 * 62) : 400; // ~5 yıl veya 400 gün
    for (int i = 0; i <= maxDays; i++) {
      final d = cursor.add(Duration(days: i));
      if (d.isBefore(start)) continue;
      if (isDueOn(r, d, start)) return d;
    }
    return null;
  }
}
