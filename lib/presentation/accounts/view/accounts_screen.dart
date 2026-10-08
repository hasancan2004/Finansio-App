import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/account.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/empty_state.dart';
import '../viewmodel/accounts_provider.dart';
import 'account_detail_screen.dart';
import 'account_ui.dart';
import 'add_account_screen.dart';
import 'transfer_screen.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  String _fmt(double amount) {
    final f = NumberFormat("#,##0.##", "tr_TR");
    return '${f.format(amount)} ₺';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final summary = ref.watch(accountsSummaryProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AppScaffold(
      title: "Hesaplarım",
      headerHeight: 215,
      surfaceTopSpacing: 118,
      actions: [
        IconButton(
          tooltip: "Hesaplar arası transfer",
          icon: const Icon(Icons.swap_horiz, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TransferScreen()),
            );
          },
        ),
        const SizedBox(width: 4),
      ],
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addAccountFab',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddAccountScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text("Hesap Ekle", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: AppHeader(
              title: "Cüzdanlarım 💳",
              subtitle: "Nakit, banka ve kredi kartlarını tek yerden yönet",
              trailing: CircleAvatar(
                radius: 18,
                backgroundColor: cs.primary.withOpacity(0.16),
                child: Icon(Icons.account_balance_wallet_outlined, color: cs.primary),
              ),
            ),
          ),
          Expanded(
            child: accountsAsync.when(
              data: (accounts) {
                if (accounts.isEmpty) {
                  return EmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: "Henüz hesap yok",
                    subtitle:
                        "Nakit cüzdanı, banka hesabı veya kredi kartı ekleyerek bakiye takibine başla.",
                    action: FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AddAccountScreen()),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text("İlk hesabı ekle"),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  children: [
                    _SummaryCard(
                      summary: summary,
                      format: _fmt,
                    ),
                    const SizedBox(height: 16),
                    ...accounts.map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _AccountCard(
                            account: a,
                            format: _fmt,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AccountDetailScreen(account: a),
                              ),
                            ),
                            onEdit: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AddAccountScreen(editing: a),
                              ),
                            ),
                          ),
                        )),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Hata: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final AccountsSummary summary;
  final String Function(double) format;

  const _SummaryCard({required this.summary, required this.format});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: cs.surfaceContainerHighest.withOpacity(0.35),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Toplam Net Değer",
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurfaceVariant,
              )),
          const SizedBox(height: 4),
          Text(
            format(summary.netWorth),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: summary.netWorth >= 0 ? Colors.green : cs.error,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: "Varlıklar",
                  value: format(summary.assets),
                  color: Colors.blue,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: "Kart Borcu",
                  value: format(summary.cardDebt),
                  color: Colors.red,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: color,
                )),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final AccountSummary account;
  final String Function(double) format;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _AccountCard({
    required this.account,
    required this.format,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final color = AccountUi.hexToColor(account.colorHex);
    final icon = AccountUi.iconFor(account);

    return Opacity(
      opacity: account.isArchived ? 0.55 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: cs.surfaceContainerHighest.withOpacity(0.35),
              border: Border.all(
                color: account.isCreditCard
                    ? Colors.red.withOpacity(0.25)
                    : color.withOpacity(0.30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  account.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (account.isArchived) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.inventory_2_outlined,
                                    size: 14, color: cs.onSurfaceVariant),
                              ],
                            ],
                          ),
                          Text(
                            account.type.label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onEdit,
                      icon: Icon(Icons.edit_outlined, color: cs.onSurfaceVariant),
                      tooltip: 'Düzenle',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (account.isCreditCard)
                  _CreditCardInfo(account: account, format: format, isDark: isDark)
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Güncel Bakiye",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          )),
                      Text(
                        format(account.currentBalance),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: account.currentBalance >= 0
                              ? Colors.green
                              : (isDark ? Colors.red.shade400 : Colors.red),
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
}

class _CreditCardInfo extends StatelessWidget {
  final AccountSummary account;
  final String Function(double) format;
  final bool isDark;

  const _CreditCardInfo({
    required this.account,
    required this.format,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final util = account.utilization ?? 0;
    final utilColor = util >= 0.9
        ? Colors.red
        : (util >= 0.7 ? Colors.orange : Colors.green);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Kart Borcu",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                )),
            Text(
              format(account.debt),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.red.shade400 : Colors.red,
              ),
            ),
          ],
        ),
        if (account.creditLimit != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: util.clamp(0, 1),
              minHeight: 8,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(utilColor),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Kalan limit: ${format(account.availableLimit ?? 0)}",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                "Limit: ${format(account.creditLimit!)}",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Pill(
                icon: Icons.receipt_long_outlined,
                label: "Bu dönem",
                value: format(account.periodSpent),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Pill(
                icon: account.isOverdue
                    ? Icons.error_outline
                    : Icons.event_available_outlined,
                label: "Son ödeme",
                value: account.dueDate != null
                    ? DateFormat('dd.MM.yyyy').format(account.dueDate!)
                    : '-',
                highlight: account.isDueSoon || account.isOverdue,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  const _Pill({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = highlight ? Colors.orange : cs.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: cs.onSurfaceVariant,
                    )),
                Text(value,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
