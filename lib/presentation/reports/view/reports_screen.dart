// lib/screens/reports_screen.dart
import 'package:finansio/presentation/transactions/view/filtered_tx_list_screen.dart';
import 'package:finansio/presentation/reports/view/risk_details_screen.dart';
import 'package:finansio/presentation/reports/viewmodel/risk_providers.dart';
import 'package:finansio/domain/engine/risk_score.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:finansio/domain/models/summary.dart';

import 'package:finansio/presentation/transactions/viewmodel/tx_providers.dart';
import 'package:finansio/presentation/reports/viewmodel/reports.dart';

import '../../../data/database/app_database.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/app_header.dart';

// ✅ PDF ve Bildirim Servisleri dahil edildi
import 'package:finansio/data/services/pdf_export_service.dart';
import 'package:finansio/data/services/notification_service.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pieAsync = ref.watch(categoryPieProvider);
    final trendAsync = ref.watch(monthlyTrendProvider);
    final summaryAsync = ref.watch(reportsSummaryProvider);

    final txsAsync = ref.watch(txStreamProvider);
    final filter = ref.watch(txFilterProvider);

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    String filterLabel(FilterRange f) {
      switch (f) {
        case FilterRange.all:
          return 'Tümü';
        case FilterRange.thisMonth:
          return 'Bu Ay';
        case FilterRange.lastMonth:
          return 'Geçen Ay';
      }
    }

    return AppScaffold(
      title: "Raporlar",
      surfaceTopSpacing: 130,
      headerHeight: 240,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: AppHeader(
              title: "Raporlar 📊",
              subtitle: "Filtre: ${filterLabel(filter)}",
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. İNDİR BUTONU
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () async {
                        final currentFilter = filterLabel(filter);
                        final transactions = txsAsync.value ?? [];

                        if (transactions.isNotEmpty) {
                          double totalIncome = 0;
                          double totalExpense = 0;
                          for (final tx in transactions) {
                            if (tx.amount >= 0) {
                              totalIncome += tx.amount;
                            } else {
                              totalExpense += tx.amount;
                            }
                          }

                          final filePath = await PdfExportService.downloadMonthlyReport(
                            monthName: currentFilter,
                            summary: Summary(
                                income: totalIncome,
                                expense: totalExpense,
                                net: totalIncome + totalExpense
                            ),
                            transactions: transactions,
                          );

                          if (filePath != null) {
                            await NotificationService.showDownloadNotification(filePath);
                          }
                        }
                      },
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white.withOpacity(0.25),
                        child: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 2. PAYLAŞ BUTONU
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () async {
                        final currentFilter = filterLabel(filter);
                        final transactions = txsAsync.value ?? [];

                        if (transactions.isNotEmpty) {
                          double totalIncome = 0;
                          double totalExpense = 0;
                          for (final tx in transactions) {
                            if (tx.amount >= 0) {
                              totalIncome += tx.amount;
                            } else {
                              totalExpense += tx.amount;
                            }
                          }

                          await PdfExportService.generateAndShareMonthlyReport(
                            monthName: currentFilter,
                            summary: Summary(
                                income: totalIncome,
                                expense: totalExpense,
                                net: totalIncome + totalExpense
                            ),
                            transactions: transactions,
                          );
                        }
                      },
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white.withOpacity(0.25),
                        child: const Icon(Icons.ios_share_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Filter row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _FilterRow(
                current: filter,
                onChanged: (f) => ref.read(txFilterProvider.notifier).state = f,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Risk Kartı
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: const _RiskPremiumCard(),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: summaryAsync.when(
                  data: (s) {
                    return Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            title: 'Gelir',
                            value: s.income,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatTile(
                            title: 'Gider',
                            value: s.expense,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatTile(
                            title: 'Net',
                            value: s.net,
                            color: s.net >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const SizedBox(
                    height: 52,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, st) => Text(
                    "Hata: $e",
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Pie + Compare
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kategori Dağılımı (Gider)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    pieAsync.when(
                      data: (list) {
                        if (list.isEmpty) {
                          return const _EmptyBox("Gösterilecek veri yok.");
                        }
                        return Column(
                          children: [
                            _CategoryPie(list: list),
                            const SizedBox(height: 16),
                            _CategoryCompareSection(list: list),
                          ],
                        );
                      },
                      loading: () => const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, st) => Text(
                        "Hata: $e",
                        style:
                        theme.textTheme.bodySmall?.copyWith(color: cs.error),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Trend charts (Akıllı Kontrollü)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Aylık Trend (Son 6 Ay)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Row(
                          children: [
                            const _LegendDot(color: Colors.green, label: "Gelir"),
                            const SizedBox(width: 8),
                            const _LegendDot(color: Colors.red, label: "Gider"),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    trendAsync.when(
                      data: (list) {
                        final activeList = list.where((m) => m.income > 0 || m.expense.abs() > 0).toList();

                        // Eğer 1 veya daha az ay verisi varsa sıkışma olmasın diye şık bir bilgi kutusu gösterelim
                        if (activeList.length < 2) {
                          return const _EmptyBox("Aylık trend grafiği için en az 2 aylık veri gerekiyor.");
                        }

                        return Column(
                          children: [
                            const SizedBox(height: 8),
                            _MonthlyLines(list: activeList),
                          ],
                        );
                      },
                      loading: () => const SizedBox(
                        height: 220,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, st) => Text(
                        "Hata: $e",
                        style:
                        theme.textTheme.bodySmall?.copyWith(color: cs.error),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Insight
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: _InsightFromData(
                  pieAsync: pieAsync,
                  summaryAsync: summaryAsync,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Küçük Lejant Noktası
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ---------------- PREMIUM RISK CARD ----------------
class _RiskPremiumCard extends ConsumerWidget {
  const _RiskPremiumCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final async = ref.watch(monthlyRiskProvider);

    Color levelColor(RiskLevel level) {
      switch (level) {
        case RiskLevel.high:
          return cs.error;
        case RiskLevel.medium:
          return Colors.orange.shade800;
        case RiskLevel.low:
          return Colors.green;
      }
    }

    IconData levelIcon(RiskLevel level) {
      switch (level) {
        case RiskLevel.high:
          return Icons.warning_amber_rounded;
        case RiskLevel.medium:
          return Icons.info_outline;
        case RiskLevel.low:
          return Icons.verified_outlined;
      }
    }

    String levelLabel(RiskLevel level) {
      switch (level) {
        case RiskLevel.high:
          return "Yüksek";
        case RiskLevel.medium:
          return "Orta";
        case RiskLevel.low:
          return "Düşük";
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RiskDetailsScreen()),
        );
      },
      child: async.when(
        loading: () => Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              "Risk analizi hazırlanıyor…",
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        error: (e, st) => Text(
          "Risk hesaplanamadı.",
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.error,
          ),
        ),
        data: (r) {
          final c = levelColor(r.level);
          final icon = levelIcon(r.level);
          final progress = (r.score / 100.0).clamp(0.0, 1.0);

          final insight =
          r.reasons.isNotEmpty ? r.reasons.first : "Bu ay risk verisi kısıtlı.";

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.withOpacity(0.20)),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: c),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Risk Durumu",
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          insight,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withOpacity(0.65),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: c.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: c.withOpacity(0.22)),
                    ),
                    child: Text(
                      "Risk: ${levelLabel(r.level)} • ${r.score}/100",
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: c,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 10),
              if (r.reasons.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: r.reasons.take(3).map((s) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: cs.surfaceVariant.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: cs.outlineVariant.withOpacity(0.25)),
                      ),
                      child: Text(
                        s,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface.withOpacity(0.78),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    "Detayı gör",
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right, size: 18, color: cs.primary),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------- FILTER ROW ----------------
class _FilterRow extends StatelessWidget {
  final FilterRange current;
  final ValueChanged<FilterRange> onChanged;

  const _FilterRow({
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget chip(String label, FilterRange value) {
      final selected = current == value;
      return ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? cs.onPrimary : cs.primary,
          ),
        ),
        selected: selected,
        selectedColor: cs.primary.withOpacity(0.92),
        backgroundColor: cs.surfaceVariant.withOpacity(0.35),
        onSelected: (_) => onChanged(value),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        side: BorderSide(
          color: selected
              ? cs.primary.withOpacity(0.25)
              : cs.outlineVariant.withOpacity(0.35),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      children: [
        chip('Bu Ay', FilterRange.thisMonth),
        chip('Geçen Ay', FilterRange.lastMonth),
        chip('Tümü', FilterRange.all),
      ],
    );
  }
}

// ---------------- SUMMARY TILE ----------------
class _StatTile extends StatelessWidget {
  final String title;
  final double value;
  final Color color;

  const _StatTile({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface.withOpacity(0.65),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            currency.format(value),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- PIE CHART ----------------
class _CategoryPie extends StatefulWidget {
  final List<CategoryTotal> list;
  const _CategoryPie({required this.list});

  @override
  State<_CategoryPie> createState() => _CategoryPieState();
}

class _CategoryPieState extends State<_CategoryPie> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final list = widget.list;
    final total = list.fold<double>(0, (a, b) => a + b.total);

    if (total <= 0) return const _EmptyBox('Gösterilecek veri yok.');

    final cs = Theme.of(context).colorScheme;
    final currency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    final sections = List.generate(list.length, (i) {
      final ct = list[i];
      final isTouched = _touchedIndex == i;

      final percent = (ct.total / total * 100.0);
      return PieChartSectionData(
        value: ct.total,
        title: '${percent.toStringAsFixed(0)}%',
        radius: isTouched ? 74 : 62,
        titleStyle: TextStyle(
          fontSize: isTouched ? 13 : 12,
          fontWeight: FontWeight.w900,
          color: cs.onSurface,
        ),
        color: _hexToColor(ct.category.colorHex),
        badgeWidget: isTouched
            ? Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: cs.inverseSurface,
            borderRadius: BorderRadius.circular(999),
            border:
            Border.all(color: cs.outlineVariant.withOpacity(0.25)),
          ),
          child: Text(
            currency.format(ct.total),
            style: TextStyle(
              color: cs.onInverseSurface,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        )
            : null,
        badgePositionPercentageOffset: 1.15,
      );
    });

    final bool hasValidTouched = _touchedIndex != null &&
        _touchedIndex! >= 0 &&
        _touchedIndex! < list.length;

    final centerTitle =
    hasValidTouched ? list[_touchedIndex!].category.name : "Toplam Gider";
    final centerValue = hasValidTouched
        ? currency.format(list[_touchedIndex!].total)
        : currency.format(total);

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 38,
                  startDegreeOffset: -90,
                  borderData: FlBorderData(show: false),
                  pieTouchData: PieTouchData(
                    enabled: true,
                    touchCallback: (event, response) {
                      final touched = response?.touchedSection;
                      final idx = touched?.touchedSectionIndex;

                      if (!event.isInterestedForInteractions ||
                          idx == null ||
                          idx < 0 ||
                          idx >= list.length) {
                        if (_touchedIndex != null) {
                          setState(() => _touchedIndex = null);
                        }
                        return;
                      }

                      if (_touchedIndex != idx) {
                        setState(() => _touchedIndex = idx);
                      }

                      if (event is FlTapUpEvent) {
                        final ct = list[idx];
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FilteredTxListScreen(
                              title: ct.category.name,
                              categoryId: ct.category.id,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    centerValue,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: list.take(8).map((ct) {
            return _LegendItem(
              color: _hexToColor(ct.category.colorHex),
              label: '${ct.category.name} • ${currency.format(ct.total)}',
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: cs.onSurface.withOpacity(0.85),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ---------------- CATEGORY COMPARE ----------------
class _CategoryCompareSection extends StatefulWidget {
  final List<CategoryTotal> list;
  const _CategoryCompareSection({required this.list});

  @override
  State<_CategoryCompareSection> createState() =>
      _CategoryCompareSectionState();
}

class _CategoryCompareSectionState extends State<_CategoryCompareSection> {
  late Set<int> _selectedIds;

  @override
  void initState() {
    super.initState();
    final firstThree = widget.list.take(3).map((e) => e.category.id).toSet();
    _selectedIds = firstThree.isNotEmpty
        ? firstThree
        : widget.list.map((e) => e.category.id).toSet();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.list.isEmpty) return const SizedBox.shrink();

    final total = widget.list.fold<double>(0, (a, b) => a + b.total.abs());
    if (total <= 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    final visible = widget.list.take(widget.list.length.clamp(0, 8)).toList();
    final selectedList =
    visible.where((ct) => _selectedIds.contains(ct.category.id)).toList();

    final finalSelected =
    selectedList.isEmpty && visible.isNotEmpty ? [visible.first] : selectedList;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Kategorileri karşılaştır",
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: visible.map((ct) {
            final isSel = _selectedIds.contains(ct.category.id);
            final color = _hexToColor(ct.category.colorHex);
            return FilterChip(
              label: Text(
                ct.category.name,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isSel ? cs.onPrimary : cs.onSurface,
                ),
              ),
              selected: isSel,
              backgroundColor: cs.surfaceVariant.withOpacity(0.35),
              selectedColor: color.withOpacity(0.85),
              onSelected: (_) {
                setState(() {
                  if (isSel && _selectedIds.length > 1) {
                    _selectedIds.remove(ct.category.id);
                  } else if (!isSel) {
                    _selectedIds.add(ct.category.id);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              barGroups: List.generate(finalSelected.length, (i) {
                final ct = finalSelected[i];
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: ct.total.abs(),
                      width: 22,
                      borderRadius: BorderRadius.circular(6),
                      color: _hexToColor(ct.category.colorHex),
                    ),
                  ],
                );
              }),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      final text = value >= 1000
                          ? '${(value / 1000).toStringAsFixed(1)}k'
                          : value.toStringAsFixed(0);
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          text,
                          style: TextStyle(
                            fontSize: 10,
                            color: cs.onSurface.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= finalSelected.length) {
                        return const SizedBox.shrink();
                      }
                      final name = finalSelected[idx].category.name;
                      final shortName = name.length > 8 ? '${name.substring(0, 6)}..' : name;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          shortName,
                          style: TextStyle(
                            fontSize: 10,
                            color: cs.onSurface.withOpacity(0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => cs.inverseSurface,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final ct = finalSelected[group.x.toInt()];
                    final percent =
                    (ct.total.abs() / total * 100).toStringAsFixed(0);
                    return BarTooltipItem(
                      '${ct.category.name}\n${currency.format(ct.total.abs())} • %$percent',
                      TextStyle(color: cs.onInverseSurface),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------- MONTHLY LINES (AKILLI KONTROLLÜ) ----------------
class _MonthlyLines extends StatelessWidget {
  final List<MonthlyTotals> list;
  const _MonthlyLines({required this.list});

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) return const _EmptyBox('Gösterilecek veri yok.');

    final fmt = DateFormat('MM/yy');

    final incomeSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];

    for (int i = 0; i < list.length; i++) {
      final m = list[i];
      incomeSpots.add(FlSpot(i.toDouble(), m.income));
      expenseSpots.add(FlSpot(i.toDouble(), m.expense.abs()));
    }

    final allY = [
      ...incomeSpots.map((e) => e.y),
      ...expenseSpots.map((e) => e.y)
    ];
    final maxY = allY.fold<double>(0, (p, y) => y > p ? y : p);

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (list.length - 1).toDouble().clamp(0, double.infinity),
          minY: 0,
          maxY: maxY == 0 ? 1 : maxY * 1.2,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY == 0 ? 1 : maxY / 4,
            getDrawingHorizontalLine: (_) => FlLine(color: Colors.white10, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= list.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      fmt.format(list[idx].month),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.75),
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: incomeSpots,
              isCurved: true,
              color: Colors.green,
              barWidth: 3.5,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.green.withOpacity(0.1),
              ),
            ),
            LineChartBarData(
              spots: expenseSpots,
              isCurved: true,
              color: Colors.redAccent,
              barWidth: 3.5,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.redAccent.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- INSIGHT ----------------
class _InsightFromData extends StatelessWidget {
  final AsyncValue<List<CategoryTotal>> pieAsync;
  final AsyncValue<SummaryTotals> summaryAsync;

  const _InsightFromData({
    required this.pieAsync,
    required this.summaryAsync,
  });

  @override
  Widget build(BuildContext context) {
    if (!pieAsync.hasValue || !summaryAsync.hasValue) {
      return const SizedBox.shrink();
    }

    final pieList = pieAsync.value ?? [];
    final s = summaryAsync.value!;
    if (pieList.isEmpty) return const SizedBox.shrink();

    final totalExpense = pieList.fold<double>(0, (a, b) => a + b.total);
    if (totalExpense <= 0) return const SizedBox.shrink();

    final top = pieList.reduce((a, b) => a.total >= b.total ? a : b);
    final topPercent = (top.total / totalExpense) * 100;

    final buf = StringBuffer();
    if (s.net < 0) {
      buf.write(
        'Bu dönemde giderlerin gelirlerinden ${s.net.abs().toStringAsFixed(0)} ₺ fazla. ',
      );
    } else if (s.net > 0) {
      buf.write('Bu dönemde ${s.net.toStringAsFixed(0)} ₺ fazla verin var. ',);
    }
    buf.write(
      '${top.category.name}, giderlerinin %${topPercent.toStringAsFixed(0)} ile en büyük payı oluşturuyor.',
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.insights_outlined,
            color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            buf.toString(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final String msg;
  const _EmptyBox(this.msg);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 100,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
      ),
      child: Text(
        msg,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: cs.onSurface.withOpacity(0.7),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

Color _hexToColor(String hex) {
  final v = hex.replaceAll('#', '');
  final colorInt = int.parse(v, radix: 16) | 0xFF000000;
  return Color(colorInt);
}