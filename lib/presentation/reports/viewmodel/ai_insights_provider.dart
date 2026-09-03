import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../transactions/viewmodel/tx_providers.dart';

DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);
DateTime _monthEndInclusive(DateTime d) =>
    DateTime(d.year, d.month + 1, 0, 23, 59, 59, 999);

class AiInsightsData {
  final SummaryLite thisMonth;
  final SummaryLite lastMonth;

  final String? topExpenseCategoryName;
  final double topExpenseCategoryAmount; // positive

  final double expenseChangePct; // lastMonth -> thisMonth (can be negative)

  // ✅ NEW: category delta
  final String? mostIncreasedCategoryName;
  final double mostIncreasedDeltaAmount; // + amount
  final double? mostIncreasedDeltaPct; // nullable (if last=0)

  // ✅ NEW: (bonus) most decreased
  final String? mostDecreasedCategoryName;
  final double mostDecreasedDeltaAmount; // negative amount
  final double? mostDecreasedDeltaPct; // nullable

  final List<String> insights; // ready-to-show lines

  const AiInsightsData({
    required this.thisMonth,
    required this.lastMonth,
    required this.topExpenseCategoryName,
    required this.topExpenseCategoryAmount,
    required this.expenseChangePct,
    required this.mostIncreasedCategoryName,
    required this.mostIncreasedDeltaAmount,
    required this.mostIncreasedDeltaPct,
    required this.mostDecreasedCategoryName,
    required this.mostDecreasedDeltaAmount,
    required this.mostDecreasedDeltaPct,
    required this.insights,
  });
}

class SummaryLite {
  final double income;
  final double expense; // positive
  final double net;

  const SummaryLite({
    required this.income,
    required this.expense,
    required this.net,
  });
}

/// Bu ay işlemleri (global)
final aiThisMonthTxsProvider = StreamProvider<List<Tx>>((ref) {
  final db = ref.watch(dbProvider);
  final now = DateTime.now();
  final start = _monthStart(now);
  final end = _monthEndInclusive(now);

  return db.watchTransactions(
    startDate: start,
    endDate: end,
    categoryId: null,
    minAmount: null,
    maxAmount: null,
    sortByAmount: false,
    sortAsc: false,
    query: null,
  );
});

/// Geçen ay işlemleri (global)
final aiLastMonthTxsProvider = StreamProvider<List<Tx>>((ref) {
  final db = ref.watch(dbProvider);
  final now = DateTime.now();
  final last = DateTime(now.year, now.month - 1, 1);
  final start = _monthStart(last);
  final end = _monthEndInclusive(last);

  return db.watchTransactions(
    startDate: start,
    endDate: end,
    categoryId: null,
    minAmount: null,
    maxAmount: null,
    sortByAmount: false,
    sortAsc: false,
    query: null,
  );
});

