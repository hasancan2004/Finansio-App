import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:finansio/data/database/app_database.dart';
import 'package:finansio/presentation/transactions/viewmodel/tx_providers.dart';

import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/theme/app_surfaces.dart';


class FilteredTxListScreen extends ConsumerWidget {
  final String title;
  final int? categoryId;
  final DateTime? month;

  const FilteredTxListScreen({
    super.key,
    required this.title,
    this.categoryId,
    this.month,
  });

  Color _cardBg(ColorScheme cs) => AppSurfaces.cardFill(cs);
  BorderSide _cardBorder(ColorScheme cs) => AppSurfaces.cardBorder(cs);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final start = month != null ? DateTime(month!.year, month!.month, 1) : null;
    final end = month != null ? DateTime(month!.year, month!.month + 1, 1) : null;

    final future = db.filteredTransactions(
      categoryId: categoryId,
      start: start,
      end: end,
    );

    final currency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final dateFmt = DateFormat("dd.MM.yyyy HH:mm");

    return AppScaffold(
      title: title,
      headerHeight: 220,
      surfaceTopSpacing: 120,
      body: Stack(
        children: [
          // ✅ Soft tint overlay
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
              // ✅ Header
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: AppHeader(
                  title: title,
                  subtitle: month != null
                      ? "Seçili ayın işlemleri"
                      : categoryId != null
                      ? "Seçili kategori işlemleri"
                      : "Filtrelenmiş işlemler",
                  trailing: CircleAvatar(
                    radius: 18,
                    backgroundColor: cs.primary.withOpacity(0.16),
                    child: Icon(Icons.list_alt, color: cs.primary, size: 18),
                  ),
                ),
              ),

              Expanded(
                child: FutureBuilder<List<TxWithCategory>>(
                  future: future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snap.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            "Hata: ${snap.error}",
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    }

                    final list = snap.data ?? [];

                    if (list.isEmpty) {
                      return const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: "Bu filtreye ait işlem yok",
                        subtitle: "Farklı bir filtre deneyebilirsin.",
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final item = list[i];
                        final tx = item.tx;
                        final cat = item.category;
                        final isIncome = tx.amount >= 0;

                        final note = tx.note ?? '';
                        final subtitleParts = <String>[];
                        if (note.isNotEmpty) subtitleParts.add(note);
                        subtitleParts.add(dateFmt.format(tx.date));

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Card(
                            color: _cardBg(cs),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: _cardBorder(cs),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _hexToColor(cat.colorHex).withOpacity(.92),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.35),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  cat.name.characters.first,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              title: Text(
                                cat.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Text(
                                subtitleParts.join(' • '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurface.withOpacity(0.68),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: Text(
                                '${isIncome ? '+' : '-'}${currency.format(tx.amount.abs())}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: isIncome ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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

Color _hexToColor(String hex) {
  var v = hex.replaceAll('#', '');
  if (v.length == 6) v = 'FF$v';
  final colorInt = int.parse(v, radix: 16);
  return Color(colorInt);
}
