import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/account.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/theme/app_surfaces.dart';
import '../viewmodel/accounts_provider.dart';
import 'account_ui.dart';

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  int? _fromId;
  int? _toId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_saving) return;

    final from = _fromId;
    final to = _toId;
    final amount = double.tryParse(_amountCtrl.text.trim().replaceAll(',', '.')) ?? 0;

    if (from == null || to == null) {
      _snack("Lütfen kaynak ve hedef hesabı seç.");
      return;
    }
    if (from == to) {
      _snack("Kaynak ve hedef hesap aynı olamaz.");
      return;
    }
    if (amount <= 0) {
      _snack("Geçerli bir tutar gir.");
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(accountsControllerProvider).addTransfer(
            fromAccountId: from,
            toAccountId: to,
            amount: amount,
            date: _date,
            note: _noteCtrl.text,
          );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _snack("Transfer başarısız: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accountsAsync = ref.watch(accountsStreamProvider);

    return AppScaffold(
      title: "Para Transferi",
      headerHeight: 215,
      surfaceTopSpacing: 118,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: AppHeader(
              title: "Hesaplar Arası Transfer 🔁",
              subtitle: "Gelir-gideri bozmadan hesaplar arasında bakiye taşı",
            ),
          ),
          Expanded(
            child: accountsAsync.when(
              data: (all) {
                final accounts =
                    all.where((a) => !a.isArchived).toList(growable: false);
                if (accounts.length < 2) {
                  return _InsufficientAccounts(accounts: accounts);
                }

                final fromId = _fromId ?? accounts.first.id;
                final toId = _toId ??
                    (accounts.length > 1 && accounts[1].id != fromId
                        ? accounts[1].id
                        : accounts.firstWhere((a) => a.id != fromId,
                            orElse: () => accounts.first).id);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppSurfaces.cardDecoration(cs),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _AccountDropdown(
                            label: "Kimden (Kaynak)",
                            accounts: accounts,
                            value: fromId,
                            icon: Icons.upload_outlined,
                            onChanged: (v) => setState(() => _fromId = v),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Icon(Icons.arrow_downward,
                                color: cs.primary, size: 26),
                          ),
                          const SizedBox(height: 8),
                          _AccountDropdown(
                            label: "Kime (Hedef)",
                            accounts: accounts,
                            value: toId,
                            icon: Icons.download_outlined,
                            onChanged: (v) => setState(() => _toId = v),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: _amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]'))
                            ],
                            decoration: InputDecoration(
                              labelText: "Tutar (₺)",
                              prefixIcon:
                                  const Icon(Icons.payments_outlined),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(14),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: "Tarih",
                                prefixIcon:
                                    const Icon(Icons.calendar_today_outlined),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text(
                                  DateFormat('dd.MM.yyyy').format(_date)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _noteCtrl,
                            decoration: InputDecoration(
                              labelText: "Not (opsiyonel)",
                              hintText: "Örn: ATM'den nakit çekme",
                              prefixIcon: const Icon(Icons.notes_outlined),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.swap_horiz),
                        label: Text(
                          _saving ? "Aktarılıyor..." : "Transferi Gerçekleştir",
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
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

class _AccountDropdown extends StatelessWidget {
  final String label;
  final List<AccountSummary> accounts;
  final int value;
  final IconData icon;
  final ValueChanged<int> onChanged;

  const _AccountDropdown({
    required this.label,
    required this.accounts,
    required this.value,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      value: accounts.any((a) => a.id == value) ? value : accounts.first.id,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      items: accounts
          .map((a) => DropdownMenuItem(
                value: a.id,
                child: Row(
                  children: [
                    Icon(AccountUi.iconFor(a),
                        size: 18, color: AccountUi.hexToColor(a.colorHex)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(a.name, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _InsufficientAccounts extends StatelessWidget {
  final List<AccountSummary> accounts;
  const _InsufficientAccounts({required this.accounts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz,
                size: 72, color: theme.colorScheme.primary.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              accounts.isEmpty
                  ? "Önce hesap eklemelisin"
                  : "Transfer için en az 2 hesap gerekli",
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              "Hesaplar arası para aktarımı yapabilmek için en az iki farklı hesabın olmalı.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
