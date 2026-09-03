import 'package:finansio/presentation/budgets/viewmodel/budget_providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/empty_state.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  String _monthTR(int m) {
    const names = [
      '',
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık'
    ];
    return names[m];
  }

  Color _cardBg(ColorScheme cs) => cs.primaryContainer.withOpacity(0.22);
  BorderSide _cardBorder(ColorScheme cs) =>
      BorderSide(color: cs.primary.withOpacity(0.10));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(currentYearProvider);
    final month = ref.watch(currentMonthProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AppScaffold(
      title: "Bütçeler",
      headerHeight: 240,
      surfaceTopSpacing: 130,
      body: Stack(
        children: [
          // ✅ Hafif tint overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      cs.primary.withOpacity(0.06),
                      cs.secondary.withOpacity(0.03),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          Column(
            children: [
              // ✅ Header (Ay + yıl + nav okları)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: AppHeader(
                  title: "${_monthTR(month)} $year",
                  subtitle: "Aylık kategori bütçelerini düzenle ve takip et",
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: "Önceki Ay",
                        onPressed: () {
                          final d = DateTime(year, month - 1, 1);
                          ref.read(currentYearProvider.notifier).state = d.year;
                          ref.read(currentMonthProvider.notifier).state = d.month;
                        },
                        icon: const Icon(Icons.chevron_left, color: Colors.white),
                      ),
                      IconButton(
                        tooltip: "Sonraki Ay",
                        onPressed: () {
                          final d = DateTime(year, month + 1, 1);
                          ref.read(currentYearProvider.notifier).state = d.year;
                          ref.read(currentMonthProvider.notifier).state = d.month;
                        },
                        icon: const Icon(Icons.chevron_right, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: Consumer(
                  builder: (_, ref, __) {
                    final async = ref.watch(budgetStatusesProvider);

                    return async.when(
                      data: (list) {
                        if (list.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: EmptyState(
                              icon: Icons.account_balance_wallet_outlined,
                              title: "Henüz bütçe bilgisi yok",
                              subtitle:
                              "Kategorilerine aylık limit koyarak harcamalarını daha iyi kontrol edebilirsin.",
                              action: null,
                            ),
                          );
                        }

                        final exceeded =
                        list.where((e) => (e.progress ?? 0) > 1).toList();

                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            // ✅ Üst uyarı (varsa)
                            if (exceeded.isNotEmpty) ...[
                              Card(
                                color: cs.errorContainer.withOpacity(0.35),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(
                                      color: cs.error.withOpacity(0.18)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.warning_amber_rounded,
                                          color: Colors.orange.shade800),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Limit aşımları var",
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "${exceeded.length} kategoride bütçe limiti aşıldı. Bütçeleri gözden geçir.",
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: cs.onSurface
                                                    .withOpacity(0.7),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],

                            ...List.generate(list.length, (i) {
                              final item = list[i];
                              return Padding(
                                padding: EdgeInsets.only(
                                    bottom: i == list.length - 1 ? 0 : 10),
                                child: _BudgetCard(
                                  item: item,
                                  cardBg: _cardBg(cs),
                                  cardBorder: _cardBorder(cs),
                                ),
                              );
                            }),
                          ],
                        );
                      },
                      loading: () =>
                      const Center(child: CircularProgressIndicator()),
                      error: (e, st) => Center(child: Text("Hata: $e")),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends ConsumerWidget {
  final BudgetStatus item;
  final Color cardBg;
  final BorderSide cardBorder;

  const _BudgetCard({
    required this.item,
    required this.cardBg,
    required this.cardBorder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(currentYearProvider);
    final month = ref.watch(currentMonthProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final c = item.category;
    final budget = item.budget;
    final spent = item.spent;
    final remaining = item.remaining;

    final rawProgress = item.progress ?? 0;
    final progress = rawProgress.clamp(0.0, 1.0);
    final exceeded = rawProgress > 1.0;
    final nearLimit = !exceeded && rawProgress > 0.8;

    final remainingText =
    remaining != null ? '${remaining.toStringAsFixed(2)} ₺' : "- ₺";

    Color barColor;
    if (exceeded) {
      barColor = cs.error;
    } else if (nearLimit) {
      barColor = Colors.orange.shade800;
    } else {
      barColor = cs.primary;
    }

    String statusLabel;
    IconData statusIcon;
    Color statusColor;
    Color statusBg;

    if (exceeded) {
      statusLabel = "Limit Aşıldı";
      statusIcon = Icons.error_outline;
      statusColor = cs.error;
      statusBg = cs.errorContainer.withOpacity(0.35);
    } else if (nearLimit) {
      statusLabel = "Limite Yakın";
      statusIcon = Icons.warning_amber_outlined;
      statusColor = Colors.orange.shade800;
      statusBg = Colors.orange.withOpacity(0.12);
    } else {
      statusLabel = "Takip";
      statusIcon = Icons.shield_outlined;
      statusColor = cs.primary;
      statusBg = cs.primaryContainer.withOpacity(0.35);
    }

    return Card(
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: cardBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst satır
            Row(
              children: [
                _ColorDot(hex: c.colorHex),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    c.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (budget != null)
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: statusColor.withOpacity(0.18)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: budget == null || budget <= 0 ? 0 : progress,
                minHeight: 8,
                color: barColor,
                backgroundColor: cs.surfaceVariant.withOpacity(0.40),
              ),
            ),
            const SizedBox(height: 10),

            // info chips
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _infoChip(context,
                    label: "Harcama", value: "${spent.toStringAsFixed(2)} ₺"),
                _infoChip(
                  context,
                  label: "Bütçe",
                  value:
                  budget != null ? "${budget.toStringAsFixed(2)} ₺" : "- ₺",
                ),
                _infoChip(
                  context,
                  label: "Kalan",
                  value: remainingText,
                  highlightColor: exceeded
                      ? cs.errorContainer.withOpacity(0.45)
                      : nearLimit
                      ? Colors.orange.withOpacity(0.18)
                      : cs.secondaryContainer.withOpacity(0.35),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // actions
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final amount = await _askAmount(
                      context,
                      current: budget,
                      title: '${c.name} için bütçe',
                    );
                    if (amount == null) return;

                    await ref
                        .read(
                      upsertBudgetProvider(
                        UpsertBudgetArgs(
                          categoryId: c.id,
                          year: year,
                          month: month,
                          amount: amount,
                        ),
                      ).future,
                    )
                        .catchError((_) {});

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Bütçe kaydedildi")),
                      );
                    }
                  },
                  icon: Icon(budget == null ? Icons.add : Icons.edit),
                  label: Text(budget == null ? "Bütçe Ekle" : "Düzenle"),
                ),
                const SizedBox(width: 8),
                if (budget != null)
                  TextButton.icon(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("Bütçeyi Sil"),
                          content: Text(
                              '${c.name} için bu ayki bütçeyi silmek istiyor musun?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text("Vazgeç"),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text("Sil"),
                            ),
                          ],
                        ),
                      );
                      if (ok != true) return;

                      await ref
                          .read(
                        deleteBudgetProvider(
                          DeleteBudgetArgs(
                            categoryId: c.id,
                            year: year,
                            month: month,
                          ),
                        ).future,
                      )
                          .catchError((_) {});

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Bütçe silindi")),
                        );
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text("Sil"),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(
      BuildContext context, {
        required String label,
        required String value,
        Color? highlightColor,
      }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: (highlightColor ?? cs.surfaceVariant.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$label: ",
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(value, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.hex});
  final String hex;

  @override
  Widget build(BuildContext context) {
    var s = hex.replaceAll('#', '');
    if (s.length == 6) s = 'FF$s';
    final v = int.tryParse(s, radix: 16) ?? 0xFF9E9E9E;
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: Color(v),
        shape: BoxShape.circle,
      ),
    );
  }
}

Future<double?> _askAmount(
    BuildContext context, {
      double? current,
      String? title,
    }) async {
  final controller = TextEditingController(
    text: current != null ? current.toStringAsFixed(2) : '',
  );
  final formKey = GlobalKey<FormState>();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title ?? "Bütçe"),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Bütçe (₺)',
            hintText: "Örnek 2500",
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return "Boş bırakılamaz";
            final parsed = double.tryParse(v.replaceAll(',', '.'));
            if (parsed == null || parsed <= 0) return "Geçerli bir sayı gir";
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text("İptal"),
        ),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(ctx, true);
          },
          child: const Text("Kaydet"),
        ),
      ],
    ),
  );

  if (ok != true) return null;
  return double.parse(controller.text.replaceAll(',', '.'));
}
