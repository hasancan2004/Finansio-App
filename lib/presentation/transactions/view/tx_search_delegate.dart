// lib/widgets/tx_search_delegate.dart
// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:finansio/data/database/app_database.dart';
import 'package:finansio/presentation/transactions/viewmodel/tx_providers.dart';

class TxSearchDelegate extends SearchDelegate<String?> {
  TxSearchDelegate({String? initialQuery}) {
    query = (initialQuery ?? '');
  }

  // ✅ Türkçe + case-insensitive normalize
  String _norm(String s) {
    return s
        .trim()
        .toLowerCase()
    // Türkçe harf normalize
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'c');
  }

  bool _matches(Tx t, String q) {
    if (q.isEmpty) return true;

    final nq = _norm(q);

    // aranacak alanlar: kategori + not
    final cat = _norm(t.category.name);
    final note = _norm(t.note ?? '');

    return cat.contains(nq) || note.contains(nq);
  }

  @override
  String get searchFieldLabel => 'İşlem ara (kategori / not)';

  @override
  TextInputAction get textInputAction => TextInputAction.search;

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          tooltip: "Temizle",
          icon: Icon(Icons.close),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      tooltip: "Geri",
      icon: Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  // ✅ Enter basınca: query’yi HomeScreen’e döndür
  @override
  void showResults(BuildContext context) {
    // query boşsa kapatma, suggestions göster
    if (query.trim().isEmpty) {
      showSuggestions(context);
      return;
    }
    close(context, query.trim());
  }

  // ✅ Live: her tuşta çalışan "Google suggestions" kısmı
  @override
  Widget buildSuggestions(BuildContext context) {
    return _LiveTxSearchList(
      queryText: query,
      onPickQuery: (q) => close(context, q),
    );
  }

  // ✅ Search results: suggestions ile aynı listeyi gösterebiliriz.
  // İstersen results kısmı daha "tam ekran arama sonuçları" gibi kalır.
  @override
  Widget buildResults(BuildContext context) {
    return _LiveTxSearchList(
      queryText: query,
      onPickQuery: (q) => close(context, q),
      showAsResults: true,
    );
  }
}

// ==========================
// Live Search Widget
// ==========================
class _LiveTxSearchList extends ConsumerWidget {
  final String queryText;
  final ValueChanged<String> onPickQuery;
  final bool showAsResults;

  const _LiveTxSearchList({
    required this.queryText,
    required this.onPickQuery,
    this.showAsResults = false,
  });

  String _norm(String s) {
    return s
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'c');
  }

  bool _matches(Tx t, String q) {
    if (q.trim().isEmpty) return true;

    final nq = _norm(q);

    final cat = _norm(t.category.name);
    final note = _norm(t.note ?? '');

    return cat.contains(nq) || note.contains(nq);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(txStreamProvider);
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final timeFmt = DateFormat('dd.MM.yyyy • HH:mm');

    return txs.when(
      loading: () => Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text("Hata: $e")),
      data: (list) {
        // ✅ canlı filtre (case-insensitive)
        final q = queryText.trim();

        final filtered = list.where((t) => _matches(t, q)).toList();

        // ✅ newest first (local)
        filtered.sort((a, b) => b.date.toLocal().compareTo(a.date.toLocal()));

        // Query boşken: "son işlemler" gibi davranalım
        if (q.isEmpty) {
          final recent = filtered.take(25).toList();

          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Text(
                  "Son işlemler",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface.withOpacity(.7),
                  ),
                ),
              ),
              ...recent.map((t) => _TxSuggestionTile(
                t: t,
                subtitle: timeFmt.format(t.date.toLocal()),
                onTap: () {
                  // ✅ kullanıcı bir öneriye tıklarsa:
                  // kategori adı ile arama yapmasını sağlıyoruz (istersen note da olabilir)
                  onPickQuery(t.category.name);
                },
              )),
              const SizedBox(height: 24),
            ],
          );
        }

        // Query dolu ama sonuç yok
        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                "“$q” için eşleşme bulunamadı.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface.withOpacity(.7),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // Query dolu: suggestions listesi
        // Results modunda daha fazla gösterebiliriz
        final showCount = showAsResults ? 200 : 20;
        final shown = filtered.take(showCount).toList();

        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "${filtered.length} sonuç",
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface.withOpacity(.7),
                      ),
                    ),
                  ),
                  if (!showAsResults)
                    TextButton(
                      onPressed: () {
                        // ✅ "tüm sonuçlar" gibi davran: query’yi geri döndür
                        // HomeScreen filtreyi uygulasın
                        onPickQuery(q);
                      },
                      child: Text("Uygula"),
                    ),
                ],
              ),
            ),
            ...shown.map((t) => _TxSuggestionTile(
              t: t,
              subtitle: [
                if ((t.note ?? '').trim().isNotEmpty) t.note!.trim(),
                timeFmt.format(t.date.toLocal()),
              ].join(" • "),
              onTap: () {
                // ✅ öneriye tıklayınca: query’yi aynı bırakıp uygula
                // burada “kira” gibi kategoriyle aramayı uygulatıyoruz
                onPickQuery(q);
              },
            )),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class _TxSuggestionTile extends StatelessWidget {
  final Tx t;
  final String subtitle;
  final VoidCallback onTap;

  const _TxSuggestionTile({
    required this.t,
    required this.subtitle,
    required this.onTap,
  });

  Color _hexToColor(String hex) {
    final v = hex.replaceAll('#', '');
    final colorInt = int.parse(v, radix: 16) | 0xFF000000;
    return Color(colorInt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isIncome = t.amount >= 0;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: _hexToColor(t.category.colorHex).withOpacity(.9),
        child: Text(
          t.category.name.characters.first,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      title: Text(
        t.category.name,
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _formatTry(t.amount.abs()),
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: isIncome ? Colors.green : Colors.red,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      dense: true,
      tileColor: cs.surface,
    );
  }
}

/// ✅ ₺ sağda: "10.000 ₺"
String _formatTry(double amount) {
  final f = NumberFormat("#,##0", "tr_TR");
  return '${f.format(amount)} ₺';
}