import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../viewmodel/saving_goals_provider.dart';
import 'add_saving_goal_screen.dart';

class SavingGoalsScreen extends ConsumerWidget {
  const SavingGoalsScreen({super.key});

  String _formatTry(double amount) {
    final f = NumberFormat("#,##0", "tr_TR");
    return '${f.format(amount)} ₺';
  }

  Color _hexToColor(String hex) {
    final v = hex.replaceAll('#', '');
    if (v.length == 6) {
      return Color(int.parse('FF$v', radix: 16));
    }
    return Colors.blue;
  }

  // ---- PARA EKLEME MODALI ----
  void _showAddMoneySheet(BuildContext context, WidgetRef ref, int goalId, String title) {
    final amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24, right: 24, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$title\nKumbarasına Para Ekle',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Eklenecek Tutar (₺)',
                  prefixIcon: const Icon(Icons.add_circle_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  final amountText = amountController.text.replaceAll(',', '.');
                  final amount = double.tryParse(amountText) ?? 0.0;
                  if (amount > 0) {
                    ref.read(savingGoalsControllerProvider).addMoneyToGoal(goalId, amount, title);
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Kumbaraya At', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // ---- HEDEF DÜZENLEME MODALI ----
  void _showEditGoalSheet(BuildContext context, WidgetRef ref, int goalId, String currentTitle, double currentTarget) {
    final titleController = TextEditingController(text: currentTitle);
    final amountController = TextEditingController(text: currentTarget.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24, right: 24, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Hedefi Düzenle',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Hedef Adı',
                  prefixIcon: const Icon(Icons.flag_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Hedeflenen Tutar (₺)',
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  final title = titleController.text.trim();
                  final amountText = amountController.text.replaceAll(',', '.');
                  final amount = double.tryParse(amountText) ?? 0.0;

                  if (title.isNotEmpty && amount > 0) {
                    // ✅ HATA DÜZELTİLDİ: Artık doğru updateGoal fonksiyonu çağrılıyor
                    ref.read(savingGoalsControllerProvider).updateGoal(
                      id: goalId,
                      title: title,
                      targetAmount: amount,
                    );
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Güncelle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // ---- HEDEF SİLME ONAYI ----
  void _confirmDelete(BuildContext context, WidgetRef ref, int goalId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kumbarayı Sil'),
        content: Text('"$title" hedefini silmek istediğinden emin misin?\n\nBu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              ref.read(savingGoalsControllerProvider).deleteGoal(goalId);
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
    final goalsAsync = ref.watch(savingGoalsStreamProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kumbaralarım', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: goalsAsync.when(
        data: (goals) {
          if (goals.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.savings_outlined, size: 80, color: cs.primary.withAlpha(128)),
                  const SizedBox(height: 16),
                  Text('Henüz bir hedefin yok.', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Hemen bir kumbara oluştur ve\nbirikim yapmaya başla!', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final goal = goals[index];
              final progressPercent = (goal.progress * 100).toInt();
              final goalColor = _hexToColor(goal.colorHex);

              return Card(
                margin: const EdgeInsets.only(bottom: 20),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: cs.outlineVariant.withAlpha(100)),
                ),
                color: cs.surfaceContainerHighest.withAlpha(76),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: goalColor.withAlpha(51), shape: BoxShape.circle),
                            child: Icon(Icons.savings, color: goalColor, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(goal.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, fontSize: 18)),
                                const SizedBox(height: 4),
                                Text('${_formatTry(goal.currentAmount)} / ${_formatTry(goal.targetAmount)}', style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          // Yüzde Rozeti
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
                            child: Text('%$progressPercent', style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                          // Düzenle / Sil Menüsü
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant),
                            onSelected: (value) {
                              if (value == 'edit') {
                                // ✅ HATA DÜZELTİLDİ: Artık düzenleme popup'ı açılıyor
                                _showEditGoalSheet(context, ref, goal.id, goal.title, goal.targetAmount);
                              } else if (value == 'delete') {
                                _confirmDelete(context, ref, goal.id, goal.title);
                              }
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Düzenle')])),
                              PopupMenuItem<String>(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('Sil', style: TextStyle(color: Colors.red))])),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: goal.progress,
                          minHeight: 12,
                          backgroundColor: cs.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(goalColor),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Kalan Tutar', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                              Text(_formatTry(goal.remainingAmount), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => _showAddMoneySheet(context, ref, goal.id, goal.title),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Para Ekle'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ],
                      )
                    ],
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
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddSavingGoalScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Yeni Hedef', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}