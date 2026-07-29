// lib/providers/risk_providers.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finansio/ai/risk_score.dart';
import 'package:finansio/providers/providers.dart';
import 'package:finansio/providers/budget_providers.dart';
import 'package:finansio/providers/forecast_providers.dart';

/// Home’da gösterilecek “Aylık Risk”
/// - forecastProvider (Future) + globalLimitStatusProvider + budgetStatusesProvider (Stream)
final monthlyRiskProvider = FutureProvider.autoDispose<RiskScoreResult>((ref) async {
  // autoDispose olduğu için home sayfasından çıkınca kapanır.
  // ama home içinde rebuild olsa bile Future cache eder.
  final keepAlive = ref.keepAlive();
  Timer(const Duration(minutes: 2), keepAlive.close); // 2 dk cache

  final forecast = await ref.watch(forecastProvider.future);
  final globalLimit = ref.watch(globalLimitStatusProvider);

  // budgetStatusesProvider StreamProvider -> ilk değeri al
  final budgets = await ref.watch(budgetStatusesProvider.future);

  return RiskScorer.computeMonthly(
    forecast: forecast,
    globalLimit: globalLimit,
    categoryBudgets: budgets,
  );
});
