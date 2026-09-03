// lib/screens/risk_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:finansio/data/database/app_database.dart';
import 'package:finansio/presentation/budgets/viewmodel/budget_providers.dart';
import 'package:finansio/presentation/transactions/viewmodel/tx_providers.dart';
import 'package:finansio/presentation/reports/viewmodel/risk_providers.dart';

import 'package:finansio/domain/engine/risk_score.dart';

import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/app_header.dart';

class RiskDetailsScreen extends ConsumerWidget {
  const RiskDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    final riskAsync = ref.watch(monthlyRiskProvider);
    final budgetsAsync = ref.watch(budgetStatusesProvider);
    final globalLimit = ref.watch(globalLimitStatusProvider);

    return AppScaffold(
      title: "Risk Detay",
      headerHeight: 240,
      surfaceTopSpacing: 130,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: AppHeader(
              title: "Risk Detay 🧠",
              subtitle: "Limit ve bütçelerden hesaplanır", // ✅ Metin güncellendi
              trailing: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withOpacity(0.25),
                child: const Icon(Icons.shield_outlined,
                    color: Colors.white, size: 18),
              ),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                // 1) ÜST KART: skor + level + nedenler
                Card(
                  color: cs.primaryContainer.withOpacity(0.22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: cs.primary.withOpacity(0.10)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: riskAsync.when(
                      loading: () => _loadingLine(theme, "Risk analizi hazırlanıyor…"),
                      error: (e, st) => _errorLine(theme, cs, "Risk hesaplanamadı: $e"),
                      data: (r) {
                        final c = _levelColor(cs, r.level);
                        final icon = _levelIcon(r.level);
                        final label = _levelLabel(r.level);
                        final p = (r.score / 100.0).clamp(0.0, 1.0);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: c.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
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
                                        r.title,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Seviye: $label",
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: cs.onSurface.withOpacity(0.65),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: c.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: c.withOpacity(0.22)),
                                  ),
                                  child: Text(
                                    "${r.score}/100",
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
                                value: p,
                                minHeight: 10,
                                backgroundColor: cs.surfaceVariant.withOpacity(0.35),
                                valueColor: AlwaysStoppedAnimation<Color>(c),
                              ),
                            ),

                            const SizedBox(height: 12),
                            Text(
                              "Neden böyle?",
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),

                            ...r.reasons.map(
                                  (s) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "• ",
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        s,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: cs.onSurface.withOpacity(0.78),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            if (r.footer != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                r.footer!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurface.withOpacity(0.55),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 2) BREAKDOWN: Global Limit / Kategori Bütçeleri
                Card(
                  color: cs.primaryContainer.withOpacity(0.22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: cs.primary.withOpacity(0.10)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Bileşenler",
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),

                        _BreakdownRow(
                          title: "Genel Limit",
                          valueText: globalLimit.enabled
                              ? "${(globalLimit.progress * 100).toStringAsFixed(0)}%"
                              : "Kapalı",
                          color: globalLimit.enabled
                              ? (globalLimit.exceeded
                              ? cs.error
                              : (globalLimit.near
                              ? Colors.orange.shade800
                              : Colors.green))
                              : cs.onSurface.withOpacity(0.45),
                          subtitle: globalLimit.enabled
                              ? "${currency.format(globalLimit.spent)} / ${currency.format(globalLimit.limit)}"
                              : "Ayarlar → Genel Limit",
                        ),

                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.pushNamed(context, '/settings'),
                                icon: const Icon(Icons.settings_outlined, size: 18),
                                label: const Text("Limit Ayarı"),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.pushNamed(context, '/budgets'),
                                icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                                label: const Text("Bütçeler"),
                              ),
                            ),
                          ],
                        ),

                        const Divider(height: 26),

