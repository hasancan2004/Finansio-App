// lib/presentation/reports/view/ai_insights_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../viewmodel/ai_insights_provider.dart';
import '../../budgets/viewmodel/budget_providers.dart';
import '../../transactions/viewmodel/tx_providers.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/theme/app_surfaces.dart';

class AIInsightsScreen extends ConsumerWidget {
  const AIInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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

    // ---------------- YENİ GRUPLANDIRILMIŞ TASARIM BİLEŞENLERİ ----------------

    // 1. ANA ÖZET (HERO) KARTI
    Widget _buildHeroSummary({
      required double net,
      required double income,
      required double expense,
      required double changePct,
    }) {
      final netColor = net >= 0 ? Colors.green : cs.error;
      final hasChange = !changePct.isNaN;
      final isUp = hasChange && changePct > 0;
      final changeColor = !hasChange ? cs.onSurface.withOpacity(0.5) : (isUp ? cs.error : Colors.green);

      return Card(
        color: AppSurfaces.cardFill(cs),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: cs.primary.withOpacity(0.15)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                "Bu Ay Net Durum",
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(net),
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: netColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Icon(Icons.arrow_downward_rounded, color: Colors.green, size: 20),
                        const SizedBox(height: 4),
                        Text("Gelir", style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.6))),
                        Text(tr(income), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 40, color: cs.onSurface.withOpacity(0.1)),
                  Expanded(
                    child: Column(
                      children: [
                        Icon(Icons.arrow_upward_rounded, color: cs.error, size: 20),
                        const SizedBox(height: 4),
                        Text("Gider", style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.6))),
                        Text(tr(expense), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
              if (hasChange) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: changeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isUp ? Icons.trending_up : Icons.trending_down, size: 16, color: changeColor),
                      const SizedBox(width: 6),
                      Text(
                        "Geçen aya göre %${changePct.abs().toStringAsFixed(0)} ${isUp ? 'artış' : 'düşüş'}",
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: changeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ]
            ],
          ),
        ),
      );
    }

    // Alt Metrik Hücresi (Grid için)
    Widget _buildMetricCell(String title, String value, Color valColor, IconData icon) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: cs.primary.withOpacity(0.7)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: valColor,
              ),
            ),
          ],
        ),
      );
    }

    // 2. GİDİŞAT KARTI (2x2 Metrikler)
    Widget _buildMetricsGrid({
      required double avgDaily,
      required double projected,
      required int remainingDays,
      required double? savingRate,
      required double expense,
    }) {
      return Card(
        color: cs.primaryContainer.withOpacity(0.12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: cs.primary.withOpacity(0.10)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  _buildMetricCell("Günlük Ort.", expense > 0 ? tr(avgDaily) : "—", cs.error, Icons.speed),
                  Container(width: 1, height: 40, color: cs.onSurface.withOpacity(0.1), margin: const EdgeInsets.symmetric(horizontal: 12)),
                  _buildMetricCell("Kalan Gün", "$remainingDays gün", cs.onSurface, Icons.event_available),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, thickness: 1),
              ),
              Row(
                children: [
                  _buildMetricCell("Projeksiyon", expense > 0 ? tr(projected) : "—", cs.error, Icons.auto_graph),
                  Container(width: 1, height: 40, color: cs.onSurface.withOpacity(0.1), margin: const EdgeInsets.symmetric(horizontal: 12)),
                  _buildMetricCell(
                    "Tasarruf Oranı",
                    savingRate == null ? "—" : "%${(savingRate * 100).toStringAsFixed(0)}",
                    savingRate == null ? cs.onSurface : (savingRate >= 0 ? Colors.green : cs.error),
                    Icons.savings_outlined,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Kategori Satırı (Liste içi)
    Widget _buildCategoryRow(String title, String? catName, double? amount, IconData icon, Color color, String subText) {
      return Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.6), fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  catName == null ? "—" : "$catName • ${tr(amount ?? 0)}",
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: cs.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (catName != null)
            Text(subText, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800, color: color)),
        ],
      );
    }

    // 3. KATEGORİ ANALİZİ KARTI
    Widget _buildCategoryAnalysis(AiInsightsData d, double expense, String? topShareText) {
      return Card(
        color: cs.primaryContainer.withOpacity(0.12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: cs.primary.withOpacity(0.10)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildCategoryRow(
                "En Çok Harcanan",
                d.topExpenseCategoryName,
                d.topExpenseCategoryAmount,
                Icons.category_outlined,
                cs.primary,
                topShareText ?? "",
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, thickness: 1),
              ),
              _buildCategoryRow(
                "En Çok Artan (Geçen Aya Göre)",
                d.mostIncreasedCategoryName,
                d.mostIncreasedDeltaAmount,
                Icons.trending_up,
                cs.error,
                d.mostIncreasedDeltaPct == null ? "Yeni" : "+%${d.mostIncreasedDeltaPct!.toStringAsFixed(0)}",
              ),
            ],
          ),
        ),
      );
    }

    // 4. TASARRUF ÖNERİSİ KARTI
    Widget savingTipCard({required String title, required String message, required String impactText}) {
      return Card(
        color: cs.tertiaryContainer.withOpacity(0.3),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: cs.tertiary.withOpacity(0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: cs.tertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: cs.onTertiaryContainer)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4, fontWeight: FontWeight.w600, color: cs.onSurface.withOpacity(0.85)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.savings, size: 16, color: Colors.green.shade800),
                    const SizedBox(width: 6),
                    Text(impactText, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: Colors.green.shade800)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 5. YZ BİLDİRİMLERİ KARTI
    Widget insightCard(List<String> lines) {
      return Card(
        color: cs.primaryContainer.withOpacity(0.12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: cs.primary.withOpacity(0.10)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: cs.primary),
                  const SizedBox(width: 8),
                  Text("Akıllı Yorumlar", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 12),
              ...lines.map(
                    (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("• ", style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900, color: cs.primary)),
                      Expanded(
                        child: Text(
                          t,
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.35, fontWeight: FontWeight.w600, color: cs.onSurface.withOpacity(0.85)),
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
          const SizedBox(height: 16),
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
                final change = d.expenseChangePct;

                final avgDailyExpense = dayOfMonth <= 0 ? 0.0 : (expense / dayOfMonth);
                final projectedExpense = avgDailyExpense * dim;

                double? savingRate;
                if (income > 0) savingRate = (net / income).clamp(-1.0, 1.0);

                String? topShareText;
                if ((d.topExpenseCategoryName != null) && (d.topExpenseCategoryAmount != null) && expense > 0) {
                  final share = (d.topExpenseCategoryAmount! / expense) * 100;
                  topShareText = "%${share.toStringAsFixed(0)}";
                }

                final extra = <String>[];
                if (expense > 0) {
                  extra.add("Günlük ortalama giderin ${tr(avgDailyExpense)}. Bu tempoyla ay sonu giderin yaklaşık ${tr(projectedExpense)} olabilir.");
                }
                if (savingRate != null) {
                  final pct = (savingRate.abs() * 100).toStringAsFixed(0);
                  if (savingRate >= 0) {
                    extra.add("Tasarruf oranı yaklaşık %$pct. Bu iyi bir tempo ✅");
                  } else {
                    extra.add("Net negatif gidiyorsun (yaklaşık %$pct). Birkaç kategori kısarsan toparlarsın.");
                  }
                }
                if (remaining > 0) {
                  extra.add("Ayın bitmesine $remaining gün kaldı. Bu süreyi ‘kontrollü harcama’ modu için iyi kullanabilirsin.");
                }
                if (!change.isNaN) {
                  if (change >= 30) {
                    extra.add("Gider artışı yüksek (%${change.toStringAsFixed(0)}). En çok artan 1–2 kalemi yakalayıp frenlemek çok etkili olur.");
                  } else if (change <= -15) {
                    extra.add("Giderlerin düşmüş görünüyor. Bu disiplin ay sonu netini güçlendirir 💪");
                  }
                }

                String tipTitle = "Tasarruf önerisi";
                String tipMessage = "Bu ay harcamalarını güzel takip ediyorsun. İstersen 1–2 küçük dokunuşla netini güçlendirebiliriz.";
                String tipImpact = "Hedef: +0 ₺ / ay";
                double estimatedSave = 0;

                if (d.topExpenseCategoryName != null && d.topExpenseCategoryAmount != null && d.topExpenseCategoryAmount! > 0) {
                  final catName = d.topExpenseCategoryName!;
                  final catAmount = d.topExpenseCategoryAmount!;
                  const reducePct = 0.12;
                  estimatedSave = catAmount * reducePct;
                  tipMessage = "Bu ay en çok harcama yaptığın kategori $catName (${tr(catAmount)}). Bu kalemde yaklaşık %${(reducePct * 100).toStringAsFixed(0)} daha kontrollü gidersen ay sonunda netine ciddi katkı olur.";
                  tipImpact = "Tahmini kazanç: +${tr(estimatedSave)} / ay";
                }

                if (!change.isNaN && change >= 30 && expense > 0) {
                  const reducePct = 0.08;
                  estimatedSave = expense * reducePct;
                  tipTitle = "Bu ay frene basma modu";
                  tipMessage = "Geçen aya göre giderlerin artmış (%${change.toStringAsFixed(0)}). Bu ay toplam gideri %${(reducePct * 100).toStringAsFixed(0)} azaltmak bile ay sonunda netini toparlar. 1–2 kategori seçip oradan kısabilirsin.";
                  tipImpact = "Tahmini kazanç: +${tr(estimatedSave)} / ay";
                }

                final allInsights = [...d.insights, ...extra];

                return Column(
                  children: [
                    _buildHeroSummary(net: net, income: income, expense: expense, changePct: change),
                    const SizedBox(height: 12),
                    _buildMetricsGrid(avgDaily: avgDailyExpense, projected: projectedExpense, remainingDays: remaining, savingRate: savingRate, expense: expense),
                    const SizedBox(height: 12),
                    _buildCategoryAnalysis(d, expense, topShareText),
                    const SizedBox(height: 12),
                    savingTipCard(title: tipTitle, message: tipMessage, impactText: tipImpact),
                    const SizedBox(height: 12),
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