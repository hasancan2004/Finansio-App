import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/notification_listener_service.dart';
import '../../../data/services/transaction_capture_service.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/app_scaffold.dart';

class NotificationCaptureScreen extends ConsumerStatefulWidget {
  const NotificationCaptureScreen({super.key});

  @override
  ConsumerState<NotificationCaptureScreen> createState() =>
      _NotificationCaptureScreenState();
}

class _NotificationCaptureScreenState
    extends ConsumerState<NotificationCaptureScreen> {
  bool _enabled = false;
  bool _listenerEnabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await TransactionCaptureService.isEnabled();
    final listenerEnabled = await NotificationListenerService.isEnabled();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _listenerEnabled = listenerEnabled;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    await TransactionCaptureService.setEnabled(value);
    if (!mounted) return;
    setState(() => _enabled = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AppScaffold(
      title: "Otomatik İşlem",
      headerHeight: 215,
      surfaceTopSpacing: 118,
      actions: [
        IconButton(
          tooltip: "Yenile",
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _load,
        ),
        const SizedBox(width: 4),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: AppHeader(
              title: "Akıllı Yakalama 🔔",
              subtitle: "Banka bildirimlerinden işlemleri otomatik oluştur",
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: cs.surfaceContainerHighest.withOpacity(0.35),
                          border:
                              Border.all(color: cs.outlineVariant.withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _enabled,
                              title: const Text(
                                'Bildirimden işlem yakala',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              subtitle: Text(
                                'Bankadan gelen harcama/para bildirimlerini algılayıp işleme dönüştürür.',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                              onChanged: _toggle,
                            ),
                            const Divider(height: 20),
                            Row(
                              children: [
                                Icon(
                                  _listenerEnabled
                                      ? Icons.check_circle
                                      : Icons.error_outline,
                                  size: 18,
                                  color: _listenerEnabled
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _listenerEnabled
                                        ? 'Bildirim erişimi verilmiş.'
                                        : 'Bildirim erişimi henüz verilmemiş.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_enabled && !_listenerEnabled) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: Colors.orange.withOpacity(0.12),
                            border: Border.all(
                                color: Colors.orange.withOpacity(0.35)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Önce erişim izni vermelisin',
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Finansio\'nun bildirimleri okuyabilmesi için sistem ayarlarından "Finansio İşlem Yakalayıcı" seçeneğini etkinleştir.',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: FilledButton.icon(
                                  onPressed: () async {
                                    await NotificationListenerService
                                        .openSettings();
                                    await Future.delayed(
                                        const Duration(milliseconds: 500));
                                    await _load();
                                  },
                                  icon: const Icon(Icons.settings),
                                  label: const Text('Bildirim erişimini aç'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Not: Algılanan her bildirim için sana bir onay penceresi açılır; işlemi sen onaylarsan kaydeder. '
                        'Yanlış eşleşmeleri bu sayede engelleyebilirsin.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
