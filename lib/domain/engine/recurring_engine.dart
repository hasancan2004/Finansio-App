import 'package:drift/drift.dart';
import '../../data/database/app_database.dart';

class RecurringEngine {
  final AppDatabase db;

  final int maxBackfillDays;
  final int maxCreatesPerRule;

  RecurringEngine(
      this.db, {
        this.maxBackfillDays = 7,
        this.maxCreatesPerRule = 50,
      });

  Future<int> run() async {
    final now = DateTime.now();
    final today = _dateOnly(now);
    int createdTotal = 0;

    final rules = await (db.select(db.recurringRules)
      ..where((t) => t.isActive.equals(true)))
        .get();

    for (final r in rules) {
      final start = _dateOnly(r.startDate);
      if (today.isBefore(start)) continue;

      final windowStart = today.subtract(Duration(days: maxBackfillDays));
      final effectiveStart = start.isAfter(windowStart) ? start : windowStart;

      DateTime? lastGenerated = r.lastGeneratedAt == null ? null : _dateOnly(r.lastGeneratedAt!);

      final from = lastGenerated == null
          ? effectiveStart
          : lastGenerated.add(const Duration(days: 1));

      if (from.isAfter(today)) continue;

      int createdForRule = 0;
      DateTime? lastProducedDateOnly;

      var cursor = from;
      while (!cursor.isAfter(today)) {
        if (createdForRule >= maxCreatesPerRule) break;

        if (_isDueOn(r, cursor, start)) {
          // extra safety
          if (lastGenerated != null && lastGenerated == cursor) {
            cursor = cursor.add(const Duration(days: 1));
            continue;
          }

          await _generateTransaction(r, _mergeTime(cursor, now));

          createdForRule++;
          createdTotal++;

          lastGenerated = cursor;
          lastProducedDateOnly = cursor;
        }

        cursor = cursor.add(const Duration(days: 1));
      }

      if (createdForRule > 0 && lastProducedDateOnly != null) {
        await (db.update(db.recurringRules)..where((t) => t.id.equals(r.id))).write(
          RecurringRulesCompanion(
            lastGeneratedAt: Value(_mergeTime(lastProducedDateOnly!, now)),
          ),
        );
      }
    }

    return createdTotal;
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _mergeTime(DateTime dateOnly, DateTime now) =>
      DateTime(dateOnly.year, dateOnly.month, dateOnly.day, now.hour, now.minute);

  bool _isDueOn(RecurringRule r, DateTime day, DateTime startDateOnly) {
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

  int _clampDayOfMonth(int year, int month, int desiredDay) {
    final lastDay = DateTime(year, month + 1, 0).day;
    if (desiredDay < 1) return 1;
    if (desiredDay > lastDay) return lastDay;
    return desiredDay;
  }

  Future<void> _generateTransaction(RecurringRule r, DateTime dateTime) async {
    final amount = r.isIncome ? r.amount : -r.amount;

    await db.transaction(() async {
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          amount: amount,
          categoryId: r.categoryId,
          note: Value(r.note),
          date: Value(dateTime),
        ),
      );
    });
  }
}
