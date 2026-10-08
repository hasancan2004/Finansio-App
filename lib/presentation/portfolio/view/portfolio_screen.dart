// lib/presentation/portfolio/view/portfolio_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../data/database/app_database.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/bottom_nav.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/theme/app_surfaces.dart';
import '../viewmodel/portfolio_providers.dart';
import 'add_asset_screen.dart';

class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  bool _refreshing = false;

  Future<void> _refreshPrices() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final updated = await ref.read(portfolioControllerProvider).refreshPrices();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(updated > 0
                ? '$updated varlığın güncel fiyatı TCMB\'den güncellendi.'
                : 'Güncellenecek döviz varlığı bulunamadı.'),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('Fiyatlar alınamadı: $e')));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  String _formatTry(double amount, {bool signed = false}) {
    final f = NumberFormat("#,##0.00", "tr_TR");
    final sign = signed && amount > 0 ? '+' : '';
    return '$sign${f.format(amount)} ₺';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final assetsAsync = ref.watch(assetsStreamProvider);
    final summary = ref.watch(portfolioSummaryProvider);

    return AppScaffold(
      title: "Varlıklarım",
      surfaceTopSpacing: 130,
      headerHeight: 240,
      actions: [
        IconButton(
          tooltip: "Kurları güncelle",
          icon: _refreshing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.sync, color: Colors.white),
          onPressed: _refreshing ? null : _refreshPrices,
        ),
        IconButton(
          tooltip: "Ana Ekrana Dön",
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => bottomNavKey.currentState?.returnToHome(),
        ),
        const SizedBox(width: 8),
      ],
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: AppHeader(
              title: "Portföyüm 💼",
              subtitle: "Güncel Değer: ${_formatTry(summary.currentValue)}",
              trailing: CircleAvatar(
                radius: 20,
                backgroundColor: cs.primary.withOpacity(0.16),
                child: const Icon(Icons.pie_chart_outline, color: Colors.white),
              ),
            ),
          ),

          assetsAsync.when(
            data: (assets) {
              if (assets.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: EmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: "Henüz varlık eklemedin",
                    subtitle: "Altın, döviz veya fon yatırımlarını ekleyerek portföyünü takip etmeye başla.",
                    action: FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddAssetScreen()),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text("Varlık Ekle"),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _SummaryCard(summary: summary, format: _formatTry),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _DistributionCard(assets: assets, format: _formatTry),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: assets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final asset = assets[index];
                        return _AssetCard(asset: asset, format: _formatTry);
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => Center(child: Text("Hata: $e")),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final PortfolioSummary summary;
  final String Function(double, {bool signed}) format;

  const _SummaryCard({required this.summary, required this.format});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isProfit = summary.profitLoss >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppSurfaces.cardDecoration(cs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Toplam Kâr/Zarar",
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  format(summary.profitLoss, signed: true),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isProfit
                        ? Colors.green
                        : (isDark ? Colors.red.shade400 : Colors.red),
                  ),
                ),
              ),
              if (summary.totalCost > 0)
                Text(
                  '%${(summary.profitLossPercent * 100).toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isProfit
                        ? Colors.green
                        : (isDark ? Colors.red.shade400 : Colors.red),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _cell(theme, "Toplam Maliyet", format(summary.totalCost),
                    cs.onSurface),
              ),
              Expanded(
                child: _cell(theme, "Güncel Değer",
                    format(summary.currentValue), cs.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(ThemeData theme, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900, color: color)),
        ),
      ],
    );
  }
}

class _AssetCard extends ConsumerWidget {
  final AssetItem asset;
  final String Function(double, {bool signed}) format;
  const _AssetCard({required this.asset, required this.format});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    String iconStr = "💰";
    if (asset.type == "GOLD") iconStr = "🟡";
    if (asset.type == "USD") iconStr = "💵";
    if (asset.type == "EUR") iconStr = "💶";
    if (asset.type == "CRYPTO") iconStr = "🪙";

    final color = _hexToColor(asset.colorHex);
    final isProfit = asset.profitLoss >= 0;
    final profitColor = isProfit
        ? Colors.green
        : (isDark ? Colors.red.shade400 : Colors.red);

    return Container(
      decoration: AppSurfaces.cardDecoration(cs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddAssetScreen(editing: asset)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: color.withOpacity(0.15),
                      child: Text(iconStr, style: const TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            asset.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${asset.quantity} birim • Maliyet: ${format(asset.averagePrice)}",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withOpacity(0.7),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.edit_outlined, size: 16, color: cs.onSurface.withOpacity(0.5)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Güncel Değer",
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant)),
                          Text(
                            format(asset.currentValue),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(asset.hasLivePrice ? "Kâr/Zarar" : "Güncel fiyat yok",
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant)),
                          Text(
                            asset.hasLivePrice
                                ? "${format(asset.profitLoss, signed: true)} (%${(asset.profitLossPercent * 100).toStringAsFixed(1)})"
                                : "Fiyat girilmemiş",
                            textAlign: TextAlign.end,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: asset.hasLivePrice ? profitColor : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    final v = hex.replaceAll('#', '');
    final colorInt = int.parse(v, radix: 16) | 0xFF000000;
    return Color(colorInt);
  }
}

String _typeLabel(String type) {
  switch (type) {
    case 'GOLD':
      return 'Altın';
    case 'USD':
      return 'Dolar';
    case 'EUR':
      return 'Euro';
    case 'CRYPTO':
      return 'Kripto';
    case 'STOCK':
      return 'Hisse';
    default:
      return 'Diğer';
  }
}

Color _typeColor(String type) {
  switch (type) {
    case 'GOLD':
      return const Color(0xFFFFD700);
    case 'USD':
      return const Color(0xFF4CAF50);
    case 'EUR':
      return const Color(0xFF2196F3);
    case 'CRYPTO':
      return const Color(0xFF9C27B0);
    case 'STOCK':
      return const Color(0xFFFF5722);
    default:
      return const Color(0xFF607D8B);
  }
}

class _TypeSlice {
  final String type;
  final String label;
  final Color color;
  final double value;

  const _TypeSlice({
    required this.type,
    required this.label,
    required this.color,
    required this.value,
  });
}

List<_TypeSlice> _buildSlices(List<AssetItem> assets) {
  final map = <String, double>{};
  for (final a in assets) {
    map[a.type] = (map[a.type] ?? 0) + a.currentValue;
  }
  final slices = map.entries
      .map((e) => _TypeSlice(
            type: e.key,
            label: _typeLabel(e.key),
            color: _typeColor(e.key),
            value: e.value,
          ))
      .toList();
  slices.sort((a, b) => b.value.compareTo(a.value));
  return slices;
}

class _DistributionCard extends StatelessWidget {
  final List<AssetItem> assets;
  final String Function(double) format;

  const _DistributionCard({required this.assets, required this.format});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final slices = _buildSlices(assets);
    final total = slices.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppSurfaces.cardDecoration(cs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Varlık Dağılımı",
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: slices.map((s) {
                      final percent = s.value / total * 100;
                      return PieChartSectionData(
                        value: s.value,
                        color: s.color,
                        radius: 74,
                        title: '${percent.toStringAsFixed(0)}%',
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                    sectionsSpace: 2,
                    centerSpaceRadius: 46,
                    borderData: FlBorderData(show: false),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Toplam",
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                    Text(
                      format(total),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...slices.map((s) {
            final percent = s.value / total * 100;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: s.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(s.label,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  Text(
                    '%${percent.toStringAsFixed(1)} • ${format(s.value)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
