// lib/presentation/shared/widgets/floating_main_menu.dart
import 'package:flutter/material.dart';
import '../../transactions/view/add_tx_screen.dart';
import '../../portfolio/view/add_asset_screen.dart';
import '../theme/app_surfaces.dart';

class FloatingMainMenu extends StatelessWidget {
  const FloatingMainMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    Widget menuButton(String title, IconData icon, Color color, VoidCallback onTap) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.pop(context); // Önce menüyü kapat
            onTap(); // Sonra istenen yere git
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 28, color: color),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget listTileMenu(String title, IconData icon, String route) {
      return ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: cs.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, route);
        },
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Çekme Çubuğu (Drag Handle)
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: cs.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 24),

          // Ekleme Butonları (Grid)
          Row(
            children: [
              Expanded(
                child: menuButton("İşlem Ekle", Icons.receipt_long, cs.primary, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTxScreen()));
                }),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: menuButton("Yatırım Ekle", Icons.candlestick_chart, Colors.orange, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAssetScreen()));
                }),
              ),
            ],
          ),

          const SizedBox(height: 24),
          Divider(color: cs.onSurface.withOpacity(0.1)),
          const SizedBox(height: 12),

          // Navigasyon Linkleri
          listTileMenu("Raporlar & İstatistik", Icons.pie_chart_outline, '/reports'),
          listTileMenu("Varlıklar & Portföy", Icons.account_balance_wallet_outlined, '/portfolio'),
          listTileMenu("Bütçe Planlaması", Icons.track_changes, '/budgets'),
          listTileMenu("Ayarlar", Icons.settings_outlined, '/settings'),
        ],
      ),
    );
  }
}