// lib/presentation/reports/view/profile_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:finansio/presentation/reports/view/ai_insights_screen.dart';
import 'package:finansio/presentation/settings/view/settings_screen.dart';
import 'package:finansio/presentation/shared/widgets/app_scaffold.dart';
import 'package:finansio/presentation/shared/theme/app_surfaces.dart';

import '../../../data/services/pdf_export_service.dart';
import '../../transactions/viewmodel/tx_providers.dart';

class ProfileDashboardScreen extends ConsumerWidget {
  const ProfileDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AppScaffold(
      title: "Hesabım",
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildProfileCard(context, cs),
            const SizedBox(height: 24),
            _buildProBanner(context, cs),
            const SizedBox(height: 24),
            _buildSettingsList(context, cs, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, ColorScheme cs) {
    return Row(
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: cs.primaryContainer,
          child: Icon(
            Icons.person,
            size: 36,
            color: cs.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Finansio Kullanıcısı",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Yerel Hesap",
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
          const Icon(Icons.star_rounded, color: Colors.white, size: 32),
          const SizedBox(width: 16),
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

  Widget _buildSettingsList(BuildContext context, ColorScheme cs, WidgetRef ref) {
    return Column(
      children: [
        _buildListTile(
          icon: Icons.auto_awesome,
          title: "AI Insights (Akıllı Asistan)",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AIInsightsScreen()),
            );
          },
          cs: cs,
        ),
        _buildListTile(
          icon: Icons.account_balance_wallet,
          title: "Bütçeler ve Limitler",
          onTap: () {
            Navigator.pushNamed(context, "/budgets");
          },
          cs: cs,
        ),
        const Divider(height: 32),
        _buildListTile(
          icon: Icons.settings,
          title: "Genel Ayarlar",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
          cs: cs,
        ),

        // ✅ GÜNCELLENMİŞ PDF BUTONU (Seçenekler menüsünü açar)
        _buildListTile(
          icon: Icons.picture_as_pdf,
          title: "Raporları Dışa Aktar (PDF)",
          onTap: () => _showExportOptions(context, ref),
          cs: cs,
        ),
      ],
    );
  }

  // ✅ YENİ: Alt kısımdan açılan şık seçenek menüsü
  void _showExportOptions(BuildContext context, WidgetRef ref) {
    final txAsync = ref.read(txStreamProvider);
    final summary = ref.read(summaryProvider);

    if (txAsync.isLoading) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text("Veriler yükleniyor, lütfen bekleyin...")));
      return;
    }

    final txs = txAsync.value ?? [];

    if (txs.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text("Dışa aktarılacak finansal işlem bulunamadı.")));
      return;
    }

    final monthName = DateFormat('MMMM yyyy', 'tr_TR').format(DateTime.now());

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
          decoration: AppSurfaces.sheetDecoration(cs),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                Text(
                  "Rapor Dışa Aktarma",
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),

                // İNDİR SEÇENEĞİ
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    child: Icon(Icons.download_rounded, color: cs.primary),
                  ),
                  title: const Text("Cihaza İndir", style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text("Dosyalara kaydet ve bildirim al", style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 12)),
                  onTap: () async {
                    Navigator.pop(ctx); // Menüyü kapat
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(const SnackBar(content: Text("Rapor cihaza indiriliyor...")));

                    try {
                      await PdfExportService.downloadAndNotifyMonthlyReport(
                        monthName: monthName,
                        summary: summary,
                        transactions: txs,
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
                    }
                  },
                ),

                // PAYLAŞ SEÇENEĞİ
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.withOpacity(0.15),
                    child: Icon(Icons.share_rounded, color: Colors.green.shade700),
                  ),
                  title: const Text("Uygulamalarla Paylaş", style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text("WhatsApp, e-posta veya diğer uygulamalar", style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 12)),
                  onTap: () async {
                    Navigator.pop(ctx); // Menüyü kapat
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(const SnackBar(content: Text("Paylaşım menüsü hazırlanıyor...")));

                    try {
                      await PdfExportService.generateAndShareMonthlyReport(
                        monthName: monthName,
                        summary: summary,
                        transactions: txs,
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        );
      },
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
        child: Icon(icon, color: cs.primary, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}