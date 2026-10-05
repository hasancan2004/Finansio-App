import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../viewmodel/debts_provider.dart';
import 'add_debt_screen.dart';

class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  String _formatTry(double amount) {
    final f = NumberFormat("#,##0", "tr_TR");
    return '${f.format(amount)} ₺';
  }

  void _confirmSettle(BuildContext context, WidgetRef ref, int debtId, String personName, bool isOwedToMe) {
    final typeText = isOwedToMe ? 'Alacak tahsil edildi' : 'Borç ödendi';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isOwedToMe ? 'Tahsilatı Onayla' : 'Ödemeyi Onayla'),
        content: Text('"$personName" adlı kişiye ait bu kaydı $typeText olarak işaretlemek ve ana bakiyene yansıtmak istiyor musun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(debtsControllerProvider).settleDebt(debtId);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İşlem başarıyla kapatıldı ve bakiyene yansıtıldı.')));
            },
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int debtId, String personName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kaydı Sil'),
        content: Text('"$personName" kaydını tamamen silmek istiyor musun?\n\nBu işlem ana bakiyeni etkilemez, sadece kaydı siler.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              ref.read(debtsControllerProvider).deleteDebt(debtId);
              Navigator.pop(ctx);
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(debtsStreamProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Borç ve Alacaklar', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: debtsAsync.when(
        data: (debts) {
          if (debts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.handshake_outlined, size: 80, color: cs.primary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('Defter Tertemiz!', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Kimseye borcun yok, kimseden alacağın yok.\nHarika gidiyorsun.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            );
          }

          // Kapatılmamış olanları üste, kapatılmışları alta sıralayalım
          final sortedDebts = [...debts];
          sortedDebts.sort((a, b) {
            if (a.isSettled == b.isSettled) return b.createdAt.compareTo(a.createdAt);
            return a.isSettled ? 1 : -1;
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedDebts.length,
            itemBuilder: (context, index) {
              final debt = sortedDebts[index];
              final isPositive = debt.isOwedToMe; // Alacaklıysak yeşil, borçluysak kırmızı
              final mainColor = isPositive ? Colors.green : Colors.red;
              final accentColor = isDark ? mainColor.shade400 : mainColor.shade600;

              return Opacity(
                opacity: debt.isSettled ? 0.6 : 1.0,
                child: Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: debt.isSettled ? cs.outlineVariant : accentColor.withOpacity(0.4)),
                  ),
                  color: cs.surfaceContainerHighest.withOpacity(0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: debt.isSettled ? cs.surfaceContainer : accentColor.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                                color: debt.isSettled ? cs.onSurfaceVariant : accentColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    debt.personName,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        decoration: debt.isSettled ? TextDecoration.lineThrough : null
                                    ),
                                  ),
                                  Text(
                                    isPositive ? 'Ondan alacağın var' : 'Ona borcun var',
                                    style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _formatTry(debt.amount),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: debt.isSettled ? cs.onSurfaceVariant : accentColor,
                              ),
                            ),
                          ],
                        ),
                        if (debt.dueDate != null && !debt.isSettled) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 14, color: cs.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Text(
                                'Vade: ${DateFormat('dd.MM.yyyy').format(debt.dueDate!)}',
                                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                              ),
                            ],
                          )
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              onPressed: () => _confirmDelete(context, ref, debt.id, debt.personName),
                              icon: Icon(Icons.delete_outline, color: cs.error),
                              tooltip: 'Kaydı Sil',
                            ),
                            if (!debt.isSettled)
                              FilledButton.icon(
                                onPressed: () => _confirmSettle(context, ref, debt.id, debt.personName, isPositive),
                                style: FilledButton.styleFrom(
                                  backgroundColor: accentColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.check_circle_outline, size: 18),
                                label: Text(isPositive ? 'Tahsil Edildi' : 'Ödendi'),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('KAPATILDI', style: TextStyle(fontWeight: FontWeight.bold)),
                              )
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Hata: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDebtScreen()));
        },
        icon: const Icon(Icons.add),
        label: const Text('Yeni Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}