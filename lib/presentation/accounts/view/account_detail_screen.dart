import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/database/app_database.dart';
import '../../../domain/models/account.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../viewmodel/accounts_provider.dart';
import 'account_ui.dart';
import 'add_account_screen.dart';

class AccountDetailScreen extends ConsumerWidget {
  final AccountSummary account;
  const AccountDetailScreen({super.key, required this.account});

  String _fmt(double amount) {
    final f = NumberFormat("#,##0.##", "tr_TR");
    return '${f.format(amount)} ₺';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final color = AccountUi.hexToColor(account.colorHex);
    final txsAsync = ref.watch(accountTransactionsProvider(account.id));
    final transfersAsync = ref.watch(accountTransfersProvider(account.id));
    final dateFmt = DateFormat('dd.MM.yyyy');

    return AppScaffold(
      title: account.name,
      headerHeight: 205,
      surfaceTopSpacing: 112,
      actions: [
        IconButton(
          tooltip: "Düzenle",
          icon: const Icon(Icons.edit_outlined, color: Colors.white),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddAccountScreen(editing: account),
            ),
          ),
        ),
        const SizedBox(width: 4),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // Başlık kartı
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: color.withOpacity(isDark ? 0.20 : 0.12),
              border: Border.all(color: color.withOpacity(0.30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.22),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(AccountUi.iconFor(account),
                          color: color, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(account.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              )),
                          Text(account.type.label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  account.isCreditCard ? "Güncel Borç" : "Güncel Bakiye",
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  account.isCreditCard
                      ? _fmt(account.debt)
                      : _fmt(account.currentBalance),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: account.isCreditCard
                        ? (isDark ? Colors.red.shade400 : Colors.red)
                        : (account.currentBalance >= 0
                            ? Colors.green
                            : (isDark ? Colors.red.shade400 : Colors.red)),
                  ),
                ),
                if (account.isCreditCard) ...[
                  const SizedBox(height: 16),
                  _CreditDetails(account: account, format: _fmt),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Transferler
          Text("Transferler",
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          transfersAsync.when(
            data: (transfers) {
              if (transfers.isEmpty) {
                return _emptyRow(theme, "Bu hesaba ait transfer yok.");
              }
              return Column(
                children: transfers
                    .map((t) => _TransferTile(
                          transfer: t,
                          accountId: account.id,
                          format: _fmt,
                          dateFmt: dateFmt,
                        ))
                    .toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => Text('Hata: $e'),
          ),

          const SizedBox(height: 20),
          Text("İşlemler",
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          txsAsync.when(
            data: (txs) {
              if (txs.isEmpty) {
                return _emptyRow(theme, "Bu hesaba bağlı işlem yok.");
              }
              return Column(
                children: txs
                    .map((t) => _TxTile(tx: t, format: _fmt, dateFmt: dateFmt))
                    .toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => Text('Hata: $e'),
          ),
        ],
      ),
    );
  }

  Widget _emptyRow(ThemeData theme, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
  }
}

class _CreditDetails extends StatelessWidget {
  final AccountSummary account;
  final String Function(double) format;

  const _CreditDetails({required this.account, required this.format});

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
        if (account.creditLimit != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: util.clamp(0, 1),
              minHeight: 8,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(utilColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _kv(theme, "Kart Limiti", format(account.creditLimit!)),
              ),
              Expanded(
                child: _kv(theme, "Kalan Limit",
                    format(account.availableLimit ?? 0)),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: _kv(theme, "Bu Dönem Harcama",
                  format(account.periodSpent)),
            ),
            Expanded(
              child: _kv(
                theme,
                "Son Ödeme",
                account.dueDate != null
                    ? DateFormat('dd.MM.yyyy').format(account.dueDate!)
                    : '-',
                valueColor: account.isOverdue
                    ? Colors.red
                    : (account.isDueSoon ? Colors.orange : null),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _kv(ThemeData theme, String k, String v, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(v,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: valueColor,
            )),
      ],
    );
  }
}

class _TxTile extends StatelessWidget {
  final Tx tx;
  final String Function(double) format;
  final DateFormat dateFmt;

  const _TxTile({
    required this.tx,
    required this.format,
    required this.dateFmt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isIncome = tx.amount >= 0;
    final catColor = AccountUi.hexToColor(tx.category.colorHex);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.30),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: catColor.withOpacity(0.85),
            child: Text(
              tx.category.name.isNotEmpty
                  ? tx.category.name[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.category.name,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                if ((tx.note ?? '').isNotEmpty)
                  Text(tx.note!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _signed(tx.amount),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: isIncome
                      ? Colors.green
                      : (theme.brightness == Brightness.dark
                          ? Colors.red.shade400
                          : Colors.red),
                ),
              ),
              Text(dateFmt.format(tx.date.toLocal()),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  String _signed(double amount) {
    final f = NumberFormat("#,##0.##", "tr_TR");
    final sign = amount < 0 ? '-' : '+';
    return '$sign${f.format(amount.abs())} ₺';
  }
}

class _TransferTile extends StatelessWidget {
  final TransferItem transfer;
  final int accountId;
  final String Function(double) format;
  final DateFormat dateFmt;

  const _TransferTile({
    required this.transfer,
    required this.accountId,
    required this.format,
    required this.dateFmt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isOutgoing = transfer.fromAccountId == accountId;
    final other = isOutgoing ? transfer.toName : transfer.fromName;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.30),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: (isOutgoing ? Colors.orange : Colors.teal)
                .withOpacity(0.18),
            child: Icon(
              isOutgoing ? Icons.upload_outlined : Icons.download_outlined,
              size: 18,
              color: isOutgoing ? Colors.orange : Colors.teal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isOutgoing ? 'Gönderildi → $other' : 'Alındı ← $other',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                if ((transfer.note ?? '').isNotEmpty)
                  Text(transfer.note!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isOutgoing ? '-' : '+'}${format(transfer.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: isOutgoing ? Colors.orange : Colors.teal,
                ),
              ),
              Text(dateFmt.format(transfer.date.toLocal()),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}
