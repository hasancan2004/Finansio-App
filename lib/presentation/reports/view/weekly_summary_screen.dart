// lib/presentation/reports/view/weekly_summary_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:finansio/data/database/app_database.dart';
import 'package:finansio/presentation/transactions/viewmodel/tx_providers.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/theme/app_surfaces.dart';

class WeeklySummaryScreen extends ConsumerWidget {
  const WeeklySummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    // Tüm işlemleri dinle
    final txsAsync = ref.watch(txStreamProvider);

    return AppScaffold(
      title: "Haftalık Özet",
      headerHeight: 220,
      surfaceTopSpacing: 120,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: AppHeader(
              title: "Haftalık Özetin 📊",
              subtitle: "Geçen haftanın finansal analizi",
              trailing: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
              onSurface: true,
            ),
          ),
          Expanded(
            child: txsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Hata: $e')),
              data: (allTxs) {
                // Son 7 günü filtrele
                final now = DateTime.now();
                final sevenDaysAgo = now.subtract(const Duration(days: 7));
                final weeklyTxs = allTxs.where((t) => t.date.isAfter(sevenDaysAgo)).toList();

                if (weeklyTxs.isEmpty) {
                  return const Center(child: Text("Bu hafta hiç harcama yapmamışsın!"));
                }

                double income = 0;
                double expense = 0;
                final categoryTotals = <String, double>{};
                final expenseTxs = <Tx>[];

                for (final t in weeklyTxs) {
                  if (t.amount >= 0) {
                    income += t.amount;
                  } else {
                    expense += t.amount.abs();
                    categoryTotals[t.category.name] = (categoryTotals[t.category.name] ?? 0) + t.amount.abs();
                    expenseTxs.add(t);
                  }
                }

                final net = income - expense;

                // Kategorileri büyükten küçüğe sırala
                final sortedCats = categoryTotals.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));

                // En büyük 3 harcamayı bul
                expenseTxs.sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));
                final topTxs = expenseTxs.take(3).toList();

                // Dinamik İçgörü Mesajı
                String insightMessage = "Sakin bir hafta geçirmişsin.";
                if (expense > income && income > 0) {
                  insightMessage = "Bu hafta gelirinden fazlasını harcadın. Gelecek hafta fren yapmalıyız!";
                } else if (sortedCats.isNotEmpty) {
                  final topCat = sortedCats.first;
                  if (topCat.value > expense * 0.4) {
                    insightMessage = "Bütçenin neredeyse yarısı ${topCat.key} kategorisine gitmiş! 💸";
                  } else if (net > 0) {
                    insightMessage = "Harika! Bu haftayı kârda kapattın, birikime devam. 🚀";
                  }
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    // Yapay Zeka / Analiz Kartı
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: net >= 0 ? Colors.green.withOpacity(0.15) : cs.errorContainer.withOpacity(0.40),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: net >= 0 ? Colors.green.withOpacity(0.3) : cs.error.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(net >= 0 ? Icons.auto_awesome : Icons.warning_amber_rounded,
                              color: net >= 0 ? Colors.green : cs.error, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              insightMessage,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Özet Kartları
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            title: "Gelir",
                            amount: currency.format(income),
                            color: Colors.green,
                            icon: Icons.arrow_downward_rounded,
                            cs: cs,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            title: "Gider",
                            amount: currency.format(expense),
                            color: Colors.red,
                            icon: Icons.arrow_upward_rounded,
                            cs: cs,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SummaryCard(
                      title: "Net Durum",
                      amount: currency.format(net),
                      color: net >= 0 ? Colors.green : Colors.red,
                      icon: Icons.account_balance_wallet_outlined,
                      cs: cs,
                      isFullWidth: true,
                    ),
                    const SizedBox(height: 24),

                    // Kategori Dağılımı (Sadece harcama varsa)
                    if (sortedCats.isNotEmpty) ...[
                      Text(
                        "Harcama Dağılımı",
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.surfaceVariant.withOpacity(0.30),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
                        ),
                        child: Column(
                          children: sortedCats.map((cat) {
                            final percent = (cat.value / expense).clamp(0.0, 1.0);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(cat.key, style: const TextStyle(fontWeight: FontWeight.w800)),
                                      Text(currency.format(cat.value), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.red)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      value: percent,
                                      minHeight: 6,
                                      color: Colors.orange.shade800,
                                      backgroundColor: cs.surfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // En Büyük Harcamalar
                    if (topTxs.isNotEmpty) ...[
                      Text(
                        "En Büyük Harcamalar",
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 12),
                      ...topTxs.map((t) => Card(
                        color: AppSurfaces.cardFill(cs),
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: cs.primary.withOpacity(0.10)),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: cs.errorContainer,
                            child: Icon(Icons.money_off, color: cs.error, size: 18),
                          ),
                          title: Text(t.category.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: Text(t.note ?? "Not yok", maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Text(currency.format(t.amount.abs()), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w900)),
                        ),
                      )).toList(),
                    ]
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

class _SummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;
  final IconData icon;
  final ColorScheme cs;
  final bool isFullWidth;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
    required this.cs,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppSurfaces.cardFill(cs),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: isFullWidth ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isFullWidth ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            amount,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}