// lib/presentation/reports/view/category_spike_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:finansio/presentation/transactions/viewmodel/tx_providers.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/app_header.dart';

class CategorySpikeScreen extends ConsumerWidget {
  const CategorySpikeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final txsAsync = ref.watch(txStreamProvider);

    return AppScaffold(
      title: "Kategori Değişim Analizi",
      headerHeight: 220,
      surfaceTopSpacing: 120,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: AppHeader(
              title: "Kategori Trendleri 📈",
              subtitle: "Harcamalarındaki ani artış ve azalışlar",
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
                if (allTxs.isEmpty) {
                  return const Center(child: Text("Henüz analiz edilecek işlem yok."));
                }

                // Bu ay ve geçen ay harcamalarını kategorilere göre ayıralım
                final now = DateTime.now();
                final thisMonth = now.month;
                final lastMonth = thisMonth == 1 ? 12 : thisMonth - 1;

                final thisMonthTotals = <String, double>{};
                final lastMonthTotals = <String, double>{};

                for (final t in allTxs) {
                  if (t.amount < 0) {
                    final absVal = t.amount.abs();
                    if (t.date.month == thisMonth) {
                      thisMonthTotals[t.category.name] = (thisMonthTotals[t.category.name] ?? 0) + absVal;
                    } else if (t.date.month == lastMonth) {
                      lastMonthTotals[t.category.name] = (lastMonthTotals[t.category.name] ?? 0) + absVal;
                    }
                  }
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.purple.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.swap_vert, color: Colors.purple, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Bu analiz, bu ayki harcamalarını geçen ayın aynı dönemiyle kıyaslayarak değişimleri gösterir.",
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Kategori Kıyaslaması",
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    ...thisMonthTotals.entries.map((entry) {
                      final catName = entry.key;
                      final currentVal = entry.value;
                      final prevVal = lastMonthTotals[catName] ?? 0.0;

                      double percentChange = 0;
                      if (prevVal > 0) {
                        percentChange = ((currentVal - prevVal) / prevVal) * 100;
                      } else if (currentVal > 0) {
                        percentChange = 100; // Geçen ay hiç yokken bu ay harcanmışsa
                      }

                      final isIncrease = percentChange >= 0;

                      return Card(
                        color: cs.primaryContainer.withOpacity(0.22),
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: cs.primary.withOpacity(0.10)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(catName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Geçen ay: ${currency.format(prevVal)}",
                                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.6)),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currency.format(currentVal),
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (isIncrease ? Colors.red : Colors.green).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "${isIncrease ? '+' : ''}${percentChange.toStringAsFixed(1)}%",
                                      style: TextStyle(
                                        color: isIncrease ? Colors.red : Colors.green,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
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