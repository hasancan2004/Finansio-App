import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/services/recurring_schedule.dart';
import '../viewmodel/subscriptions_provider.dart';
import 'add_subscription_screen.dart';

import '../../../data/database/app_database.dart';

class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  String _formatTry(double amount) {
    final f = NumberFormat("#,##0", "tr_TR");
    return '${f.format(amount.abs())} ₺';
  }

  // Popüler markalara göre renk veren akıllı fonksiyon
  Color _getBrandColor(String? note) {
    if (note == null) return Colors.blueGrey;
    final lower = note.toLowerCase();
    if (lower.contains('netflix')) return const Color(0xFFE50914);
    if (lower.contains('spotify')) return const Color(0xFF1DB954);
    if (lower.contains('youtube')) return const Color(0xFFFF0000);
    if (lower.contains('amazon') || lower.contains('prime')) return const Color(0xFF00A8E1);
    if (lower.contains('apple')) return Colors.grey.shade400;
    if (lower.contains('exxen')) return const Color(0xFFF6C800);
    if (lower.contains('blutv')) return const Color(0xFF007BFF);
    if (lower.contains('disney')) return const Color(0xFF113CCF);
    if (lower.contains('gym') || lower.contains('macfit')) return Colors.orange;
    return Colors.deepPurple;
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int id, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aboneliği İptal Et'),
        content: Text('"$title" abonelik takibini silmek istediğinden emin misin?\nGeçmişte kaydedilen ödemelerin silinmez.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              ref.read(subscriptionsControllerProvider).deleteSubscription(id);
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
    final subsAsync = ref.watch(subscriptionsStreamProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aboneliklerim', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: subsAsync.when(
        data: (subs) {
          if (subs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.autorenew_outlined, size: 80, color: cs.primary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('Abonelik bulunamadı.', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Düzenli ödediğin fatura ve\nüyelikleri buradan takip edebilirsin.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            );
          }

          // Toplam Aylık Gideri Hesapla
          double totalMonthly = 0.0;
          for (final sub in subs) {
            if (!sub.isActive) continue;
            if (sub.frequency == 'monthly') {
              totalMonthly += sub.amount.abs() / sub.interval;
            } else if (sub.frequency == 'weekly') {
              totalMonthly += (sub.amount.abs() * 4) / sub.interval;
            } else if (sub.frequency == 'daily') {
              totalMonthly += (sub.amount.abs() * 30) / sub.interval;
            }
          }

          return Column(
            children: [
              // Üst Kısım: Aylık Toplam Gider Analizi
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary.withOpacity(0.8), cs.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: cs.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.analytics_outlined, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Aylık Toplam Yük', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(_formatTry(totalMonthly), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Abonelikler Listesi
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: subs.length,
                  itemBuilder: (context, index) {
                    final sub = subs[index];
                    final title = sub.note?.isNotEmpty == true ? sub.note! : 'Abonelik';
                    final initial = title.substring(0, 1).toUpperCase();
                    final brandColor = _getBrandColor(sub.note);

                    // Bir sonraki ödeme tarihini hesapla
                    final nextDate = RecurringSchedule.nextRunDateOnly(sub);
                    final daysLeft = nextDate != null ? nextDate.difference(DateTime.now()).inDays : null;

                    String dateText = 'Tarih Yok';
                    if (nextDate != null) {
                      if (daysLeft == 0) dateText = 'Bugün';
                      else if (daysLeft == 1) dateText = 'Yarın';
                      else if (daysLeft! > 1) dateText = '$daysLeft gün sonra';
                      else dateText = DateFormat('dd MMM').format(nextDate);
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
                      ),
                      color: cs.surfaceContainerHighest.withOpacity(0.3),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            // Marka İkonu/Baş Harfi
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: sub.isActive ? brandColor.withOpacity(0.2) : cs.surfaceContainer,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initial,
                                style: TextStyle(
                                  color: sub.isActive ? brandColor : cs.onSurfaceVariant,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Başlık ve Tarih
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: sub.isActive ? cs.onSurface : cs.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 12, color: cs.onSurfaceVariant),
                                      const SizedBox(width: 4),
                                      Text(
                                        dateText,
                                        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Fiyat ve Menü
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatTry(sub.amount),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: sub.isActive ? cs.onSurface : cs.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Transform.scale(
                                      scale: 0.8,
                                      child: Switch(
                                        value: sub.isActive,
                                        onChanged: (val) {
                                          ref.read(subscriptionsControllerProvider).toggleActive(sub.id, sub.isActive);
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: Icon(Icons.delete_outline, size: 20, color: cs.error.withOpacity(0.8)),
                                      onPressed: () => _confirmDelete(context, ref, sub.id, title),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Hata: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddSubscriptionScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Yeni Abonelik', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}