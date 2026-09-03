// lib/ai/spending_analyzer.dart

class AnomalyResult {
  final bool isAnomaly;
  final String title;
  final String message;

  final double? median;
  final double? threshold;

  const AnomalyResult({
    required this.isAnomaly,
    required this.title,
    required this.message,
    this.median,
    this.threshold,
  });

  static const none = AnomalyResult(
    isAnomaly: false,
    title: "",
    message: "",
  );
}

class SpendingAnalyzer {
  /// Basit median helper
  static double _median(List<double> xs) {
    if (xs.isEmpty) return 0;
    final s = [...xs]..sort();
    final mid = s.length ~/ 2;
    if (s.length.isOdd) return s[mid];
    return (s[mid - 1] + s[mid]) / 2.0;
  }

  /// ✅ KATEGORİ BAZLI ANOMALİ
  /// pastAbsExpenses: aynı kategoride geçmiş giderlerin abs değerleri (pozitif)
  static AnomalyResult detectCategoryExpenseAnomaly({
    required List<double> pastAbsExpenses,
    required double newAbsExpense,
    required String categoryName,
    int minHistoryCount = 8,
    double multiplier = 2.4,
    double minAbs = 250.0,
  }) {
    if (newAbsExpense <= 0) return AnomalyResult.none;
    if (pastAbsExpenses.length < minHistoryCount) {
      // history azsa hiç uyarma (global fallback yapacağız)
      return AnomalyResult.none;
    }

    final med = _median(pastAbsExpenses);
    final thr = (med * multiplier);

    // iki şart: kategori median * multiplier + minAbs
    final effectiveThr = thr < minAbs ? minAbs : thr;
    final isAnomaly = newAbsExpense >= effectiveThr;

    if (!isAnomaly) return AnomalyResult.none;

    return AnomalyResult(
      isAnomaly: true,
      title: "Kategori bazlı olağandışı harcama",
      message:
      "'$categoryName' kategorisinde bu tutar alışılmıştan yüksek görünüyor.",
      median: med,
      threshold: effectiveThr,
    );
  }

  /// ✅ GLOBAL ANOMALİ (senin mevcut fonksiyonun yerine de bunu kullanabilirsin)
  static AnomalyResult detectGlobalExpenseAnomaly({
    required List<double> pastAbsExpenses,
    required double newAbsExpense,
    int minHistoryCount = 10,
    double multiplier = 2.2,
    double minAbs = 350.0,
  }) {
    if (newAbsExpense <= 0) return AnomalyResult.none;
    if (pastAbsExpenses.length < minHistoryCount) return AnomalyResult.none;

    final med = _median(pastAbsExpenses);
    final thr = (med * multiplier);
    final effectiveThr = thr < minAbs ? minAbs : thr;
    final isAnomaly = newAbsExpense >= effectiveThr;

    if (!isAnomaly) return AnomalyResult.none;

    return AnomalyResult(
      isAnomaly: true,
      title: "Genel olağandışı harcama",
      message: "Genel harcama alışkanlıklarına göre bu tutar yüksek görünüyor.",
      median: med,
      threshold: effectiveThr,
    );
  }
}
