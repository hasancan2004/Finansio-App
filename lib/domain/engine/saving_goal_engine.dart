// Birikim hedefi tahmin motoru.
//
// Hedefin ne kadar sürede tamamlanacağını, kullanıcının şu ana kadarki
// ortalama birikim hızına göre kestirir. Flutter / Drift bağımlılığı içermez.

/// Bir hedef için hesaplanmış tahmin değerleri.
class GoalEstimate {
  final double progress; // 0..1
  final double remainingAmount;
  final double monthlyRate; // tahmini ₺/ay birikim hızı
  final double? monthsToReach; // null = kestirilemiyor
  final DateTime? estimatedFinish; // null = kestirilemiyor
  final DateTime? targetDate;
  final bool isCompleted;

  const GoalEstimate({
    required this.progress,
    required this.remainingAmount,
    required this.monthlyRate,
    required this.monthsToReach,
    required this.estimatedFinish,
    required this.targetDate,
    required this.isCompleted,
  });
}

class SavingGoalEngine {
  const SavingGoalEngine._();

  static const double _avgDaysPerMonth = 30.44;

  static GoalEstimate estimate({
    required double currentAmount,
    required double targetAmount,
    required DateTime createdAt,
    DateTime? targetDate,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();

    final progress = targetAmount > 0
        ? (currentAmount / targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final remaining =
        (targetAmount - currentAmount).clamp(0.0, double.infinity);
    final isCompleted = targetAmount > 0 && currentAmount >= targetAmount;

    if (currentAmount <= 0) {
      return GoalEstimate(
        progress: progress,
        remainingAmount: remaining,
        monthlyRate: 0,
        monthsToReach: null,
        estimatedFinish: null,
        targetDate: targetDate,
        isCompleted: isCompleted,
      );
    }

    final daysSince = today.difference(createdAt).inDays;
    // Henüz bir ay dolmadıysa bile en az 1 aylık varmış gibi hesapla ki
    // yeni eklenen hedef için uçuk hızlı tahmin çıkmasın.
    final elapsedMonths = (daysSince / _avgDaysPerMonth).clamp(1.0, double.infinity);
    final monthlyRate = currentAmount / elapsedMonths;

    final double monthsToReach = remaining > 0 ? (remaining / monthlyRate) : 0;
    final estimatedFinish =
        today.add(Duration(days: (monthsToReach * _avgDaysPerMonth).round()));

    return GoalEstimate(
      progress: progress,
      remainingAmount: remaining,
      monthlyRate: monthlyRate,
      monthsToReach: monthsToReach,
      estimatedFinish: estimatedFinish,
      targetDate: targetDate,
      isCompleted: isCompleted,
    );
  }
}