                        budgetsAsync.when(
                          loading: () => _loadingLine(theme, "Bütçeler yükleniyor…"),
                          error: (e, st) => _errorLine(theme, cs, "Bütçe hatası: $e"),
                          data: (list) {
                            final exceeded = list
                                .where((b) => (b.progress ?? 0) > 1.0)
                                .toList();
                            final near = list
                                .where((b) =>
                            (b.progress ?? 0) > 0.8 &&
                                (b.progress ?? 0) <= 1.0)
                                .toList();

                            final BudgetStatus? topRisk = exceeded.isNotEmpty
                                ? exceeded.first
                                : (near.isNotEmpty ? near.first : null);

                            String sub;
                            if (exceeded.isNotEmpty) {
                              sub = "${exceeded.length} kategoride aşıldı";
                            } else if (near.isNotEmpty) {
                              sub = "${near.length} kategoride yaklaştın";
                            } else {
                              sub = "Sorun görünmüyor";
                            }

                            final col = exceeded.isNotEmpty
                                ? cs.error
                                : (near.isNotEmpty
                                ? Colors.orange.shade800
                                : Colors.green);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _BreakdownRow(
                                  title: "Kategori bütçeleri",
                                  valueText: sub,
                                  color: col,
                                  subtitle: "Bu ay için aktif bütçeler",
                                ),

                                if (topRisk != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: cs.surfaceVariant.withOpacity(0.30),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: cs.outlineVariant.withOpacity(0.25)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "En riskli kategori",
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: cs.onSurface.withOpacity(0.75),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                topRisk.category.name,
                                                style: theme.textTheme.titleSmall?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              "%${(((topRisk.progress ?? 0) * 100).clamp(0, 999)).toStringAsFixed(0)}",
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                fontWeight: FontWeight.w900,
                                                color: (topRisk.progress ?? 0) > 1.0
                                                    ? cs.error
                                                    : Colors.orange.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(999),
                                          child: LinearProgressIndicator(
                                            value: ((topRisk.progress ?? 0).clamp(0.0, 1.0)),
                                            minHeight: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 12),

                                ...[
                                  ...exceeded.take(2),
                                  ...near.take(2),
                                ].map((b) {
                                  final p = (b.progress ?? 0).clamp(0.0, 999.0);
                                  final isEx = p > 1.0;
                                  final barColor =
                                  isEx ? cs.error : Colors.orange.shade800;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                b.category.name,
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              "${(p * 100).toStringAsFixed(0)}%",
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                fontWeight: FontWeight.w900,
                                                color: barColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(999),
                                          child: LinearProgressIndicator(
                                            value: p.clamp(0.0, 1.0),
                                            minHeight: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 3) AKSİYON ÖNERİLERİ
                Card(
                  color: cs.primaryContainer.withOpacity(0.22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: cs.primary.withOpacity(0.10)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: riskAsync.when(
                      loading: () => _loadingLine(theme, "Öneriler hazırlanıyor…"),
                      error: (e, st) => _errorLine(theme, cs, "Öneri üretilemedi: $e"),
                      data: (r) {
                        final tips = _tipsFor(r.level);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Ne yapabilirsin?",
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...tips.map(
                                  (t) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.check_circle_outline, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        t,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: cs.onSurface.withOpacity(0.78),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _levelLabel(RiskLevel level) {
    switch (level) {
      case RiskLevel.high:
        return "Yüksek";
      case RiskLevel.medium:
        return "Orta";
      case RiskLevel.low:
        return "Düşük";
    }
  }

  static Color _levelColor(ColorScheme cs, RiskLevel level) {
    switch (level) {
      case RiskLevel.high:
        return cs.error;
      case RiskLevel.medium:
        return Colors.orange.shade800;
      case RiskLevel.low:
        return Colors.green;
    }
  }

  static IconData _levelIcon(RiskLevel level) {
    switch (level) {
      case RiskLevel.high:
        return Icons.warning_amber_rounded;
      case RiskLevel.medium:
        return Icons.info_outline;
      case RiskLevel.low:
        return Icons.verified_outlined;
    }
  }

  static Widget _loadingLine(ThemeData theme, String text) {
    return Row(
      children: [
        const SizedBox(
            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 10),
        Text(text,
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800)),
      ],
    );
  }

  static Widget _errorLine(ThemeData theme, ColorScheme cs, String text) {
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w800,
        color: cs.error,
      ),
    );
  }

  static List<String> _tipsFor(RiskLevel level) {
    switch (level) {
      case RiskLevel.high:
        return const [
          "Bu ay kalan günler için 2–3 ana gider kategorisini sıkı takip et.",
          "Genel limiti aşmışsan limiti güncelle ya da harcamayı kıs (market/yeme-içme).",
          "Tek seferlik büyük harcamaları (alışveriş/elektronik) sonraki aya ertele.",
        ];
      case RiskLevel.medium:
        return const [
          "En çok harcadığın 1–2 kategoride ufak kesinti bile neti toparlar.",
          "Bütçeye yaklaşan kategorileri limitle veya bu hafta harcamayı azalt.",
          "Yeni harcama girerken anomali uyarılarını dikkate al.",
        ];
      case RiskLevel.low:
        return const [
          "Şu an stabil gidiyorsun: bütçe hedeflerini koru.",
          "Küçük birikim için otomatik hedef belirleyebilirsin (örn. haftalık).",
          "Bütçe durumunu ara ara kontrol edip sürpriz giderlere hazır ol.", // ✅ Metin güncellendi
        ];
    }
  }
}

class _BreakdownRow extends StatelessWidget {
  final String title;
  final String valueText;
  final Color color;
  final String subtitle;

  const _BreakdownRow({
    required this.title,
    required this.valueText,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withOpacity(0.65),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          valueText,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}