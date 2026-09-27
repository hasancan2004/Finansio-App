// lib/providers/reports.dart
import 'package:finansio/data/database/app_database.dart';
import 'package:finansio/presentation/transactions/viewmodel/tx_providers.dart';
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

// ✅ Reports Summary (Tetikleyici Eklendi & autoDispose kaldırıldı)
final reportsSummaryProvider =
FutureProvider<SummaryTotals>((ref) async {
  final db = ref.watch(dbProvider);
  ref.watch(txStreamProvider); // ✅ GİZLİ TETİKLEYİCİ: İşlem değiştiğinde otomatik yeniler
  final filter = ref.watch(txFilterProvider);
  final r = _rangeFromFilter(filter);
  return db.fetchSummaryTotals(startDate: r.start, endDate: r.end);
});

// ✅ Kategori pastası (Tetikleyici Eklendi & autoDispose kaldırıldı)
final categoryPieProvider =
FutureProvider<List<CategoryTotal>>((ref) async {
  final db = ref.watch(dbProvider);
  ref.watch(txStreamProvider); // ✅ GİZLİ TETİKLEYİCİ: İşlem değiştiğinde otomatik yeniler
  final filter = ref.watch(txFilterProvider);
  final r = _rangeFromFilter(filter);
  return db.sumExpensesByCategory(start: r.start, end: r.end);
});

// ✅ Aylık trend (Tetikleyici Eklendi & autoDispose kaldırıldı)
final monthlyTrendProvider =
FutureProvider<List<MonthlyTotals>>((ref) async {
  final db = ref.watch(dbProvider);
  ref.watch(txStreamProvider); // ✅ GİZLİ TETİKLEYİCİ: İşlem değiştiğinde otomatik yeniler
  return db.monthlyTotals(monthsBack: 6);
});