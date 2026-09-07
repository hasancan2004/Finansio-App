// lib/presentation/transactions/view/home_screen.dart
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:drift/drift.dart' show Value;
import 'package:finansio/presentation/budgets/viewmodel/budget_providers.dart';
import 'package:finansio/presentation/transactions/view/add_tx_screen.dart';
import 'package:finansio/presentation/shared/widgets/empty_state.dart';
import 'package:finansio/presentation/transactions/view/tx_search_delegate.dart';
import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:finansio/data/database/app_database.dart';
import 'package:finansio/domain/models/summary.dart';
import 'package:finansio/presentation/transactions/viewmodel/tx_providers.dart';

import 'tx_filter_sheet.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/theme/app_surfaces.dart';

// ✅ Recurring Engine
import 'package:finansio/domain/engine/recurring_engine.dart';

// ✅ Profil Dashboard Ekranımız
import '../../reports/view/profile_dashboard_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _recurringRan = false;

  @override
  void initState() {
    super.initState();

    // ✅ Home ilk açılışında 1 kere RecurringEngine çalıştır
    Future.microtask(() async {
      if (_recurringRan) return;
      _recurringRan = true;

      try {
        final db = ref.read(dbProvider);
        final created = await RecurringEngine(db).run();

        if (!mounted) return;

        if (created > 0) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text("✅ $created tekrarlayan işlem otomatik eklendi"),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
        }
      } catch (_) {
        // Sessiz
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final txs = ref.watch(txStreamProvider);
    final summary = ref.watch(summaryProvider);
    final filter = ref.watch(txFilterProvider);
    final range = ref.watch(globalDateRangeProvider);

    final budgetsAsync = ref.watch(budgetStatusesProvider);
    final globalLimit = ref.watch(globalLimitStatusProvider);

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // ✅ Limit/bütçe bannerları sadece "Bu Ay" + date range yokken
    final bool showBudgetBanners = filter == FilterRange.thisMonth && range == null;

    // ✅ Dynamic greeting
    final hour = DateTime.now().hour;
    final greet = hour < 12
        ? "Günaydın 👋"
        : hour < 18
        ? "İyi günler 👋"
        : "İyi akşamlar 👋";

    Widget alertPill({
      required IconData icon,
      required String text,
      required Color fg,
      required Color bg,
      VoidCallback? onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: fg.withOpacity(0.18)),
            ),
            child: Row(
              children: [
                Icon(icon, color: fg, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: fg.withOpacity(0.75),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final Widget globalLimitBanner = (() {
      if (!globalLimit.enabled) return const SizedBox.shrink();
      if (!globalLimit.near && !globalLimit.exceeded) {
        return const SizedBox.shrink();
      }

      final hasExceeded = globalLimit.exceeded;

      final String text = hasExceeded
          ? 'Genel limit aşıldı: ${globalLimit.spent.toStringAsFixed(0)} / ${globalLimit.limit.toStringAsFixed(0)} ₺'
          : 'Genel limite yaklaştın: %${(globalLimit.progress * 100).toStringAsFixed(0)}';

      final Color fg = hasExceeded ? cs.error : Colors.orange.shade800;
      final Color bg = hasExceeded
          ? cs.errorContainer.withOpacity(0.45)
          : Colors.orange.withOpacity(0.14);

      final IconData icon =
      hasExceeded ? Icons.error_outline : Icons.warning_amber_outlined;

      return alertPill(
        icon: icon,
        text: text,
        fg: fg,
        bg: bg,
        onTap: () => Navigator.pushNamed(context, '/budgets'),
      );
    })();

    final Widget categoryBudgetBanner = budgetsAsync.when(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();

        final exceededCount = list.where((b) => (b.progress ?? 0) > 1.0).length;
        final nearCount = list
            .where((b) => (b.progress ?? 0) > 0.8 && (b.progress ?? 0) <= 1.0)
            .length;

        if (exceededCount == 0 && nearCount == 0) {
          return const SizedBox.shrink();
        }

        final hasExceeded = exceededCount > 0;

        final text = hasExceeded
            ? '$exceededCount kategoride limit aşıldı'
            : '$nearCount kategoride limite yaklaştın';

        final Color fg = hasExceeded ? cs.error : Colors.orange.shade800;
        final Color bg = hasExceeded
            ? cs.errorContainer.withOpacity(0.45)
            : Colors.orange.withOpacity(0.14);

        final icon =
        hasExceeded ? Icons.error_outline : Icons.warning_amber_outlined;

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: alertPill(
            icon: icon,
            text: text,
            fg: fg,
            bg: bg,
            onTap: () => Navigator.pushNamed(context, '/budgets'),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
    );

    Future<void> openAddTx() async {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddTxScreen()),
      );
    }

    return AppScaffold(
      title: "Finansio",
      actions: [
        _buildSearchButton(context),
        IconButton(
          tooltip: "Tarih Aralığı",
          icon: const Icon(Icons.date_range, color: Colors.white),
          onPressed: () async {
            final now = DateTime.now();
            final initial = ref.read(globalDateRangeProvider);
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(now.year - 5),
              lastDate: DateTime(now.year + 5),
              initialDateRange: initial ??
                  DateTimeRange(
                    start: DateTime(now.year, now.month, 1),
                    end: DateTime(now.year, now.month + 1, 0),
                  ),
            );
            if (picked != null) {
              ref.read(globalDateRangeProvider.notifier).state = picked;
              ref.read(txFilterProvider.notifier).state = FilterRange.all;
            }
          },
        ),
        IconButton(
          tooltip: "Gelişmiş Filtre",
          icon: const Icon(Icons.filter_list, color: Colors.white),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              useSafeArea: true,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              showDragHandle: false,
              builder: (_) => const TxFilterSheet(),
            );
          },
        ),
        const SizedBox(width: 6),
      ],
      surfaceTopSpacing: 130,
      headerHeight: 240,
      floatingActionButton: FloatingActionButton(
        onPressed: openAddTx,
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          // HEADER
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: AppHeader(
              title: greet,
              subtitle: "Bugün finans durumun nasıl?",
              trailing: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfileDashboardScreen(),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: cs.primary.withOpacity(0.16),
                    child: Icon(Icons.person, color: cs.primary),
                  ),
                ),
              ),
            ),
          ),

          // FILTER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _FilterChips(
                selected: filter,
                onSelected: (f) => ref.read(txFilterProvider.notifier).state = f,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // SUMMARY
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: AppSurfaces.cardFill(cs),
              elevation: isDark ? 0 : 1,
              shadowColor: cs.primary.withOpacity(0.22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: AppSurfaces.cardBorder(cs),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: _SummaryCard(summary: summary),
              ),
            ),
          ),

          // RANGE
          if (range != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: AppSurfaces.cardFill(cs),
                elevation: isDark ? 0 : 1,
                shadowColor: cs.primary.withOpacity(0.22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: AppSurfaces.cardBorder(cs),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Tarih: ${DateFormat('dd.MM.yyyy').format(range.start)} – ${DateFormat('dd.MM.yyyy').format(range.end)}",
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                        ref.read(globalDateRangeProvider.notifier).state = null,
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text("Temizle"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // BANNERS (SADECE BU AY)
          if (showBudgetBanners) ...[
            if (globalLimit.enabled && (globalLimit.near || globalLimit.exceeded))
              globalLimitBanner,
            categoryBudgetBanner,
            const SizedBox(height: 10),
          ] else ...[
            const SizedBox(height: 10),
          ],

          // Transaction list
          _buildTransactionListEmbedded(context, txs),
        ],
      ),
    );
  }

  // ----------------- TOP ACTIONS -----------------

  Widget _buildSearchButton(BuildContext context) {
    final activeQuery = ref.watch(searchQueryProvider);

    return Row(
      children: [
        IconButton(
          tooltip: "Ara",
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: () async {
            final result = await showSearch<String?>(
              context: context,
              delegate: TxSearchDelegate(initialQuery: activeQuery),
            );
            if (result != null) {
              ref.read(searchQueryProvider.notifier).state =
              result.trim().isEmpty ? null : result.trim();
            }
          },
        ),
        if ((activeQuery ?? '').isNotEmpty)
          IconButton(
            tooltip: "Aramayı Temizle",
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => ref.read(searchQueryProvider.notifier).state = null,
          ),
      ],
    );
  }

  // ----------------- TX LIST (EMBEDDED) -----------------

  Widget _buildTransactionListEmbedded(
      BuildContext context,
      AsyncValue<List<Tx>> txs,
      ) {
    return txs.when(
      data: (list) {
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: "Henüz işlem yok",
              subtitle: "İlk işlemini ekle ve Finansio seni yönlendirsin.",
              action: FilledButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddTxScreen()),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text("İlk işlemi ekle"),
              ),
            ),
          );
        }

        final items = [...list];
        items.sort((a, b) => b.date.toLocal().compareTo(a.date.toLocal()));

        final cs = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final timeFmt = DateFormat('HH:mm');
        final fullFmt = DateFormat('dd.MM.yyyy');
        final theme = Theme.of(context);

        Future<void> goEdit(Tx t) async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddTxScreen(editing: t)),
          );
        }

        Future<void> deleteTx(Tx t) async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("İşlemi Sil"),
              content: Text(
                '"${t.category.name}" kategorisindeki ${_formatTry(t.amount.abs())} tutarındaki işlemi silmek istiyor musun?',
              ),
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

          try {
            await ref.read(dbProvider).deleteTransaction(t.id);

            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    "Silindi: ${t.category.name} • ${_formatTry(t.amount.abs())}",
                  ),
                  action: SnackBarAction(
                    label: "Geri al",
                    onPressed: () async {
                      await ref.read(dbProvider).addTransaction(
                        TransactionsCompanion.insert(
                          amount: t.amount,
                          categoryId: t.category.id,
                          note: (t.note == null || t.note!.trim().isEmpty)
                              ? const Value.absent()
                              : Value(t.note!),
                          date: Value(t.date),
                        ),
                      );
                    },
                  ),
                ),
              );
          } catch (e) {
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: Text("Silinemedi: $e"),
                  backgroundColor: cs.error,
                ),
              );
          }
        }

        final rows = <_TxRow>[];
        DateTime? lastDay;

        for (final t in items) {
          final dayKey = _dateOnly(t.date.toLocal());
          if (lastDay == null || dayKey != lastDay) {
            rows.add(_TxRow.header(dayKey));
            lastDay = dayKey;
          }
          rows.add(_TxRow.item(t));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows.length,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemBuilder: (context, i) {
            final row = rows[i];

            if (row.isHeader) {
              final day = row.day!;
              final title = _prettyDayLabel(day, fullFmt);

              return Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 8),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface.withOpacity(isDark ? 0.75 : 0.85),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 1,
                        // ✅ Çizgi rengini açık temada daha belirgin hale getirdik
                        color: cs.outlineVariant.withOpacity(isDark ? 0.35 : 0.70),
                      ),
                    ),
                  ],
                ),
              );
            }

            final t = row.tx!;
            final localDate = t.date.toLocal();
            final isIncome = t.amount >= 0;
            final initial = t.category.name.characters.first;

            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 200 + i * 18),
              builder: (_, v, child) => Opacity(
                opacity: v,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - v)),
                  child: child,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Dismissible(
                  key: ValueKey('tx_${t.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cs.error.withOpacity(0.15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.delete_outline, color: cs.error),
                        const SizedBox(width: 6),
                        Text(
                          "Sil",
                          style: TextStyle(
                            color: cs.error,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  confirmDismiss: (_) async {
                    await deleteTx(t);
                    return false;
                  },
                  child: Card(
                    color: AppSurfaces.cardFill(cs),
                    elevation: isDark ? 0 : 1,
                    shadowColor: cs.primary.withOpacity(0.20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: AppSurfaces.cardBorder(cs),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => goEdit(t),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor:
                              _hexToColor(t.category.colorHex).withOpacity(.90),
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.category.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      if ((t.note ?? '').isNotEmpty) t.note!,
                                      timeFmt.format(localDate),
                                    ].join(' • '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatTry(t.amount.abs()),
                                  style: TextStyle(
                                    color: isIncome
                                        ? Colors.green
                                        : _expenseAmountColor(isDark),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => goEdit(t),
                                      child: Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Icon(
                                          Icons.edit_outlined,
                                          size: 20,
                                          color: cs.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => deleteTx(t),
                                      child: Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Icon(
                                          Icons.delete_outline,
                                          size: 20,
                                          color: cs.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Center(child: Text('Hata: $e')),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final FilterRange selected;
  final ValueChanged<FilterRange> onSelected;

  const _FilterChips({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget chip(String label, FilterRange value) {
      final isSelected = selected == value;
      return ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: isSelected ? cs.onPrimary : cs.primary,
          ),
        ),
        selected: isSelected,
        selectedColor: cs.primary.withOpacity(.92),
        backgroundColor: cs.primaryContainer.withOpacity(0.55),
        onSelected: (_) => onSelected(value),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(
          color: isSelected ? cs.primary.withOpacity(0.25) : cs.outlineVariant.withOpacity(0.35),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      children: [
        chip("Tümü", FilterRange.all),
        chip("Bu Ay", FilterRange.thisMonth),
        chip("Geçen Ay", FilterRange.lastMonth),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Summary summary;
  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget cell(String title, double value, Color color) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatTry(value.abs()),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final expense = _expenseAmountColor(isDark);

    return Row(
      children: [
        cell("Gelir", summary.income, Colors.green),
        const SizedBox(width: 12),
        cell("Gider", summary.expense, expense),
        const SizedBox(width: 12),
        cell("Net", summary.net, summary.net >= 0 ? Colors.green : expense),
      ],
    );
  }
}

class _TxRow {
  final DateTime? day;
  final Tx? tx;

  bool get isHeader => day != null;

  _TxRow._({this.day, this.tx});

  factory _TxRow.header(DateTime day) => _TxRow._(day: day);
  factory _TxRow.item(Tx tx) => _TxRow._(tx: tx);
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _prettyDayLabel(DateTime day, DateFormat fullFmt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  if (day == today) return "Bugün";
  if (day == yesterday) return "Dün";

  return fullFmt.format(day);
}

Color _hexToColor(String hex) {
  final v = hex.replaceAll('#', '');
  final colorInt = int.parse(v, radix: 16) | 0xFF000000;
  return Color(colorInt);
}

Color _expenseAmountColor(bool isDark) =>
    isDark ? Colors.red.shade400 : Colors.red;

/// ✅ ₺ sağda + işareti yok: "10.000 ₺"
String _formatTry(double amount) {
  final f = NumberFormat("#,##0", "tr_TR");
  return '${f.format(amount)} ₺';
}