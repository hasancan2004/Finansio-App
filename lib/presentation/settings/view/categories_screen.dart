import 'package:finansio/data/database/app_database.dart';
import 'package:finansio/presentation/transactions/viewmodel/tx_providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/theme/app_surfaces.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Color _cardBg(ColorScheme cs) => AppSurfaces.cardFill(cs);
  BorderSide _cardBorder(ColorScheme cs) => AppSurfaces.cardBorder(cs);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Future<bool> _confirmDelete(Category c) async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Kategoriyi Sil"),
          content: Text(
            '"${c.name}" silinsin mi?\n\n'
                'Bu kategoriye bağlı işlemler varsa silme başarısız olabilir.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Vazgeç"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Sil"),
            ),
          ],
        ),
      );
      return ok ?? false;
    }

    Future<void> _deleteCategory(Category c) async {
      final ok = await _confirmDelete(c);
      if (!ok) return;

      try {
        await db.deleteCategory(c.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Silindi: ${c.name}")),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Silinemedi: $e"),
              backgroundColor: cs.error,
            ),
          );
        }
      }
    }

    return AppScaffold(
      title: "Kategoriler",
      headerHeight: 220,
      surfaceTopSpacing: 120,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showDialog(
            context: context,
            builder: (_) => const _CategoryDialog.add(),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: Stack(
        children: [
          // ✅ Hafif tint overlay (açık modda beyazı kırar)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      cs.primary.withOpacity(0.06),
                      cs.secondary.withOpacity(0.03),
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
                  title: "Kategoriler 🗂️",
                  subtitle: "Gelir / gider kayıtların için düzenli etiketler",
                  trailing: CircleAvatar(
                    radius: 18,
                    backgroundColor: cs.primary.withOpacity(0.16),
                    child: Icon(Icons.category, color: cs.primary, size: 18),
                  ),
                ),
              ),

              Expanded(
                child: StreamBuilder<List<Category>>(
                  stream: db.watchCategories(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final list = snap.data ?? const [];

                    if (list.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: EmptyState(
                          icon: Icons.category_outlined,
                          title: "Hiç kategori yok",
                          subtitle:
                          "Gelir ve giderlerini daha düzenli görmek için kategoriler oluştur.",
                          action: FilledButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text("İlk kategorini ekle"),
                            onPressed: () async {
                              await showDialog(
                                context: context,
                                builder: (_) => const _CategoryDialog.add(),
                              );
                            },
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final c = list[i];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Dismissible(
                            key: ValueKey('cat_${c.id}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              decoration: BoxDecoration(
                                color: cs.errorContainer.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(Icons.delete_outline, color: cs.error),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Sil",
                                    style: TextStyle(
                                      color: cs.error,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            confirmDismiss: (_) async => _confirmDelete(c),
                            onDismissed: (_) async => _deleteCategory(c),
                            child: Card(
                              color: _cardBg(cs),
                              elevation: 0,
                              shadowColor: cs.primary.withOpacity(0.12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                                side: _cardBorder(cs),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color:
                                    _hexToColor(c.colorHex).withOpacity(0.95),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.35),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  c.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                subtitle: Text(
                                  "Listelerde bu renkle gösterilecek.",
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurface.withOpacity(0.68),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),

                                // ✅ NEW: Kalem + Çöp butonu yan yana
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      tooltip: "Düzenle",
                                      onPressed: () async {
                                        await showDialog(
                                          context: context,
                                          builder: (_) => _CategoryDialog.edit(
                                            category: c,
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: cs.error,
                                      ),
                                      tooltip: "Sil",
                                      onPressed: () => _deleteCategory(c),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ekle/Düzenle Diyaloğu
class _CategoryDialog extends ConsumerStatefulWidget {
  final Category? category;
  const _CategoryDialog.add({super.key}) : category = null;
  const _CategoryDialog.edit({super.key, required this.category});

  @override
  ConsumerState<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends ConsumerState<_CategoryDialog> {
  final _nameCtrl = TextEditingController();
  late String _selectedHex;

  static const _palette = <String>[
    '#FF7043',
    '#42A5F5',
    '#AB47BC',
    '#66BB6A',
    '#FFA726',
    '#26C6DA',
    '#EC407A',
    '#7E57C2',
    '#26A69A',
    '#EF5350',
    '#8D6E63',
    '#78909C',
  ];

  bool get _isEdit => widget.category != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameCtrl.text = widget.category!.name;
      _selectedHex = widget.category!.colorHex;
    } else {
      _selectedHex = _palette.first;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final db = ref.read(dbProvider);
    final name = _nameCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("İsim boş olamaz")),
      );
      return;
    }

    final exists = await db.categoryNameExists(
      name,
      exceptId: _isEdit ? widget.category!.id : null,
    );
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$name" zaten var.')),
      );
      return;
    }

    try {
      if (_isEdit) {
        await db.updateCategory(
          id: widget.category!.id,
          name: name,
          colorHex: _selectedHex,
        );
      } else {
        await db.addCategory(
          name: name,
          colorHex: _selectedHex,
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Kaydedilemedi: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        _isEdit ? "Kategoriyi Düzenle" : "Kategori Ekle",
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: "İsim",
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Renk",
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurface.withOpacity(0.75),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _palette.map((hex) {
                final isSel = hex == _selectedHex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedHex = hex),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _hexToColor(hex),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSel ? cs.onSurface : cs.outlineVariant,
                        width: isSel ? 2 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Vazgeç"),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(_isEdit ? "Kaydet" : "Ekle"),
        ),
      ],
    );
  }
}

/// '#RRGGBB' → Color
Color _hexToColor(String hex) {
  final v = hex.replaceAll('#', '');
  final colorInt = int.parse(v, radix: 16) | 0xFF000000;
  return Color(colorInt);
}