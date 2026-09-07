import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finansio/data/database/app_database.dart';
import 'package:finansio/presentation/shared/theme/app_surfaces.dart';
import 'package:finansio/presentation/transactions/viewmodel/tx_providers.dart';

class TxFilterSheet extends ConsumerStatefulWidget {
  const TxFilterSheet({super.key});

  @override
  ConsumerState<TxFilterSheet> createState() => _TxFilterSheetState();
}

class _TxFilterSheetState extends ConsumerState<TxFilterSheet> {
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();

  int? _selectedCategoryId;
  List<Category> _cats = [];

  @override
  void initState() {
    super.initState();

    _selectedCategoryId = ref.read(categoryIdFilterProvider);

    final minA = ref.read(minAmountFilterProvider);
    final maxA = ref.read(maxAmountFilterProvider);
    if (minA != null) _minCtrl.text = minA.toString();
    if (maxA != null) _maxCtrl.text = maxA.toString();

    ref.read(dbProvider).allCategories().then((value) {
      if (!mounted) return;
      setState(() => _cats = value);
    });
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  double? _toDouble(String s) {
    final v = s.trim().replaceAll(',', '.');
    if (v.isEmpty) return null;
    return double.tryParse(v);
  }

  void _apply() {
    ref.read(categoryIdFilterProvider.notifier).state = _selectedCategoryId;
    ref.read(minAmountFilterProvider.notifier).state = _toDouble(_minCtrl.text);
    ref.read(maxAmountFilterProvider.notifier).state = _toDouble(_maxCtrl.text);
    Navigator.pop(context);
  }

  void _clear() {
    setState(() {
      _selectedCategoryId = null;
      _minCtrl.clear();
      _maxCtrl.clear();
    });
    ref.read(txFilterProvider.notifier).state = FilterRange.thisMonth;
    ref.read(categoryIdFilterProvider.notifier).state = null;
    ref.read(minAmountFilterProvider.notifier).state = null;
    ref.read(maxAmountFilterProvider.notifier).state = null;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final range = ref.watch(txFilterProvider);

    final sheetDecoration = AppSurfaces.sheetDecoration(cs);
    final fieldFill = AppSurfaces.cardFill(cs);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          10,
          12,
          12 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: sheetDecoration.copyWith(
              borderRadius: BorderRadius.circular(22),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Handle
                        Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Title row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: cs.primary.withOpacity(0.12),
                                ),
                              ),
                              child: Icon(Icons.tune, color: cs.primary, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Filtreler',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _clear,
                              icon: const Icon(Icons.clear_all),
                              label: const Text('Temizle'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Quick range chips
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              _chip(
                                context,
                                label: 'Tümü',
                                selected: range == FilterRange.all,
                                onTap: () => ref
                                    .read(txFilterProvider.notifier)
                                    .state = FilterRange.all,
                              ),
                              _chip(
                                context,
                                label: 'Bu Ay',
                                selected: range == FilterRange.thisMonth,
                                onTap: () => ref
                                    .read(txFilterProvider.notifier)
                                    .state = FilterRange.thisMonth,
                              ),
                              _chip(
                                context,
                                label: 'Geçen Ay',
                                selected: range == FilterRange.lastMonth,
                                onTap: () => ref
                                    .read(txFilterProvider.notifier)
                                    .state = FilterRange.lastMonth,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),
                        Divider(height: 16, color: cs.outlineVariant.withOpacity(0.35)),
                        const SizedBox(height: 6),

                        // Category dropdown
                        DropdownButtonFormField<int?>(
                          value: _selectedCategoryId,
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Tüm Kategoriler'),
                            ),
                            ..._cats.map(
                                  (c) => DropdownMenuItem<int?>(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => _selectedCategoryId = v),
                          decoration: InputDecoration(
                            labelText: 'Kategori',
                            filled: true,
                            fillColor: fieldFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Min / Max
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _minCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Min tutar',
                                  hintText: 'Örn: -100',
                                  filled: true,
                                  fillColor: fieldFill,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _maxCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Max tutar',
                                  hintText: 'Örn: 1000',
                                  filled: true,
                                  fillColor: fieldFill,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Apply button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _apply,
                            icon: const Icon(Icons.check),
                            label: const Text('Uygula'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(
      BuildContext context, {
        required String label,
        required bool selected,
        required VoidCallback onTap,
      }) {
    final cs = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: selected ? cs.onPrimary : cs.primary,
        ),
      ),
      selected: selected,
      selectedColor: cs.primary.withOpacity(0.92),
      backgroundColor: AppSurfaces.cardFill(cs),
      onSelected: (_) => onTap(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      side: BorderSide(
        color: selected
            ? cs.primary.withOpacity(0.22)
            : cs.outlineVariant.withOpacity(0.30),
      ),
    );
  }
}
