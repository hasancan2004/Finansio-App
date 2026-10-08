// lib/presentation/portfolio/view/add_asset_screen.dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../transactions/viewmodel/tx_providers.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/theme/app_surfaces.dart';

class AddAssetScreen extends ConsumerStatefulWidget {
  final AssetItem? editing;
  const AddAssetScreen({super.key, this.editing});

  @override
  ConsumerState<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends ConsumerState<AddAssetScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _quantityCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _currentPriceCtrl;

  String _selectedType = 'GOLD';
  String _selectedColor = '#FFD700'; // Varsayılan Altın Sarısı

  final List<Map<String, String>> _assetTypes = [
    {'type': 'GOLD', 'label': 'Altın', 'icon': '🟡', 'color': '#FFD700'},
    {'type': 'USD', 'label': 'Dolar', 'icon': '💵', 'color': '#4CAF50'},
    {'type': 'EUR', 'label': 'Euro', 'icon': '💶', 'color': '#2196F3'},
    {'type': 'CRYPTO', 'label': 'Kripto', 'icon': '🪙', 'color': '#9C27B0'},
    {'type': 'STOCK', 'label': 'Hisse', 'icon': '📈', 'color': '#FF5722'},
    {'type': 'OTHER', 'label': 'Diğer', 'icon': '💎', 'color': '#607D8B'},
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _quantityCtrl = TextEditingController(text: e != null ? e.quantity.toString() : '');
    _priceCtrl = TextEditingController(text: e != null ? e.averagePrice.toString() : '');
    _currentPriceCtrl = TextEditingController(
        text: e?.currentPrice != null ? e!.currentPrice.toString() : '');

    if (e != null) {
      _selectedType = e.type;
      _selectedColor = e.colorHex;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _quantityCtrl.dispose();
    _priceCtrl.dispose();
    _currentPriceCtrl.dispose();
    super.dispose();
  }

  void _onTypeChanged(String type) {
    setState(() {
      _selectedType = type;
      // Otomatik renk ata
      _selectedColor = _assetTypes.firstWhere((t) => t['type'] == type)['color']!;

      // Eğer isim boşsa otomatik doldur
      if (_nameCtrl.text.trim().isEmpty) {
        _nameCtrl.text = _assetTypes.firstWhere((t) => t['type'] == type)['label']!;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    final qty = double.tryParse(_quantityCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final price = double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final currentPriceText = _currentPriceCtrl.text.trim().replaceAll(',', '.');
    final currentPrice = double.tryParse(currentPriceText);

    final db = ref.read(dbProvider);

    try {
      if (widget.editing == null) {
        // YENİ EKLE
        await db.addAsset(
          AssetsCompanion.insert(
            type: _selectedType,
            name: name,
            quantity: Value(qty),
            averagePrice: Value(price),
            currentPrice:
                currentPrice != null ? Value(currentPrice) : const Value.absent(),
            colorHex: Value(_selectedColor),
          ),
        );
      } else {
        // GÜNCELLE
        await db.updateAsset(
          id: widget.editing!.id,
          name: name,
          quantity: qty,
          averagePrice: price,
          currentPrice: currentPrice,
          clearCurrentPrice: currentPrice == null,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _delete() async {
    if (widget.editing == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Emin misin?"),
        content: const Text("Bu varlığı silmek istediğine emin misin? (İşlemler silinmez, sadece portföyden kalkar)"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("İptal")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Sil")),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(dbProvider).deleteAsset(widget.editing!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isEditing = widget.editing != null;

    return AppScaffold(
      title: isEditing ? "Varlığı Düzenle" : "Yeni Varlık",
      headerHeight: 200,
      surfaceTopSpacing: 110,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: AppHeader(
              title: isEditing ? "Düzenle ✍️" : "Yatırım Ekle 📈",
              subtitle: "Portföyüne varlık ekleyerek takibe başla",
            ),
          ),

          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                children: [
                  // Varlık Türü Seçimi
                  Text(
                    "Varlık Türü",
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _assetTypes.map((t) {
                      final isSel = _selectedType == t['type'];
                      return ChoiceChip(
                        label: Text("${t['icon']} ${t['label']}"),
                        selected: isSel,
                        onSelected: (_) => _onTypeChanged(t['type']!),
                        selectedColor: _hexToColor(t['color']!).withOpacity(0.2),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: isSel ? _hexToColor(t['color']!) : cs.onSurface,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Form Alanları (Cam/Kart Tasarımı)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppSurfaces.cardDecoration(cs),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: "Varlık Adı (Örn: Gram Altın, Binance BTC)",
                            prefixIcon: Icon(Icons.edit_note),
                          ),
                          validator: (v) => v == null || v.isEmpty ? "Lütfen bir isim girin" : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _quantityCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                                decoration: const InputDecoration(
                                  labelText: "Miktar",
                                  prefixIcon: Icon(Icons.scale_outlined),
                                  hintText: "15.5",
                                ),
                                validator: (v) => v == null || v.isEmpty ? "Miktar girin" : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _priceCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                                decoration: const InputDecoration(
                                  labelText: "Ort. Maliyet (₺)",
                                  prefixIcon: Icon(Icons.payments_outlined),
                                  hintText: "2850",
                                ),
                                validator: (v) => v == null || v.isEmpty ? "Maliyet girin" : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _currentPriceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                          decoration: const InputDecoration(
                            labelText: "Güncel Fiyat (₺) — İsteğe Bağlı",
                            prefixIcon: Icon(Icons.trending_up),
                            hintText: "Kâr/zarar için güncel fiyat gir",
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Kaydet Butonu
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check),
                      label: Text(
                        isEditing ? "Değişiklikleri Kaydet" : "Portföye Ekle",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),

                  // Sil Butonu (Sadece Düzenleme Modundaysa)
                  if (isEditing) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: _delete,
                        icon: Icon(Icons.delete_outline, color: cs.error),
                        label: Text(
                          "Bu Varlığı Sil",
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: cs.error),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: cs.error.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _hexToColor(String hex) {
    final v = hex.replaceAll('#', '');
    final colorInt = int.parse(v, radix: 16) | 0xFF000000;
    return Color(colorInt);
  }
}