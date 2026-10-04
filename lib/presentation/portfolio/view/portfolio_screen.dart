// lib/presentation/portfolio/view/portfolio_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/database/app_database.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/bottom_nav.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/theme/app_surfaces.dart';
import '../viewmodel/portfolio_providers.dart';
import 'add_asset_screen.dart';

class PortfolioScreen extends ConsumerWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final assetsAsync = ref.watch(assetsStreamProvider);
    final totalValue = ref.watch(portfolioTotalProvider);

    return AppScaffold(
      title: "Varlıklarım",
      surfaceTopSpacing: 130,
      headerHeight: 240,
      // ✅ ÇAKIŞMA ÇÖZÜMÜ: Buradaki floatingActionButton tamamen kaldırıldı.
      // Kontrol artık tamamen BottomNavShell'de!
      actions: [
        IconButton(
          tooltip: "Ana Ekrana Dön",
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            // ✅ Public metodu tetikliyoruz, böylece private değişken hatası biter ve menü kapanmaz
            bottomNavKey.currentState?.returnToHome();
          },
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
              subtitle: "Toplam Maliyet: ${_formatTry(totalValue)}",
              trailing: CircleAvatar(
                radius: 20,
                backgroundColor: cs.primary.withOpacity(0.16),
                child: Icon(Icons.pie_chart_outline, color: cs.primary),
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

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: assets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final asset = assets[index];
                    return _AssetCard(asset: asset);
                  },
                ),
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

  String _formatTry(double amount) {
    final f = NumberFormat("#,##0.00", "tr_TR");
    return '${f.format(amount)} ₺';
  }
}

class _AssetCard extends ConsumerWidget {
  final AssetItem asset;
  const _AssetCard({required this.asset});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    String iconStr = "💰";
    if (asset.type == "GOLD") iconStr = "🟡";
    if (asset.type == "USD") iconStr = "💵";
    if (asset.type == "CRYPTO") iconStr = "🪙";

    final color = _hexToColor(asset.colorHex);

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
            child: Row(
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
                        "${asset.quantity} birim • Mal: ${_formatTry(asset.averagePrice)}",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.7),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTry(asset.totalCost),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.green.shade400 : Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(Icons.edit_outlined, size: 16, color: cs.onSurface.withOpacity(0.5)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTry(double amount) {
    final f = NumberFormat("#,##0.00", "tr_TR");
    return '${f.format(amount)} ₺';
  }

  Color _hexToColor(String hex) {
    final v = hex.replaceAll('#', '');
    final colorInt = int.parse(v, radix: 16) | 0xFF000000;
    return Color(colorInt);
  }
}