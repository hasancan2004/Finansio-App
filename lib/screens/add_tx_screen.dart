// lib/screens/add_tx_screen.dart
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:finansio/providers/forecast_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finansio/data/app_database.dart';
import 'package:finansio/providers/providers.dart';
import 'package:finansio/services/notification_service.dart';

import '../widgets/app_scaffold.dart';
import '../widgets/app_header.dart';

import 'package:finansio/providers/budget_providers.dart';

// ✅ AI
import 'package:finansio/ai/category_predictor.dart';
import 'package:finansio/ai/spending_analyzer.dart';

// ✅ learning
import 'package:finansio/utils/text_utils.dart';

class AddTxScreen extends ConsumerStatefulWidget {
  final Tx? editing;
  const AddTxScreen({super.key, this.editing});

  @override
  ConsumerState<AddTxScreen> createState() => _AddTxScreenState();
}

class _AddTxScreenState extends ConsumerState<AddTxScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  // ✅ AI auto-apply state
  bool _aiApplied = false;
  Category? _beforeAiCategory;

  Category? _selectedCat;
  List<Category> _cats = [];

  late DateTime _selectedDate;
  late bool _isIncome;

  bool get _isEdit => widget.editing != null;

  static const _prefLastCatId = "last_cat_id";
  static const _prefLastDateMs = "last_date_ms";

  // ✅ Category AI
  bool _userOverrodeCategory = false;
  CategoryPrediction? _lastPrediction;
  String? _aiDebugLine;

  // ✅ Learning state
  bool _usedPersonalOverride = false;
  List<String> _lastTokens = const [];

  // ✅ Anomaly AI
  AnomalyResult _anomaly = AnomalyResult.none;
  Timer? _anomalyDebounce;

  bool _saving = false;

  Color _cardBg(ColorScheme cs) => cs.primaryContainer.withOpacity(0.22);
  BorderSide _cardBorder(ColorScheme cs) =>
      BorderSide(color: cs.primary.withOpacity(0.10));

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _isIncome = true;

    _noteCtrl.addListener(_handleNoteChanged);
    _amountCtrl.addListener(_scheduleAnomalyCheck);

    ref.read(dbProvider).allCategories().then((value) async {
      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();

      setState(() {
        _cats = value;

        if (_isEdit) {
          final t = widget.editing!;
          _isIncome = t.amount >= 0;
          _amountCtrl.text = t.amount.abs().toStringAsFixed(2);
          _noteCtrl.text = t.note ?? '';
          _selectedDate = t.date;

          _selectedCat = value.isNotEmpty
              ? value.firstWhere(
                (c) => c.id == t.category.id,
            orElse: () => value.first,
          )
              : null;

          // Edit modunda otomatik öneri oynama
          _userOverrodeCategory = true;
        } else {
          Category? fromLastCat;
          final lastCatId = prefs.getInt(_prefLastCatId);
          if (lastCatId != null && value.any((c) => c.id == lastCatId)) {
            fromLastCat = value.firstWhere((c) => c.id == lastCatId);
          }

          final lastDateMs = prefs.getInt(_prefLastDateMs);
          final fromLastDate = lastDateMs != null
              ? DateTime.fromMillisecondsSinceEpoch(lastDateMs)
              : null;

          _selectedCat = fromLastCat ?? (value.isNotEmpty ? value.first : null);
          _selectedDate = fromLastDate ?? DateTime.now();
        }
      });

      _handleNoteChanged();
      _scheduleAnomalyCheck();
    });
  }
  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(m)));
  }
  // ---- normalize helper ----
  String _norm(String s) {
    var x = s.toLowerCase().trim();
    x = x
        .replaceAll("ı", "i")
        .replaceAll("ş", "s")
        .replaceAll("ğ", "g")
        .replaceAll("ç", "c")
        .replaceAll("ö", "o")
        .replaceAll("ü", "u");
    x = x.replaceAll(RegExp(r"[^a-z0-9\s]"), " ");
    x = x.replaceAll(RegExp(r"\s+"), " ").trim();
    return x;
  }

  Category? _findBestCategoryMatch(String predictedName) {
    if (_cats.isEmpty) return null;

    final p = _norm(predictedName);

    for (final c in _cats) {
      if (_norm(c.name) == p) return c;
    }

    for (final c in _cats) {
      final cn = _norm(c.name);
      if (cn.contains(p) || p.contains(cn)) return c;
    }

    final alias = <String, List<String>>{
      "market": ["gida", "alisveris", "bakkal"],
      "yeme icme": ["yemek", "restoran", "kafe"],
      "ulasim": ["yol", "taksi", "otobus", "metro", "benzin", "akaryakit"],
      "fatura": ["elektrik", "su", "dogalgaz", "internet", "telefon"],
      "eglence": ["sinema", "oyun", "spotify", "netflix"],
      "saglik": ["eczane", "doktor", "hastane", "ilac"],
    };

    String? group;
    final pn = _norm(predictedName);
    if (pn.isNotEmpty) {
      for (final e in alias.entries) {
        if (e.key == pn || e.key.contains(pn) || pn.contains(e.key)) {
          group = e.key;
          break;
        }
      }
    }

    if (group != null) {
      final keys = alias[group]!;
      for (final c in _cats) {
        final cn = _norm(c.name);
        if (cn == group) return c;
        if (keys.any((k) => cn.contains(k))) return c;
      }
    }

    return null;
  }

  Future<void> _applyPersonalOverrideIfAny(String note) async {
    final tokens = TextUtils.extractTokens(note);
    _lastTokens = tokens;

    if (tokens.isEmpty || _cats.isEmpty) {
      if (mounted) setState(() => _usedPersonalOverride = false);
      return;
    }

    final db = ref.read(dbProvider);
    final catId = await db.fetchBestOverrideCategoryId(tokens);

    if (!mounted) return;

    if (catId == null) {
      setState(() => _usedPersonalOverride = false);
      return;
    }

    final match = _cats.where((c) => c.id == catId).toList();
    if (match.isEmpty) {
      setState(() => _usedPersonalOverride = false);
      return;
    }

    if (!_userOverrodeCategory) {
      setState(() {
        _selectedCat = match.first;
        _usedPersonalOverride = true;

        // personal override varken aiApplied sayma
        _aiApplied = false;
        _beforeAiCategory = null;
      });
    } else {
      setState(() => _usedPersonalOverride = false);
    }
  }

  void _handleNoteChanged() {
    if (!mounted) return;

    if (_cats.isEmpty) {
      setState(() {
        _lastPrediction = null;
        _aiDebugLine = null;
        _usedPersonalOverride = false;
        _aiApplied = false;
        _beforeAiCategory = null;
      });
      return;
    }

    final note = _noteCtrl.text;

    // 1) personal override (async)
    _applyPersonalOverrideIfAny(note);

    // 2) normal predictor
    final pred = CategoryPredictor.predict(note);
    final match = _findBestCategoryMatch(pred.categoryName);

    // HIGH dışında otomatik seçme yok
    final canAutoApply = pred.level == PredictionConfidenceLevel.high;

    setState(() {
      _lastPrediction = pred;

      _aiDebugLine =
      "AI: '${pred.categoryName}' (%${(pred.confidence * 100).round()})  | match: ${match?.name ?? '-'}";

      // kullanıcı override ettiyse dokunma
      if (_userOverrodeCategory) return;

      // personal override varsa dokunma
      if (_usedPersonalOverride) return;

      if (match == null) {
        _aiApplied = false;
        _beforeAiCategory = null;
        return;
      }

      if (canAutoApply) {
        _beforeAiCategory ??= _selectedCat;
        _selectedCat = match;
        _aiApplied = true;
      } else {
        _aiApplied = false;
        _beforeAiCategory = null;
      }
    });

    _scheduleAnomalyCheck();
  }

  Future<void> _learnFromUserChoice(Category chosen) async {
    final note = _noteCtrl.text.trim();
    if (note.isEmpty) return;

    final tokens =
    _lastTokens.isNotEmpty ? _lastTokens : TextUtils.extractTokens(note);
    if (tokens.isEmpty) return;

    final db = ref.read(dbProvider);
    for (final t in tokens) {
      await db.learnCategoryOverride(token: t, categoryId: chosen.id);
    }
  }

  void _scheduleAnomalyCheck() {
    _anomalyDebounce?.cancel();
    _anomalyDebounce = Timer(const Duration(milliseconds: 350), () {
      _checkAnomalyAsync();
    });
  }

  Future<void> _checkAnomalyAsync() async {
    if (!mounted) return;

    final cat = _selectedCat;
    final rawTxt = _amountCtrl.text.trim().replaceAll(',', '.');
    final raw = double.tryParse(rawTxt) ?? 0.0;

    // gelirde anomali yok
    if (cat == null || raw <= 0 || _isIncome) {
      setState(() => _anomaly = AnomalyResult.none);
      return;
    }

    final db = ref.read(dbProvider);

    final end = DateTime.now();
    final start = end.subtract(const Duration(days: 90));

    // 1) Kategori bazlı history
    final catHistory = await db.fetchRecentExpenseAbsForCategory(
      categoryId: cat.id,
      start: start,
      end: end,
      limit: 200,
    );

    // 2) Kategori bazlı analiz
    var res = SpendingAnalyzer.detectCategoryExpenseAnomaly(
      pastAbsExpenses: catHistory,
      newAbsExpense: raw,
      categoryName: cat.name,
      minHistoryCount: 8,
      multiplier: 2.4,
      minAbs: 250.0,
    );

    // 3) kategori yetersizse global fallback
    if (!res.isAnomaly) {
      final globalHistory = await db.fetchRecentExpenseAbsGlobal(
        start: start,
        end: end,
        limit: 400,
      );

      res = SpendingAnalyzer.detectGlobalExpenseAnomaly(
        pastAbsExpenses: globalHistory,
        newAbsExpense: raw,
        minHistoryCount: 10,
        multiplier: 2.2,
        minAbs: 350.0,
      );
    }

    if (!mounted) return;
    setState(() => _anomaly = res);
  }

  Future<bool> _confirmIfAnomaly() async {
    if (!_anomaly.isAnomaly) return true;

    final med = _anomaly.median;
    final thr = _anomaly.threshold;

    final detail = [
      "Genel harcama alışkanlıklarına göre bu tutar olağandışı görünüyor.",
      if (med != null) "Tipik harcama (median): ${med.toStringAsFixed(0)} ₺",
      if (thr != null) "Uyarı eşiği: ${thr.toStringAsFixed(0)} ₺",
    ].join("\n");

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _anomaly.title.isEmpty ? "Olağandışı harcama" : _anomaly.title,
        ),
        content: Text("${_anomaly.message}\n\n$detail\n\nYine de kaydedelim mi?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Düzenle"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Yine de kaydet"),
          ),
        ],
      ),
    );

    return ok ?? false;
  }

  @override
  void dispose() {
    _anomalyDebounce?.cancel();
    _amountCtrl.removeListener(_scheduleAnomalyCheck);
    _noteCtrl.removeListener(_handleNoteChanged);

    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final initialDate = _selectedDate;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('tr', 'TR'),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );

    setState(() {
      if (pickedTime == null) {
        _selectedDate = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          initialDate.hour,
          initialDate.minute,
        );
      } else {
        _selectedDate = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      }
    });
  }

  Future<void> _onSave() async {
    if (_saving) return;  // ✅ double submit engel
    setState(() => _saving = true);

    FocusScope.of(context).unfocus();

    try {
      final cat = _selectedCat;
      if (cat == null) {
        _snack("Kategori seç.");
        return;
      }

      final rawTxt = _amountCtrl.text.trim().replaceAll(",", ".");

      if (rawTxt.isEmpty) {
        _snack("Tutar boş olamaz");
        return;
      }

      final raw = double.tryParse(rawTxt);
      if (raw == null || raw.isNaN || raw.isInfinite) {
        _snack("Geçerli bir tutar gir.");
        return;
      }

      if (raw <= 0) {
        _snack("Tutar 0'dan büyük olmalı.");
        return;
      }

      // aşırı büyük değerleri engelle (opsiyonel ama iyi)
      if (raw > 999999999) {
        _snack("Tutar çok büyük");
        return;
      }

      final ok = await _confirmIfAnomaly();
      if (!ok) return;

      final amount = _isIncome ? raw : -raw;
      final noteTrim = _noteCtrl.text.trim();
      final noteValue = noteTrim.isEmpty ? const Value<String?>.absent() : Value(noteTrim);

      final db = ref.read(dbProvider);

      if (_isEdit) {
        await db.updateTransaction(
          id: widget.editing!.id,
          amount: amount,
          categoryId: cat.id,
          note: noteTrim.isEmpty ? null : noteTrim,
          date: _selectedDate,
        );
      } else {
        await db.addTransaction(
          TransactionsCompanion.insert(
            amount: amount,
            categoryId: cat.id,
            note: noteValue,
            date: Value(_selectedDate),
          ),
        );
      }

      // refresh
      ref.invalidate(txStreamProvider);
      ref.invalidate(summaryProvider);
      ref.invalidate(budgetStatusesProvider);
      ref.invalidate(globalLimitStatusProvider);
      ref.invalidate(forecastProvider);

      // prefs bile patlasa app çökmesin
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_prefLastCatId, cat.id);
        await prefs.setInt(_prefLastDateMs, _selectedDate.millisecondsSinceEpoch);
      } catch (_) {
        //ignore
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _snack("Kaydetme başarısız: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _sectionTitle(BuildContext context, String title, {IconData? icon}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.primary.withOpacity(0.12)),
            ),
            child: Icon(icon, color: cs.primary, size: 20),
          ),
          const SizedBox(width: 10),
        ],
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dateFmt = DateFormat('dd.MM.yyyy HH:mm');

    final isReady = _selectedCat != null || _cats.isEmpty;
    if (!isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return AppScaffold(
      title: _isEdit ? "İşlemi Düzenle" : "İşlem Ekle",
      headerHeight: 230,
      surfaceTopSpacing: 125,
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: AppHeader(
                  title: _isEdit ? "İşlemi Düzenle" : "Yeni İşlem",
                  subtitle: _isIncome
                      ? "Gelir kaydı oluşturuyorsun"
                      : "Gider kaydı • bütçe uyarısı + anomali kontrolü",
                  trailing: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white.withOpacity(0.25),
                    child: Icon(
                      _isIncome ? Icons.add : Icons.remove,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                  children: [
                    Card(
                      color: _cardBg(cs),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: _cardBorder(cs),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(context, "Tutar",
                                icon: Icons.payments_outlined),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _amountCtrl,
                                    keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                    decoration: InputDecoration(
                                      hintText: '0,00',
                                      suffixText: '₺',
                                      filled: true,
                                      fillColor:
                                      cs.surfaceVariant.withOpacity(0.25),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _IncomeExpenseToggle(
                                  isIncome: _isIncome,
                                  onChanged: (v) {
                                    setState(() => _isIncome = v);
                                    _scheduleAnomalyCheck();
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Divider(height: 20),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.event_outlined),
                              title: const Text('Tarih / Saat'),
                              subtitle: Text(dateFmt.format(_selectedDate)),
                              trailing: OutlinedButton.icon(
                                onPressed: _pickDateTime,
                                icon: const Icon(Icons.edit_calendar_outlined,
                                    size: 18),
                                label: const Text('Seç'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: _cardBg(cs),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: _cardBorder(cs),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(context, "Detay",
                                icon: Icons.category_outlined),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<Category>(
                              value: _selectedCat,
                              isExpanded: true,
                              items: _cats
                                  .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.name),
                              ))
                                  .toList(),
                              onChanged: (v) async {
                                if (v == null) return;

                                final aiHadPrediction = _lastPrediction != null;

                                setState(() {
                                  _selectedCat = v;
                                  _userOverrodeCategory = true;

                                  // ✅ kullanıcı seçtiyse AI auto state sıfırla
                                  _aiApplied = false;
                                  _beforeAiCategory = null;
                                });

                                await _learnFromUserChoice(v);

                                if (!mounted) return;

                                if (aiHadPrediction) {
                                  ScaffoldMessenger.of(context)
                                    ..clearSnackBars()
                                    ..showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            "Öğrendim ✅ (bir dahakine daha iyi tahmin edeceğim)"),
                                        duration: Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                }

                                _scheduleAnomalyCheck();
                              },
                              decoration: InputDecoration(
                                labelText: 'Kategori',
                                filled: true,
                                fillColor:
                                cs.surfaceVariant.withOpacity(0.25),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),

                            // ✅ personal override banner
                            if (_usedPersonalOverride && !_userOverrodeCategory)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Row(
                                  children: [
                                    Icon(Icons.person_pin,
                                        size: 18, color: cs.primary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Kişisel öneri uygulandı (öğrenilmiş).",
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: cs.onSurface.withOpacity(0.75),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // ✅ Medium/Low AI suggestion banner (otomatik seçmez)
                            if (!_usedPersonalOverride &&
                                !_userOverrodeCategory &&
                                _lastPrediction != null &&
                                _lastPrediction!.confidence > 0 &&
                                _lastPrediction!.level !=
                                    PredictionConfidenceLevel.high)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceVariant.withOpacity(0.35),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: cs.outlineVariant.withOpacity(0.25),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.lightbulb_outline,
                                          size: 18, color: cs.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "AI önerisi: ${_lastPrediction!.categoryName} (%${(_lastPrediction!.confidence * 100).round()})",
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color:
                                            cs.onSurface.withOpacity(0.8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _noteCtrl,
                              decoration: InputDecoration(
                                labelText: 'Not (opsiyonel)',
                                hintText: 'Örn: A101 240 / Burger King 190',
                                filled: true,
                                fillColor:
                                cs.surfaceVariant.withOpacity(0.25),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // bottom button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  icon: _saving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2,),
                  )
                      : Icon(_isEdit ? Icons.save : Icons.check),
                  label: Text(_saving ? "Kaydediliyor..." : (_isEdit ? "Güncelle": "Kaydet")),
                  onPressed: _saving ? null : _onSave,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomeExpenseToggle extends StatelessWidget {
  final bool isIncome;
  final ValueChanged<bool> onChanged;

  const _IncomeExpenseToggle({
    required this.isIncome,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.surfaceVariant.withOpacity(0.22);
    final border = cs.outlineVariant.withOpacity(0.28);

    Widget btn({
      required bool incomeBtn,
      required IconData icon,
    }) {
      final selected = isIncome == incomeBtn;
      final Color selColor = incomeBtn ? Colors.green : Colors.red;
      final Color selBg = selColor.withOpacity(0.18);

      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged(incomeBtn),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? selBg : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? selColor.withOpacity(0.45) : Colors.transparent,
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: selected ? selColor : cs.onSurface.withOpacity(0.75),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 112,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          btn(incomeBtn: true, icon: Icons.add),
          const SizedBox(width: 4),
          btn(incomeBtn: false, icon: Icons.remove),
        ],
      ),
    );
  }
}
