// lib/providers/forecast_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finansio/presentation/transactions/viewmodel/tx_providers.dart';
import 'package:finansio/domain/engine/forecast_engine.dart';

final forecastProvider = FutureProvider<ForecastResult>((ref) async {
  final db = ref.read(dbProvider);

  final now = DateTime.now();
  final daysInMonth = _daysInMonth(now);

  final res = await db.fetchThisMonthDailyIncomeExpense();

  return ForecastEngine.forecastMonth(
    dailyExpenseAbs: res.expenseAbsDaily,
    dailyIncome: res.incomeDaily,
    dayOfMonth: now.day,
    daysInMonth: daysInMonth,
  );
});

int _daysInMonth(DateTime d) {
  final firstNextMonth = DateTime(d.year, d.month + 1, 1);
  final lastDayThisMonth = firstNextMonth.subtract(const Duration(days: 1));
  return lastDayThisMonth.day;
}
