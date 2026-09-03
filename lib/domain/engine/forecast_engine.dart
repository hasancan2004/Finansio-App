// lib/ai/forecast_engine.dart
class ForecastResult {
  final double predictedExpenseMonth; // ay sonu toplam gider (pozitif)
  final double predictedIncomeMonth;  // ay sonu toplam gelir (pozitif)
  final double predictedNetMonth;     // income - expense

  final double expenseSoFar;          // şu ana kadar gider
  final double incomeSoFar;           // şu ana kadar gelir

  final int dayOfMonth;               // bugün ayın kaçıncı günü
  final int daysInMonth;              // ay toplam gün

  final String explanation;

  const ForecastResult({
    required this.predictedExpenseMonth,
    required this.predictedIncomeMonth,
    required this.predictedNetMonth,
    required this.expenseSoFar,
    required this.incomeSoFar,
    required this.dayOfMonth,
    required this.daysInMonth,
    required this.explanation,
  });
}

class ForecastEngine {
  static ForecastResult forecastMonth({
    required List<double> dailyExpenseAbs, // length = dayOfMonth
    required List<double> dailyIncome,     // length = dayOfMonth
    required int dayOfMonth,
    required int daysInMonth,
  }) {
    final expSoFar = dailyExpenseAbs.fold(0.0, (a, b) => a + b);
    final incSoFar = dailyIncome.fold(0.0, (a, b) => a + b);

    final expAvg = dayOfMonth > 0 ? expSoFar / dayOfMonth : 0.0;
    final incAvg = dayOfMonth > 0 ? incSoFar / dayOfMonth : 0.0;

    final expPred = expAvg * daysInMonth;
    final incPred = incAvg * daysInMonth;
    final netPred = incPred - expPred;

    return ForecastResult(
      predictedExpenseMonth: expPred,
      predictedIncomeMonth: incPred,
      predictedNetMonth: netPred,
      expenseSoFar: expSoFar,
      incomeSoFar: incSoFar,
      dayOfMonth: dayOfMonth,
      daysInMonth: daysInMonth,
      explanation: "Bu ayın ilk $dayOfMonth günündeki ortalamaya göre projeksiyon.",
    );
  }
}
