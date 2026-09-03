import 'package:finansio/presentation/reports/view/ai_insights_screen.dart';
import 'package:finansio/presentation/settings/view/settings_screen.dart';
import 'package:finansio/presentation/shared/widgets/app_scaffold.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileDashboardScreen extends ConsumerWidget{
  const ProfileDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AppScaffold(
      title: "Hesabım",
      // AppScaffold kullandığımız için senin standart gradient + surface yapın otomatik gelecek
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16,),
            _buildProfileCard(context, cs),
            const SizedBox(height: 24,),
            _buildProBanner(context, cs),
            const SizedBox(height: 24,),
            _buildSettingsList(context, cs, ref),
          ],
        ),
      ),
    );
  }

  // En üstteki büyük avatar ve isim kısmı
  Widget _buildProfileCard(BuildContext context, ColorScheme cs) {
    return Row(
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: cs.primaryContainer,
          child: Text(
            "HC",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: cs.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 16,),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hasan Can Kula",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4,),
              Text(
                "hasancan.dev@gmail.com",
                style: TextStyle(
                  color: cs.onSurface.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Premium özelliklere hazırlık veya genel durum banner'ı
  Widget _buildProBanner(BuildContext context, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: Colors.white, size: 32,),
          const SizedBox(width: 16,),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Ücretsiz Sürüm",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "Tüm verilerin şu anda cihazda güvende.",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Alt kısımdaki ayarlar listesi
  Widget _buildSettingsList(BuildContext context, ColorScheme cs, WidgetRef ref) {
    return Column(
      children: [
        _buildListTile(
          icon: Icons.auto_awesome,
          title: "AI Insights Yapılandırması",
          onTap: () {
            // İleride AI ayarlarına gider
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AIInsightsScreen()),
            );
          },
          cs: cs
        ),
        _buildListTile(
          icon: Icons.account_balance_wallet,
          title: "Bütçeler ve Limitler",
          onTap: () {
            // Bütçe ekranına yönlendir
            Navigator.pushNamed(context, "/budgets");
          },
          cs: cs,
        ),
        const Divider(height: 32,),
        _buildListTile(
          icon: Icons.settings,
          title: "Genel Ayarlar",
          onTap: () {
            // Senin mevcut settings_screen.dart dosyana yönlendir
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
          cs: cs,
        ),
        _buildListTile(
          icon: Icons.file_download,
          title: "Dışa / İçe Aktar (CSV)",
          onTap: () {
            // CSV işlemleri
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
          cs: cs,
        ),
      ],
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required ColorScheme cs,
}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: cs.primary,size: 22,),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20,),
      onTap: onTap,
    );
  }
}