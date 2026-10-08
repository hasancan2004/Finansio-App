import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/account.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/theme/app_surfaces.dart';
import '../viewmodel/accounts_provider.dart';
import 'account_ui.dart';

class AddAccountScreen extends ConsumerStatefulWidget {
  final AccountSummary? editing;
  const AddAccountScreen({super.key, this.editing});

  @override
  ConsumerState<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();

  AccountType _type = AccountType.cash;
  String _colorHex = '#22C55E';
  String _iconName = 'cash';
  int _statementDay = 15;
  int _dueDay = 25;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _type = e.type;
      _nameCtrl.text = e.name;
      final shownBalance =
          e.type.isCreditCard ? -e.initialBalance : e.initialBalance;
      _balanceCtrl.text =
          shownBalance != 0 ? shownBalance.toStringAsFixed(2) : '';
      _colorHex = e.colorHex;
      _iconName = e.iconName;
      _limitCtrl.text = e.creditLimit != null ? e.creditLimit!.toStringAsFixed(0) : '';
      _statementDay = e.statementDay ?? 15;
      _dueDay = e.dueDay ?? 25;
    } else {
      _applyTypeDefaults(_type);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  void _applyTypeDefaults(AccountType type) {
    switch (type) {
      case AccountType.cash:
        _colorHex = '#22C55E';
        _iconName = 'cash';
        break;
      case AccountType.bank:
        _colorHex = '#3B82F6';
        _iconName = 'bank';
        break;
      case AccountType.creditCard:
        _colorHex = '#8B5CF6';
        _iconName = 'card';
        break;
    }
  }

  void _onTypeChanged(AccountType type) {
    setState(() {
      _type = type;
      _applyTypeDefaults(type);
    });
  }

  double _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0.0;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(accountsControllerProvider);
    final name = _nameCtrl.text.trim();
    final rawBalance = _parse(_balanceCtrl);
    final initialBalance = _type.isCreditCard ? -rawBalance.abs() : rawBalance;
    final limit = _type.isCreditCard ? _parse(_limitCtrl) : null;

    try {
      if (_isEditing) {
        await controller.updateAccount(
          id: widget.editing!.id,
          name: name,
          type: _type,
          initialBalance: initialBalance,
          colorHex: _colorHex,
          iconName: _iconName,
          creditLimit: limit,
          statementDay: _statementDay,
          dueDay: _dueDay,
        );
      } else {
        await controller.addAccount(
          name: name,
          type: _type,
          initialBalance: initialBalance,
          colorHex: _colorHex,
          iconName: _iconName,
          creditLimit: limit,
          statementDay: _statementDay,
          dueDay: _dueDay,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _delete() async {
    final e = widget.editing;
    if (e == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hesabı sil"),
        content: Text(
          '"${e.name}" hesabını silmek istiyor musun?\n\n'
          'Bu hesaba bağlı işlemler silinmez; yalnızca hesap bağlantısı kaldırılır. '
          'Hesaba bağlı transferler ise silinir.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Vazgeç")),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sil"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(accountsControllerProvider).deleteAccount(e.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _toggleArchive() async {
    final e = widget.editing;
    if (e == null) return;
    await ref.read(accountsControllerProvider).setArchived(e.id, !e.isArchived);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AppScaffold(
      title: _isEditing ? "Hesabı Düzenle" : "Yeni Hesap",
      headerHeight: 205,
      surfaceTopSpacing: 112,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: AppHeader(
              title: _isEditing ? "Hesabı Düzenle ✍️" : "Hesap Ekle 💳",
              subtitle: "Nakit, banka veya kredi kartı tanımla",
            ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                children: [
                  // Hesap türü seçimi
                  Text("Hesap Türü",
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _TypeChip(
                        label: "Nakit",
                        icon: Icons.payments_outlined,
                        selected: _type == AccountType.cash,
                        color: const Color(0xFF22C55E),
                        onTap: () => _onTypeChanged(AccountType.cash),
                      ),
                      const SizedBox(width: 8),
                      _TypeChip(
                        label: "Banka",
                        icon: Icons.account_balance_outlined,
                        selected: _type == AccountType.bank,
                        color: const Color(0xFF3B82F6),
                        onTap: () => _onTypeChanged(AccountType.bank),
                      ),
                      const SizedBox(width: 8),
                      _TypeChip(
                        label: "Kredi Kartı",
                        icon: Icons.credit_card,
                        selected: _type == AccountType.creditCard,
                        color: const Color(0xFF8B5CF6),
                        onTap: () => _onTypeChanged(AccountType.creditCard),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppSurfaces.cardDecoration(cs),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: "Hesap Adı",
                            hintText: "Örn: Ziraat Vadesiz, Nakit Cüzdanım",
                            prefixIcon: Icon(Icons.edit_note),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty
                                  ? "Bir hesap adı girin"
                                  : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _balanceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]'))
                          ],
                          decoration: InputDecoration(
                            labelText: _type.isCreditCard
                                ? "Açılış Borcu (₺)"
                                : "Açılış Bakiyesi (₺)",
                            hintText: "0",
                            prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                          ),
                        ),
                        if (_type.isCreditCard) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _limitCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]'))
                            ],
                            decoration: const InputDecoration(
                              labelText: "Kart Limiti (₺)",
                              hintText: "50000",
                              prefixIcon: Icon(Icons.speed_outlined),
                            ),
                            validator: (v) {
                              if (!_type.isCreditCard) return null;
                              if (v == null || v.trim().isEmpty) {
                                return "Kart limiti girin";
                              }
                              if (_parse(_limitCtrl) <= 0) {
                                return "Geçerli bir limit girin";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _DayDropdown(
                                  label: "Kesim Günü",
                                  value: _statementDay,
                                  onChanged: (v) =>
                                      setState(() => _statementDay = v),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _DayDropdown(
                                  label: "Son Ödeme Günü",
                                  value: _dueDay,
                                  onChanged: (v) =>
                                      setState(() => _dueDay = v),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text("Renk",
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: AccountUi.colorPalette.map((hex) {
                      final c = AccountUi.hexToColor(hex);
                      final selected =
                          _colorHex.toUpperCase() == hex.toUpperCase();
                      return InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => setState(() => _colorHex = hex),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? cs.onSurface
                                  : Colors.transparent,
                              width: 2.4,
                            ),
                          ),
                          child: selected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check),
                      label: Text(
                        _isEditing ? "Değişiklikleri Kaydet" : "Hesabı Oluştur",
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),

                  if (_isEditing) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _toggleArchive,
                        icon: Icon(
                          widget.editing!.isArchived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                        ),
                        label: Text(
                          widget.editing!.isArchived
                              ? "Arşivden Çıkar"
                              : "Arşivle",
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _delete,
                        icon: Icon(Icons.delete_outline, color: cs.error),
                        label: Text(
                          "Hesabı Sil",
                          style: TextStyle(
                              fontWeight: FontWeight.w900, color: cs.error),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: cs.error.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.16) : cs.surfaceContainerHighest.withOpacity(0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : cs.outlineVariant.withOpacity(0.4),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? color : cs.onSurfaceVariant, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: selected ? color : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayDropdown extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _DayDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      value: value.clamp(1, 28),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      items: List.generate(28, (i) => i + 1)
          .map((d) => DropdownMenuItem(value: d, child: Text("$d")))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
