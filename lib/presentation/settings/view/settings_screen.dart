// lib/presentation/settings/view/settings_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finansio/presentation/settings/viewmodel/theme_provider.dart';
import 'package:finansio/presentation/settings/view/privacy_policy_screen.dart';

import '../../../data/services/notification_service.dart';
import '../../../data/database/app_database.dart';
import '../../budgets/viewmodel/budget_providers.dart';
import '../../reports/viewmodel/ai_insights_provider.dart';
import '../../reports/viewmodel/forecast_providers.dart';
import '../../transactions/viewmodel/tx_providers.dart';
import '../../reports/viewmodel/reports.dart';

import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/app_scaffold.dart';

import '../../recurring/view/recurring_rules_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _loading = true;

  // Notification state
  bool _dailyEnabled = false;
  TimeOfDay _dailyTime = const TimeOfDay(hour: 21, minute: 0);

  bool _budgetEnabled = true;
  bool _trendEnabled = true;
  bool _categoryEnabled = true;

  bool _notifPermissionEnabled = true;
  bool _exactAlarmEnabled = true; // Android 12+ "Alarmlar ve hatırlatıcılar" izni
  bool _batteryOptIgnored = true; // Pil optimizasyonundan muaf mı? (true = muaf = iyi)

  // busy
  bool _backupBusy = false;

  @override
  void initState() {
    super.initState();
    _loadNotif();
  }

  // ✅ ÇÖZÜM: Try-Catch ekleyerek bildirim servisi çökse bile
  // ayarlar ekranının sonsuza kadar yükleme modunda kalmasını engelledik.
  Future<void> _loadNotif() async {
    try {
      await NotificationService.loadSettings();
      final p = await NotificationService.areNotificationsEnabled();
      final exactOk = await NotificationService.canScheduleExactAlarms();
      final batteryOk = await NotificationService.isBatteryOptimizationIgnored();

      if (!mounted) return;
      setState(() {
        _dailyEnabled = NotificationService.dailyEnabled;
        _dailyTime = NotificationService.dailyTime;
        _budgetEnabled = NotificationService.budgetEnabled;
        _trendEnabled = NotificationService.trendEnabled;
        _categoryEnabled = NotificationService.categoryEnabled;
        _notifPermissionEnabled = p;
        _exactAlarmEnabled = exactOk;
        _batteryOptIgnored = batteryOk;
        _loading = false;
      });
    } catch (e) {
      debugPrint("[Settings] Bildirim ayarları yüklenirken hata oluştu: $e");
      if (!mounted) return;
      setState(() {
        // Hata alınsa dahi loading'i kaldırıp ekranı göster
        _loading = false;
      });
    }
  }

  String _fmtTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ---------------- UI Helpers ----------------

  BoxDecoration _cardDecoration(ThemeData theme) {
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
          Color.lerp(const Color(0xFF2A2E36), cs.primaryContainer, 0.08)!,
          const Color(0xFF1E2228),
        ]
            : [
          Color.lerp(const Color(0xFFD6E7F2), cs.primaryContainer, 0.38)!,
          Color.lerp(const Color(0xFFDEECF5), cs.secondaryContainer, 0.32)!,
        ],
      ),
      border: Border.all(
        color: cs.primary.withOpacity(isDark ? 0.16 : 0.20),
      ),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withOpacity(0.35)
              : cs.primary.withOpacity(0.12),
          blurRadius: 18,
          spreadRadius: -10,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  Widget _sectionHeader({
    required ThemeData theme,
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final chip = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2F5BFF),
            Color(0xFF6A5CFF),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2F5BFF).withOpacity(isDark ? 0.35 : 0.25),
            blurRadius: 18,
            spreadRadius: -6,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        chip,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withOpacity(0.70),
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ]
            ],
          ),
        ),
      ],
    );
  }

  Widget _card(ThemeData theme, Widget child) {
    return Container(
      decoration: _cardDecoration(theme),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  TextStyle? _subtleSubtitle(ThemeData theme, {required bool enabled}) {
    final cs = theme.colorScheme;
    return theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurface.withOpacity(enabled ? 0.70 : 0.40),
      fontWeight: FontWeight.w600,
    );
  }

  // ---------------- Actions ----------------

  Future<void> _toggleDaily(bool v) async {
    if (v) {
      final granted = await NotificationService.requestPermission();
      final enabledNow = await NotificationService.areNotificationsEnabled();

      if (!mounted) return;
      setState(() => _notifPermissionEnabled = enabledNow);

      if (!granted || !enabledNow) {
        if (!mounted) return;
        setState(() => _dailyEnabled = false);
        await NotificationService.setDailyEnabled(false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bildirim izni kapalı. Ayarlardan izin verebilirsin.'),
          ),
        );
        return;
      }
    }

    await NotificationService.setDailyEnabled(v);

    if (!mounted) return;
    setState(() => _dailyEnabled = v);
  }

  Future<void> _pickDailyTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dailyTime,
    );
    if (picked == null) return;

    await NotificationService.setDailyTime(picked);
    if (!mounted) return;
    setState(() => _dailyTime = picked);
  }

  void _invalidateAll() {
    ref.invalidate(txStreamProvider);
    ref.invalidate(summaryProvider);
    ref.invalidate(budgetStatusesProvider);
    ref.invalidate(globalLimitStatusProvider);

    ref.invalidate(categoryPieProvider);
    ref.invalidate(monthlyTrendProvider);
    ref.invalidate(reportsSummaryProvider);

    ref.invalidate(aiThisMonthTxsProvider);
    ref.invalidate(aiLastMonthTxsProvider);
    ref.invalidate(aiInsightsProvider);
  }

  void _openRecurring() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RecurringRulesScreen()),
    );
  }

  Future<void> _confirmAndResetAll() async {
    if (_backupBusy) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Tüm verileri sil"),
        content: const Text(
          "Bu işlem geri alınamaz.\n\n"
              "• İşlemler (Transactions)\n"
              "• Bütçeler (Budgets)\n"
              "• Tekrarlayan kurallar\n"
              "• Kategori override'ları\n\n"
              "Silinsin mi?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("İptal"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sil"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _backupBusy = true);
    try {
      final db = ref.read(dbProvider);

      await db.clearAllData();
      await db.seedCategoriesOnly();

      _invalidateAll();

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text("Uygulama sıfırlandı ve tertemiz hale getirildi ✅")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text("Silme başarısız: $e")));
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final mode = ref.watch(themeModeProvider);
    final accentKey = ref.watch(accentColorProvider);
    final accentController = ref.read(accentColorProvider.notifier);

    return AppScaffold(
      title: "Ayarlar",
      headerHeight: 220,
      surfaceTopSpacing: 120,
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [Colors.transparent, Colors.transparent]
                        : [
                      const Color(0xFF2F5BFF).withOpacity(0.05),
                      const Color(0xFF6A5CFF).withOpacity(0.035),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: AppHeader(
                  title: "Ayarlar ⚙️",
                  subtitle: "Tema, bildirim ve yedeklemeyi buradan yönet",
                  trailing: CircleAvatar(
                    radius: 18,
                    backgroundColor: cs.primary.withOpacity(0.16),
                    child: Icon(Icons.settings, color: cs.primary),
                  ),
                  onSurface: true,
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    // ✅ Genel bildirim izni banner
                    if (!_notifPermissionEnabled)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: cs.errorContainer.withOpacity(0.40),
                          border: Border.all(
                              color: cs.error.withOpacity(0.20)),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: cs.error),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Bildirim izni kapalı",
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Hatırlatmaların çalışması için bildirim iznini açmalısın.",
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                      color: cs.onSurface
                                          .withOpacity(0.75),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        await NotificationService
                                            .openAppNotificationSettings();
                                        await _loadNotif();
                                      },
                                      icon: const Icon(
                                          Icons.check_circle_outline),
                                      label: const Text("İzin ver"),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ✅ Android 12+ Exact Alarm (Alarmlar ve hatırlatıcılar) izni banner
                    if (!_exactAlarmEnabled)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: Colors.orange.withOpacity(0.12),
                          border: Border.all(
                              color: Colors.orange.withOpacity(0.35)),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.alarm_off_rounded,
                                color: Colors.orange),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Kesin alarm izni kapalı",
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Android 12+ cihazlarda günlük hatırlatmaların tam saatinde gelebilmesi için \"Alarmlar ve hatırlatıcılar\" iznini açman gerekiyor.",
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                      color: cs.onSurface
                                          .withOpacity(0.75),
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        await NotificationService
                                            .openExactAlarmSettings();
                                        await _loadNotif();
                                      },
                                      icon: const Icon(Icons.alarm_add_rounded),
                                      label: const Text("İzin ver"),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.orange,
                                        side: const BorderSide(
                                            color: Colors.orange),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ✅ Pil Optimizasyonu banner (Samsung / MIUI için kritik)
                    if (!_batteryOptIgnored)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: Colors.yellow.shade700.withOpacity(0.10),
                          border: Border.all(
                              color: Colors.yellow.shade700.withOpacity(0.40)),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.battery_alert_rounded,
                                color: Colors.yellow.shade800),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Pil optimizasyonu açık",
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Samsung ve bazı cihazlar arka planda uygulamayı kapatarak zamanlanmış bildirimleri engelliyor. Finansio'yu pil optimizasyonundan muaf tut.",
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                      color: cs.onSurface
                                          .withOpacity(0.75),
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        await NotificationService
                                            .requestIgnoreBatteryOptimization();
                                        await Future.delayed(
                                            const Duration(seconds: 1));
                                        await _loadNotif();
                                      },
                                      icon: const Icon(
                                          Icons.battery_charging_full_rounded),
                                      label: const Text("Muaf tut"),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                        Colors.yellow.shade800,
                                        side: BorderSide(
                                            color:
                                            Colors.yellow.shade700),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ✅ TEKRARLAYAN İŞLEMLER
                    _card(
                      theme,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                            theme: theme,
                            icon: Icons.repeat_rounded,
                            title: "Tekrarlayan İşlemler",
                            subtitle:
                            "Kira / abonelik / maaş gibi kurallar",
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.tune_rounded),
                            title: const Text(
                              "Kuralları yönet",
                              style:
                              TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              "Aylık kira, haftalık harçlık, yıllık abonelik…",
                              style:
                              _subtleSubtitle(theme, enabled: true),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _openRecurring,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // BİLDİRİMLER
                    _card(
                      theme,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                            theme: theme,
                            icon: Icons.notifications_outlined,
                            title: "Bildirimler",
                            subtitle: "Hatırlatma ve uyarıları yönet",
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _dailyEnabled,
                            title: const Text("Günlük hatırlatma"),
                            subtitle: Text(
                              _dailyEnabled
                                  ? "Her gün ${_fmtTime(_dailyTime)}"
                                  : "Kapalı",
                              style: _subtleSubtitle(theme,
                                  enabled: _dailyEnabled),
                            ),
                            onChanged: _toggleDaily,
                          ),
                          AnimatedOpacity(
                            opacity: _dailyEnabled ? 1.0 : 0.4,
                            duration: const Duration(milliseconds: 200),
                            child: IgnorePointer(
                              ignoring: !_dailyEnabled,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.schedule_outlined),
                                title: const Text("Hatırlatma saati"),
                                subtitle: Text(_fmtTime(_dailyTime)),
                                trailing: FilledButton.tonal(
                                  onPressed: _pickDailyTime,
                                  child: const Text("Değiştir"),
                                ),
                              ),
                            ),
                          ),
                          const Divider(height: 20),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                            value: _budgetEnabled,
                            title: const Text("Bütçe uyarıları"),
                            subtitle: Text(
                              "%80 uyarı ve limit aşımı",
                              style: _subtleSubtitle(theme,
                                  enabled: _budgetEnabled),
                            ),
                            onChanged: (v) async {
                              await NotificationService.setBudgetEnabled(v);
                              if (!mounted) return;
                              setState(() => _budgetEnabled = v);
                            },
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: const Icon(Icons.pie_chart_outline, color: Colors.blue),
                            value: _trendEnabled,
                            title: const Text("Trend / özet bildirimleri"),
                            subtitle: Text(
                              "Haftalık / dönem özetleri",
                              style: _subtleSubtitle(theme,
                                  enabled: _trendEnabled),
                            ),
                            onChanged: (v) async {
                              await NotificationService.setTrendEnabled(v);
                              if (!mounted) return;
                              setState(() => _trendEnabled = v);
                            },
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: const Icon(Icons.swap_vert, color: Colors.purple),
                            value: _categoryEnabled,
                            title: const Text("Kategori değişim uyarıları"),
                            subtitle: Text(
                              "Kategori artış/azalış uyarıları",
                              style: _subtleSubtitle(theme,
                                  enabled: _categoryEnabled),
                            ),
                            onChanged: (v) async {
                              await NotificationService.setCategoryEnabled(v);
                              if (!mounted) return;
                              setState(() => _categoryEnabled = v);
                            },
                          ),

                          // ✅ TEST BUTONLARI GİZLENDİ (Sadece Geliştirme Modunda Görünür)
                          if (kDebugMode) ...[
                            Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: Text(
                                  "Geliştirici Araçları 🛠️",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () async {
                                            await NotificationService.debugShowNow();
                                          },
                                          icon: const Icon(Icons.bug_report_outlined),
                                          label: const Text("Günlük test"),
                                        ),
                                        TextButton.icon(
                                          onPressed: () async {
                                            await NotificationService.debugWeeklySummaryNow();
                                          },
                                          icon: const Icon(Icons.bar_chart_outlined),
                                          label: const Text("Haftalık özet test"),
                                        ),
                                        TextButton.icon(
                                          onPressed: () async {
                                            await NotificationService.debugCategorySpikeNow();
                                          },
                                          icon: const Icon(Icons.calendar_month_outlined),
                                          label: const Text("Kategori tepe noktası test"),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // GÖRÜNÜM
                    _card(
                      theme,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                            theme: theme,
                            icon: Icons.palette_outlined,
                            title: "Görünüm",
                            subtitle: "Tema modunu seç",
                          ),
                          const SizedBox(height: 12),
                          RadioListTile<ThemeMode>(
                            value: ThemeMode.system,
                            groupValue: mode,
                            dense: true,
                            title: const Text("Sistem"),
                            subtitle: const Text("Telefon ayarına göre"),
                            onChanged: (val) {
                              if (val == null) return;
                              ref.read(themeModeProvider.notifier).setThemeMode(val);
                            },
                          ),
                          RadioListTile<ThemeMode>(
                            value: ThemeMode.light,
                            groupValue: mode,
                            dense: true,
                            title: const Text("Açık"),
                            onChanged: (val) {
                              if (val == null) return;
                              ref.read(themeModeProvider.notifier).setThemeMode(val);
                            },
                          ),
                          RadioListTile<ThemeMode>(
                            value: ThemeMode.dark,
                            groupValue: mode,
                            dense: true,
                            title: const Text("Koyu"),
                            onChanged: (val) {
                              if (val == null) return;
                              ref.read(themeModeProvider.notifier).setThemeMode(val);
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // VURGU RENGİ
                    _card(
                      theme,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                            theme: theme,
                            icon: Icons.color_lens_outlined,
                            title: "Vurgu Rengi",
                            subtitle: "Butonlar ve grafiklerde kullanılır",
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: AccentColorKey.values.map((key) {
                              final color = accentColorFromKey(key);
                              final selected = key == accentKey;

                              return InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: () => accentController.setAccent(key),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withOpacity(selected ? 0.40 : 0.10),
                                        blurRadius: selected ? 18 : 10,
                                        spreadRadius: -6,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: selected ? Colors.white : Colors.white.withOpacity(0.55),
                                      width: selected ? 2.4 : 1.2,
                                    ),
                                  ),
                                  child: selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ✅ YENİ KURUMSAL HAKKINDA KISMI
                    _card(
                      theme,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                            theme: theme,
                            icon: Icons.info_outline,
                            title: "Hakkında",
                            subtitle: "Finansio • Kişisel finans takibi",
                          ),
                          const SizedBox(height: 12),
                          Text("Versiyon: 1.0.0 (Build 1)", style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 12),
                          Text(
                            "Öneri ve görüşlerin uygulamayı daha iyi hale getirmemiz için çok önemli.",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withOpacity(0.75),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                                  );
                                },
                                icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                                label: const Text("Gizlilik Politikası"),
                              ),
                              OutlinedButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Bize ulaşın sayfası yakında eklenecek.")),
                                  );
                                },
                                icon: const Icon(Icons.mail_outline, size: 18),
                                label: const Text("Bize Ulaşın"),
                              ),
                              OutlinedButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Uygulama yayına alındığında aktif olacak.")),
                                  );
                                },
                                icon: const Icon(Icons.star_border_rounded, size: 18),
                                label: const Text("Değerlendir"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // DANGER ZONE
                    _card(
                      theme,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                            theme: theme,
                            icon: Icons.warning_amber_rounded,
                            title: "Danger Zone",
                            subtitle: "Geri alınamaz işlemler",
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _backupBusy ? null : _confirmAndResetAll,
                            icon: const Icon(Icons.delete_forever),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: cs.error,
                            ),
                            label: const Text("Tüm verileri sil"),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}