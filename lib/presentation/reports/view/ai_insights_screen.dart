import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../viewmodel/ai_insights_provider.dart';
import '../../budgets/viewmodel/budget_providers.dart';
import '../../transactions/viewmodel/tx_providers.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/app_header.dart';

class AIInsightsScreen extends ConsumerWidget {
  const AIInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // ✅ ₺ sağda: "10.000 ₺"
    final _tryFmt = NumberFormat("#,##0", "tr_TR");
    String tr(num v) => "${_tryFmt.format(v)} ₺";

    final insightsAsync = ref.watch(aiInsightsProvider);
    final globalLimit = ref.watch(globalLimitStatusProvider);
    final budgetsAsync = ref.watch(budgetStatusesProvider);

    int _daysInMonth(DateTime d) => DateTime(d.year, d.month + 1, 0).day;

    Widget pill(
        String text, {
          required Color fg,
          required Color bg,
          IconData? icon,
        }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: fg.withOpacity(0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }

    // ------------------ BASE STAT CARD ------------------
    Widget statCard({
      required String title,
      required String value,
      required Color valueColor,
      IconData? icon,
      String? sub,
    }) {
      return Card(
        color: cs.primaryContainer.withOpacity(0.22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: cs.primary.withOpacity(0.10)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: cs.primary),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface.withOpacity(0.72),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: valueColor,
                      ),
                    ),
                    if (sub != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface.withOpacity(0.65),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ NEW: Wide “Change” card (okunabilir, dar alanda bozulmaz)
    Widget changeWideCard({
      required double changePct, // NaN olabilir
    }) {
      final has = !changePct.isNaN;

      final bool isUp = has && changePct > 0;
      final Color c = !has
          ? cs.onSurface.withOpacity(0.75)
          : (isUp ? Colors.red : Colors.green);

      final IconData icon = !has
          ? Icons.compare_arrows
          : (isUp ? Icons.trending_up : Icons.trending_down);

      final String value =
      !has ? "—" : "%${changePct.abs().toStringAsFixed(0)}";

      final String sub = !has
          ? "Geçen ay veri yok"
          : (isUp ? "Geçen aya göre artış" : "Geçen aya göre düşüş");

      return Card(
        color: cs.primaryContainer.withOpacity(0.22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: cs.primary.withOpacity(0.10)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.surfaceVariant.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // title + chip + value aynı satır: asla dikey saçmalamaz
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Gider değişimi",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: cs.onSurface.withOpacity(0.72),
                            ),
                          ),
                        ),
                        if (has) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: c.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: c.withOpacity(0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isUp
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  size: 14,
                                  color: c,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isUp ? "Artış" : "Düşüş",
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: c,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: c,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface.withOpacity(0.65),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget insightCard(List<String> lines) {
      return Card(
        color: cs.primaryContainer.withOpacity(0.22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: cs.primary.withOpacity(0.10)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    "AI Insights",
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...lines.map(
                    (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "• ",
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Expanded(
                        child: Text(
                          t,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface.withOpacity(0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget savingTipCard({
      required String title,
      required String message,
      required String impactText,
      IconData icon = Icons.lightbulb_outline,
    }) {
      return Card(
        color: cs.primaryContainer.withOpacity(0.22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: cs.primary.withOpacity(0.10)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withOpacity(0.88),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.withOpacity(0.18)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.savings,
                        size: 16, color: Colors.green.shade800),
                    const SizedBox(width: 6),
                    Text(
                      impactText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget budgetRiskStrip() {
      final pills = <Widget>[];

      if (globalLimit.enabled && (globalLimit.near || globalLimit.exceeded)) {
        final hasExceeded = globalLimit.exceeded;
        pills.add(
          pill(
            hasExceeded ? "Genel limit aşıldı" : "Genel limite yaklaştın",
            fg: hasExceeded ? cs.error : Colors.orange.shade800,
            bg: hasExceeded
                ? cs.errorContainer.withOpacity(0.45)
                : Colors.orange.withOpacity(0.14),
            icon: hasExceeded ? Icons.error_outline : Icons.warning_amber_outlined,
          ),
        );
      }

      final budgetPills = budgetsAsync.when(
        data: (list) {
          final exceededCount = list.where((b) => (b.progress ?? 0) > 1.0).length;
          final nearCount = list
              .where((b) => (b.progress ?? 0) > 0.8 && (b.progress ?? 0) <= 1.0)
              .length;

          if (exceededCount > 0) {
            return [
              pill(
                "$exceededCount kategoride aşım",
                fg: cs.error,
                bg: cs.errorContainer.withOpacity(0.45),
                icon: Icons.error_outline,
              ),
            ];
          }
          if (nearCount > 0) {
            return [
              pill(
                "$nearCount kategoride risk",
                fg: Colors.orange.shade800,
                bg: Colors.orange.withOpacity(0.14),
                icon: Icons.warning_amber_outlined,
              ),
            ];
          }
          return <Widget>[];
        },
        loading: () => <Widget>[],
        error: (_, __) => <Widget>[],
      );

      pills.addAll(budgetPills);

      if (pills.isEmpty) {
        return pill(
          "Risk yok gibi görünüyor ✅",
          fg: Colors.green.shade800,
          bg: Colors.green.withOpacity(0.12),
          icon: Icons.check_circle_outline,
        );
      }

      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: pills,
      );
    }

    return AppScaffold(
      title: "AI Insights",
      headerHeight: 220,
      surfaceTopSpacing: 120,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: AppHeader(
              title: "AI Insights ✨",
              subtitle: "Bu ayki finans özetin ve akıllı yorumlar",
              onSurface: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: budgetRiskStrip(),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: insightsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Text("Hata: $e"),
              data: (d) {
                final now = DateTime.now();
                final dayOfMonth = now.day;
                final dim = _daysInMonth(now);
                final remaining = (dim - dayOfMonth).clamp(0, 31);

                final income = d.thisMonth.income;
                final expense = d.thisMonth.expense;
                final net = d.thisMonth.net;

                final netColor = net >= 0 ? Colors.green : Colors.red;
                final change = d.expenseChangePct;

                final avgDailyExpense = dayOfMonth <= 0 ? 0.0 : (expense / dayOfMonth);
                final projectedExpense = avgDailyExpense * dim;

                double? savingRate;
                if (income > 0) savingRate = (net / income).clamp(-1.0, 1.0);

                String? topShareText;
                if ((d.topExpenseCategoryName != null) &&
                    (d.topExpenseCategoryAmount != null) &&
                    expense > 0) {
                  final share = (d.topExpenseCategoryAmount! / expense) * 100;
                  topShareText = "Pay: %${share.toStringAsFixed(0)}";
                }

                final extra = <String>[];

                if (expense > 0) {
                  extra.add(
                    "Günlük ortalama giderin ${tr(avgDailyExpense)}. Bu tempoyla ay sonu giderin yaklaşık ${tr(projectedExpense)} olabilir.",
                  );
                }

                if (savingRate != null) {
                  final pct = (savingRate.abs() * 100).toStringAsFixed(0);
                  if (savingRate >= 0) {
                    extra.add("Tasarruf oranı yaklaşık %$pct. Bu iyi bir tempo ✅");
                  } else {
                    extra.add(
                      "Net negatif gidiyorsun (yaklaşık %$pct). Birkaç kategori kısarsan toparlarsın.",
                    );
                  }
                }

                if (remaining > 0) {
                  extra.add(
                    "Ayın bitmesine $remaining gün kaldı. Bu süreyi ‘kontrollü harcama’ modu için iyi kullanabilirsin.",
                  );
                }

                if (!change.isNaN) {
                  if (change >= 30) {
                    extra.add(
                      "Gider artışı yüksek (%${change.toStringAsFixed(0)}). En çok artan 1–2 kalemi yakalayıp frenlemek çok etkili olur.",
                    );
                  } else if (change <= -15) {
                    extra.add(
                      "Giderlerin düşmüş görünüyor. Bu disiplin ay sonu netini güçlendirir 💪",
                    );
                  }
                }

                // ✅ Tasarruf önerisi
                String tipTitle = "Tasarruf önerisi";
                String tipMessage =
                    "Bu ay harcamalarını güzel takip ediyorsun. İstersen 1–2 küçük dokunuşla netini güçlendirebiliriz.";
                String tipImpact = "Hedef: +0 ₺ / ay";

                double estimatedSave = 0;

                if (d.topExpenseCategoryName != null &&
                    d.topExpenseCategoryAmount != null &&
                    d.topExpenseCategoryAmount! > 0) {
                  final catName = d.topExpenseCategoryName!;
                  final catAmount = d.topExpenseCategoryAmount!;
                  const reducePct = 0.12;

                  estimatedSave = catAmount * reducePct;

                  tipMessage =
                  "Bu ay en çok harcama yaptığın kategori $catName (${tr(catAmount)}). "
                      "Bu kalemde yaklaşık %${(reducePct * 100).toStringAsFixed(0)} daha kontrollü gidersen "
                      "ay sonunda netine ciddi katkı olur.";
                  tipImpact = "Tahmini kazanç: +${tr(estimatedSave)} / ay";
                }

                if (!change.isNaN && change >= 30 && expense > 0) {
                  const reducePct = 0.08;
                  estimatedSave = expense * reducePct;

                  tipTitle = "Bu ay frene basma modu";
                  tipMessage =
                  "Geçen aya göre giderlerin artmış (%${change.toStringAsFixed(0)}). "
                      "Bu ay toplam gideri %${(reducePct * 100).toStringAsFixed(0)} azaltmak bile "
                      "ay sonunda netini toparlar. 1–2 kategori seçip (Market, Dışarıda yeme, Abonelik) oradan kısabilirsin.";
                  tipImpact = "Tahmini kazanç: +${tr(estimatedSave)} / ay";
                }

                final allInsights = [
                  ...d.insights,
                  ...extra,
                ];

                return Column(
                  children: [
                    statCard(
                      title: "Bu ay net",
                      value: tr(net),
                      valueColor: netColor,
                      icon: Icons.account_balance_wallet_outlined,
                      sub: income > 0
                          ? "Gelir: ${tr(income)} • Gider: ${tr(expense)}"
                          : null,
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: statCard(
                            title: "Günlük ort. gider",
                            value: expense > 0 ? tr(avgDailyExpense) : "—",
                            valueColor: Colors.red,
                            icon: Icons.speed,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: statCard(
                            title: "Kalan gün",
                            value: "$remaining gün",
                            valueColor: cs.onSurface,
                            icon: Icons.event_available,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: statCard(
                            title: "Ay sonu gider",
                            value: expense > 0 ? tr(projectedExpense) : "—",
                            valueColor: Colors.red,
                            icon: Icons.auto_graph,
                            sub: "Projeksiyon",
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: statCard(
                            title: "Tasarruf oranı",
                            value: savingRate == null
                                ? "—"
                                : "%${(savingRate * 100).toStringAsFixed(0)}",
                            valueColor: savingRate == null
                                ? cs.onSurface
                                : (savingRate >= 0 ? Colors.green : Colors.red),
                            icon: Icons.savings_outlined,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ✅ NEW LAYOUT:
                    // 1) Bu ay gider (küçük)
                    // 2) Gider değişimi (full width, okunaklı)
                    statCard(
                      title: "Bu ay gider",
                      value: tr(expense),
                      valueColor: Colors.red,
                      icon: Icons.trending_down,
                    ),
                    const SizedBox(height: 10),
                    changeWideCard(changePct: change),

                    const SizedBox(height: 10),

                    statCard(
                      title: "En çok harcama",
                      value: d.topExpenseCategoryName == null
                          ? "—"
                          : "${d.topExpenseCategoryName} • ${tr(d.topExpenseCategoryAmount ?? 0)}",
                      valueColor: cs.onSurface,
                      icon: Icons.category_outlined,
                      sub: topShareText,
                    ),

                    const SizedBox(height: 10),

                    statCard(
                      title: "En çok artan kategori",
                      value: d.mostIncreasedCategoryName == null
                          ? "—"
                          : "${d.mostIncreasedCategoryName} • ${tr(d.mostIncreasedDeltaAmount ?? 0)}",
                      valueColor: Colors.red,
                      icon: Icons.trending_up,
                      sub: d.mostIncreasedDeltaPct == null
                          ? "Geçen ay 0'dan geldi"
                          : "≈ %${d.mostIncreasedDeltaPct!.toStringAsFixed(0)} artış",
                    ),

                    const SizedBox(height: 10),

                    savingTipCard(
                      title: tipTitle,
                      message: tipMessage,
                      impactText: tipImpact,
                    ),

                    const SizedBox(height: 10),

                    insightCard(allInsights),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}