/// Üst seviye AI Insights (bu ay vs geçen ay + top kategori + yorumlar)
final aiInsightsProvider = Provider<AsyncValue<AiInsightsData>>((ref) {
  final thisMonthAsync = ref.watch(aiThisMonthTxsProvider);
  final lastMonthAsync = ref.watch(aiLastMonthTxsProvider);

  if (thisMonthAsync.isLoading || lastMonthAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (thisMonthAsync.hasError) {
    return AsyncValue.error(thisMonthAsync.error!, thisMonthAsync.stackTrace!);
  }
  if (lastMonthAsync.hasError) {
    return AsyncValue.error(lastMonthAsync.error!, lastMonthAsync.stackTrace!);
  }

  final thisTxs = thisMonthAsync.value ?? [];
  final lastTxs = lastMonthAsync.value ?? [];

  SummaryLite summarize(List<Tx> list) {
    double income = 0;
    double expense = 0; // positive
    for (final t in list) {
      if (t.amount >= 0) {
        income += t.amount;
      } else {
        expense += t.amount.abs();
      }
    }
    final net = income - expense;
    return SummaryLite(income: income, expense: expense, net: net);
  }

  final thisSum = summarize(thisTxs);
  final lastSum = summarize(lastTxs);

  // Expense change %
  double expenseChangePct;
  if (lastSum.expense <= 0) {
    expenseChangePct = thisSum.expense > 0 ? 100 : 0;
  } else {
    expenseChangePct =
        ((thisSum.expense - lastSum.expense) / lastSum.expense) * 100.0;
  }

  // ---------- helpers: category expense maps ----------
  Map<int, double> buildExpenseByCat(List<Tx> list) {
    final map = <int, double>{};
    for (final t in list) {
      if (t.amount < 0) {
        final id = t.category.id;
        map[id] = (map[id] ?? 0) + t.amount.abs();
      }
    }
    return map;
  }

  Map<int, String> buildCatNames(List<Tx> a, List<Tx> b) {
    final map = <int, String>{};
    for (final t in [...a, ...b]) {
      map[t.category.id] = t.category.name;
    }
    return map;
  }

  final thisCatExpense = buildExpenseByCat(thisTxs);
  final lastCatExpense = buildExpenseByCat(lastTxs);
  final catNames = buildCatNames(thisTxs, lastTxs);

  // Top expense category this month
  String? topName;
  double topAmount = 0;
  if (thisCatExpense.isNotEmpty) {
    final topEntry = thisCatExpense.entries
        .reduce((a, b) => a.value >= b.value ? a : b);
    topAmount = topEntry.value;
    topName = catNames[topEntry.key];
  }

  // ✅ NEW: most increased/decreased category
  String? incName;
  double incDelta = 0;
  double? incPct;

  String? decName;
  double decDelta = 0; // negative
  double? decPct;

  // union of keys
  final allCatIds = <int>{
    ...thisCatExpense.keys,
    ...lastCatExpense.keys,
  };

  for (final id in allCatIds) {
    final thisV = thisCatExpense[id] ?? 0;
    final lastV = lastCatExpense[id] ?? 0;
    final delta = thisV - lastV; // + means increased spending

    // increased
    if (delta > incDelta) {
      incDelta = delta;
      incName = catNames[id] ?? "—";
      incPct = (lastV <= 0) ? null : (delta / lastV) * 100.0;
    }

    // decreased (delta negative) -> choose the most negative
    if (delta < decDelta) {
      decDelta = delta; // more negative = bigger decrease
      decName = catNames[id] ?? "—";
      decPct = (lastV <= 0) ? null : (delta.abs() / lastV) * 100.0;
    }
  }

  // Build insights text (kısa, ürün gibi)
  final List<String> insights = [];

  if (thisTxs.isEmpty) {
    insights.add(
        "Bu ay henüz işlem yok. İlk işlemini ekleyerek analizleri başlatabilirsin.");
  } else {
    if (expenseChangePct.abs() < 3) {
      insights.add("Bu ay giderlerin geçen aya göre neredeyse aynı seviyede.");
    } else if (expenseChangePct > 0) {
      insights.add(
          "Bu ay giderlerin geçen aya göre %${expenseChangePct.toStringAsFixed(0)} arttı.");
    } else {
      insights.add(
          "Bu ay giderlerin geçen aya göre %${expenseChangePct.abs().toStringAsFixed(0)} azaldı. Güzel gidiyorsun.");
    }

    if (topName != null && topAmount > 0) {
      insights.add("En çok harcama: $topName (₺${topAmount.toStringAsFixed(0)}).");
    }

    // ✅ NEW: category delta insight
    if (incName != null && incDelta > 0) {
      final pctText = (incPct == null)
          ? ""
          : " (≈ %${incPct!.toStringAsFixed(0)})";
      insights.add(
        "En çok artan kategori: $incName • +₺${incDelta.toStringAsFixed(0)}$pctText.",
      );
    }

    if (decName != null && decDelta < 0) {
      final pctText = (decPct == null)
          ? ""
          : " (≈ %${decPct!.toStringAsFixed(0)})";
      insights.add(
        "En çok azalan kategori: $decName • -₺${decDelta.abs().toStringAsFixed(0)}$pctText.",
      );
    }

    if (thisSum.net < 0) {
      insights.add(
          "Bu ay net bakiyen negatif. Giderleri biraz kısarsan ayı dengede kapatabilirsin.");
    } else {
      insights.add("Bu ay net bakiyen pozitif. Bu tempo ile ay sonu daha rahat geçer.");
    }

    if (thisSum.expense > 0 && thisSum.income > 0) {
      final ratio = (thisSum.expense / thisSum.income) * 100.0;
      if (ratio >= 90) {
        insights.add(
            "Gider/gelir oranı yüksek (%${ratio.toStringAsFixed(0)}). Küçük optimizasyonlar büyük fark yaratır.");
      } else if (ratio <= 60) {
        insights.add("Gider/gelir oranı iyi (%${ratio.toStringAsFixed(0)}). Böyle devam.");
      }
    }
  }

  return AsyncValue.data(
    AiInsightsData(
      thisMonth: thisSum,
      lastMonth: lastSum,
      topExpenseCategoryName: topName,
      topExpenseCategoryAmount: topAmount,
      expenseChangePct: expenseChangePct,
      mostIncreasedCategoryName: incName,
      mostIncreasedDeltaAmount: incDelta,
      mostIncreasedDeltaPct: incPct,
      mostDecreasedCategoryName: decName,
      mostDecreasedDeltaAmount: decDelta,
      mostDecreasedDeltaPct: decPct,
      insights: insights,
    ),
  );
});