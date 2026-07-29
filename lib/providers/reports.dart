// lib/providers/reports.dart
import 'package:finansio/data/app_database.dart';
import 'package:finansio/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);
DateTime _monthEndInclusive(DateTime d) =>
    DateTime(d.year, d.month + 1, 0, 23, 59, 59, 999);

({DateTime? start, DateTime? end}) _rangeFromFilter(FilterRange filter) {
  final now = DateTime.now();
  switch (filter) {
    case FilterRange.all:
      return (start: null, end: null);
    case FilterRange.thisMonth:
      return (start: _monthStart(now), end: _monthEndInclusive(now));
    case FilterRange.lastMonth:
      final last = DateTime(now.year, now.month - 1, 1);
      return (start: _monthStart(last), end: _monthEndInclusive(last));
  }
}

// ✅ Reports Summary (DB’den direkt)
final reportsSummaryProvider =
FutureProvider.autoDispose<SummaryTotals>((ref) async {
  final db = ref.watch(dbProvider);
  final filter = ref.watch(txFilterProvider);
  final r = _rangeFromFilter(filter);
  return db.fetchSummaryTotals(startDate: r.start, endDate: r.end);
});

// ✅ Kategori pastası (gider)
final categoryPieProvider =
FutureProvider.autoDispose<List<CategoryTotal>>((ref) async {
  final db = ref.watch(dbProvider);
  final filter = ref.watch(txFilterProvider);
  final r = _rangeFromFilter(filter);
  return db.sumExpensesByCategory(start: r.start, end: r.end);
});

// ✅ Aylık trend (Son 6 Ay)
final monthlyTrendProvider =
FutureProvider.autoDispose<List<MonthlyTotals>>((ref) async {
  final db = ref.watch(dbProvider);
  return db.monthlyTotals(monthsBack: 6);
});
