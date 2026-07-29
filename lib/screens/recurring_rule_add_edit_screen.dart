// lib/screens/recurring_rule_add_edit_screen.dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../providers/providers.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_header.dart';

class RecurringRuleAddEditScreen extends ConsumerStatefulWidget {
  final RecurringRule? editing;
  const RecurringRuleAddEditScreen({super.key, this.editing});

  @override
  ConsumerState<RecurringRuleAddEditScreen> createState() =>
      _RecurringRuleAddEditScreenState();
}

class _RecurringRuleAddEditScreenState
    extends ConsumerState<RecurringRuleAddEditScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _intervalCtrl = TextEditingController(text: "1");
  final _dayCtrl = TextEditingController();

  bool _isIncome = false;
  String _frequency = "monthly"; // daily / weekly / monthly
  DateTime _startDate = DateTime.now();
  bool _isActive = true;

  Category? _selectedCat;
  List<Category> _cats = [];

  bool _busy = false;
  bool _catsLoaded = false;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    _loadCatsAndInit();
  }

  Future<void> _loadCatsAndInit() async {
    try {
      final db = ref.read(dbProvider);
      final cats = await db.allCategories();

      if (!mounted) return;

      setState(() {
        _cats = cats;
        _catsLoaded = true;

        if (_isEdit) {
          final r = widget.editing!;
          _isIncome = r.isIncome;
          _amountCtrl.text = r.amount.toStringAsFixed(2);
          _noteCtrl.text = r.note ?? "";
          _frequency = r.frequency;
          _intervalCtrl.text = r.interval.toString();
          _dayCtrl.text = r.dayOfPeriod?.toString() ?? "";
          _startDate = r.startDate;
          _isActive = r.isActive;

          _selectedCat = cats.isNotEmpty
              ? cats.firstWhere(
                (c) => c.id == r.categoryId,
            orElse: () => cats.first,
          )
              : null;
        } else {
          _selectedCat = cats.isNotEmpty ? cats.first : null;

          // default day
          if (_frequency == "weekly" || _frequency == "monthly") {
            _dayCtrl.text = "1";
          }
        }

        // daily ise day boş kalsın
        if (_frequency == "daily") _dayCtrl.text = "";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _catsLoaded = true);
      _toast("Kategoriler yüklenemedi: $e");
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _intervalCtrl.dispose();
    _dayCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('tr', 'TR'),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _startDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _startDate.hour,
        _startDate.minute,
      );
    });
  }

  int _safeInt(String s, {int fallback = 1}) {
    final v = int.tryParse(s.trim());
    if (v == null) return fallback;
    return v;
  }

  Future<void> _save() async {
    if (_busy) return;

    if (_catsLoaded && _cats.isEmpty) {
      _toast("Önce en az 1 kategori eklemelisin.");
      return;
    }

    final cat = _selectedCat;

    final rawTxt = _amountCtrl.text.trim().replaceAll(',', '.');
    if (rawTxt.isEmpty) {
      _toast("Tutar boş olamaz.");
      return;
    }

    final amount = double.tryParse(rawTxt);
    if (amount == null || amount.isNaN || amount.isInfinite) {
      _toast("Geçerli bir tutar gir.");
      return;
    }
    if (amount <= 0) {
      _toast("Tutar 0'dan büyük olmalı.");
      return;
    }

    final intervalText = _intervalCtrl.text.trim();
    if (intervalText.isEmpty) {
      _toast("Interval boş olamaz.");
      return;
    }
    final interval = _safeInt(intervalText, fallback: 1);
    if (interval < 1) {
      _toast("Interval en az 1 olmalı.");
      return;
    }

    if (cat == null) {
      _toast("Kategori seçmelisin.");
      return;
    }

    // dayOfPeriod validation
    int? day;
    if (_frequency != "daily" && _dayCtrl.text.trim().isEmpty) {
      _toast("Gün alanı boş olamaz.");
      return;
    }

    if (_frequency == "weekly") {
      day = _safeInt(_dayCtrl.text, fallback: 1);
      if (day < 1 || day > 7) {
        _toast("Haftalık için gün 1..7 olmalı.");
        return;
      }
    } else if (_frequency == "monthly") {
      day = _safeInt(_dayCtrl.text, fallback: 1);
      if (day < 1 || day > 31) {
        _toast("Aylık için gün 1..31 olmalı.");
        return;
      }
    } else {
      day = null; // daily
    }

    setState(() => _busy = true);

    try {
      final db = ref.read(dbProvider);

      final noteTrim = _noteCtrl.text.trim();

      // ✅ tip-safe Value helpers (Drift)
      final Value<String?> noteValue = noteTrim.isEmpty
          ? const Value<String?>.absent()
          : Value<String?>(noteTrim);

      final Value<int?> dayValue =
      day == null ? const Value<int?>.absent() : Value<int?>(day);

      if (_isEdit) {
        final id = widget.editing!.id;

        await (db.update(db.recurringRules)..where((t) => t.id.equals(id)))
            .write(
          RecurringRulesCompanion(
            isIncome: Value(_isIncome),
            amount: Value(amount),
            categoryId: Value(cat.id),
            note: noteValue,
            frequency: Value(_frequency),
            interval: Value(interval),
            dayOfPeriod: dayValue,
            startDate: Value(_startDate),
            isActive: Value(_isActive),
          ),
        );
      } else {
        await db.into(db.recurringRules).insert(
          RecurringRulesCompanion.insert(
            isIncome: Value(_isIncome),
            amount: amount,
            categoryId: cat.id,
            note: noteValue,
            frequency: _frequency,
            interval: Value(interval),
            dayOfPeriod: dayValue,
            startDate: Value(_startDate),
            isActive: Value(_isActive),
          ),
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _toast("Kaydedilemedi: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (!_isEdit || _busy) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Kuralı sil"),
        content: const Text("Bu tekrarlayan kuralı silmek istiyor musun?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Vazgeç"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sil"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final db = ref.read(dbProvider);
      await (db.delete(db.recurringRules)
        ..where((t) => t.id.equals(widget.editing!.id)))
          .go();

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _toast("Silinemedi: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (!_catsLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final startText =
        "${_startDate.day.toString().padLeft(2, '0')}.${_startDate.month.toString().padLeft(2, '0')}.${_startDate.year}";

    return AppScaffold(
      title: _isEdit ? "Kuralı Düzenle" : "Kural Ekle",
      headerHeight: 220,
      surfaceTopSpacing: 120,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: AppHeader(
              title: _isEdit ? "Tekrarlayan Kural" : "Yeni Tekrarlayan Kural",
              subtitle: "Kira / abonelik / maaş gibi",
              trailing: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withOpacity(0.25),
                child: Icon(
                  _isIncome ? Icons.add : Icons.remove,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              onSurface: true,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (_cats.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cs.error.withOpacity(0.18)),
                    ),
                    child: Text(
                      "Kategori yok. Önce Kategoriler ekranından en az 1 kategori eklemelisin.",
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface.withOpacity(0.85),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Tür",
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Text("Gider"),
                                selected: !_isIncome,
                                onSelected: (_) =>
                                    setState(() => _isIncome = false),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ChoiceChip(
                                label: const Text("Gelir"),
                                selected: _isIncome,
                                onSelected: (_) => setState(() => _isIncome = true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _amountCtrl,
                          keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: "Tutar",
                            hintText: "0,00",
                            suffixText: "₺",
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<Category>(
                          value: _selectedCat,
                          items: _cats
                              .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.name),
                          ))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedCat = v),
                          decoration: const InputDecoration(labelText: "Kategori"),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _noteCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: "Not (opsiyonel)",
                            hintText: "Örn: Kira / Netflix / Maaş",
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Tekrar",
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: _frequency,
                          items: const [
                            DropdownMenuItem(value: "daily", child: Text("Günlük")),
                            DropdownMenuItem(value: "weekly", child: Text("Haftalık")),
                            DropdownMenuItem(value: "monthly", child: Text("Aylık")),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              _frequency = v;
                              if (v == "daily") {
                                _dayCtrl.text = "";
                              } else {
                                if (_dayCtrl.text.trim().isEmpty) {
                                  _dayCtrl.text = "1";
                                }
                              }
                            });
                          },
                          decoration: const InputDecoration(labelText: "Frekans"),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _intervalCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: "Interval",
                                  helperText: "örn: 1 ayda bir / 2 haftada bir",
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (_frequency != "daily")
                              Expanded(
                                child: TextFormField(
                                  controller: _dayCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: _frequency == "weekly"
                                        ? "Haftanın günü (1-7)"
                                        : "Ayın günü (1-31)",
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _isActive,
                          title: const Text("Aktif"),
                          subtitle: Text(_isActive ? "Kural çalışır" : "Kural devre dışı"),
                          onChanged: (v) => setState(() => _isActive = v),
                        ),
                        const Divider(height: 20),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text("Başlangıç tarihi"),
                          subtitle: Text(startText),
                          trailing: OutlinedButton.icon(
                            onPressed: _pickStartDate,
                            icon: const Icon(Icons.event_outlined),
                            label: const Text("Seç"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_isEdit)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _delete,
                          icon: Icon(Icons.delete_outline, color: cs.error),
                          label: Text("Sil", style: TextStyle(color: cs.error)),
                        ),
                      ),
                    if (_isEdit) const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _save,
                        icon: _busy
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Icon(Icons.check),
                        label: Text(
                          _busy
                              ? "Kaydediliyor..."
                              : (_isEdit ? "Güncelle" : "Kaydet"),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
