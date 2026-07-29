import 'package:finansio/ai/forecast_engine.dart';
import 'package:finansio/data/app_database.dart';
import 'package:finansio/providers/providers.dart';

enum RiskLevel {low, medium, high}

class RiskScoreResult {
  final int score;
  final RiskLevel level;
  final String title;
  final List<String> reasons;
  final String? footer;

  const RiskScoreResult({
    required this.score,
    required this.level,
    required this.title,
    required this.reasons,
    this.footer,
  });
}

class RiskScorer {
  /// “Aylık genel risk” = (Forecast + GlobalLimit + Kategori bütçeleri)
  static RiskScoreResult computeMonthly({
    required ForecastResult forecast,
    required GlobalLimitStatus globalLimit,
    required List<BudgetStatus> categoryBudgets,
}) {
    int score = 0;
    final reasons = <String>[];

    // ------------------------------
    // 1) Forecast etkisi (0..40)
    // ------------------------------
    // predictedNetMonth < 0 ise risk artar
    if (forecast.predictedNetMonth < 0) {
      // net negatife gittikçe artan risk (max 40)
      final neg = -forecast.predictedNetMonth.abs();
      final add = (neg / 1000.0 * 10).clamp(12.0, 40.0).round(); // kaba ölçek
      score += add;

      reasons.add("Tahmin: ay sonu netin eksiye düşebilir.");
    } else {
      // pozitifte düşük ama yine küçük risk (0..6)
      final add = (forecast.predictedExpenseMonth / 10000.0 * 6).clamp(0.0, 6.0).round();
      score += add;
      reasons.add("Tahmin: ay sonu görünümü genel olarak stabil.");
    }

    // ------------------------------
    // 2) Global limit etkisi (0..35)
    // ------------------------------
    if (globalLimit.enabled) {
      if (globalLimit.exceeded) {
        score += 35;
        reasons.add("Genel aylık limit aşıldı.");
      } else if (globalLimit.near) {
        score += 22;
        reasons.add("Genel limite çok yaklaştın");
      } else {
        // progress 0..0.8 ise 0..12 arası
        final add = (globalLimit.progress / 0.8 * 12).clamp(0.0, 12.0).round();
        score += add;
      }
    }

    // ------------------------------
    // 3) Kategori bütçeleri (0..25)
    // ------------------------------
    // exceeded: +10 her biri (max 20), near: +5 her biri (max 15) ama toplam 25 clamp
    final exceededCount = categoryBudgets.where((b) => (b.progress ?? 0) > 1.0).length;
    final nearCount = categoryBudgets
        .where((b) => (b.progress ?? 0) > 0.8 && (b.progress ?? 0) <= 1.0)
        .length;

    int addBud = (exceededCount * 10) + (nearCount * 5);
    addBud = addBud.clamp(0, 25);
    score += addBud;

    if (exceededCount > 0) {
      reasons.add("$exceededCount kategori bütçesi aşıldı.");
    } else if (nearCount > 0){
      reasons.add("$nearCount kategoride bütçeye yaklaştın.");
    }

    // ------------------------------
    // Final clamp + level
    // ------------------------------
    score = score.clamp(0, 100);
    final RiskLevel level;
    String title;

    if (score >= 70) {
      level = RiskLevel.high;
      title = "Risk: Yüksek";
    } else if (score >= 40) {
      level = RiskLevel.medium;
      title = "Risk: Orta";
    } else {
      level = RiskLevel.low;
      title = "Risk: Düşük";
    }

    // reasons'i 3 maddeye indir
    final trimmedReasons = reasons.where((e) => e.trim().isNotEmpty).toList();
    final shown = trimmedReasons.take(3).toList();

    return RiskScoreResult(
      score: score,
      level: level,
      title: title,
      reasons: shown.isEmpty ? const ["Veri az, risk hesaplanıyor…"] : shown,
      footer: "Bu skor; tahmin + limit + bütçelerden hesaplanır.",
    );
  }
}