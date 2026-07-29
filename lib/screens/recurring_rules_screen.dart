// lib/screens/recurring_rules_screen.dart
import 'package:drift/drift.dart' show Value, OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/app_database.dart';
import '../providers/providers.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_header.dart';

// ✅ NEW: Add/Edit screen import
import 'recurring_rule_add_edit_screen.dart';

class RecurringRulesScreen extends ConsumerWidget {
  const RecurringRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(dbProvider);

    Future<void> openAdd() async {
      final res = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const RecurringRuleAddEditScreen()),
      );

      if (res == true && context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text("Kural kaydedildi ✅"),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
      }
    }

    Future<void> openEdit(RecurringRule r) async {
      final res = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => RecurringRuleAddEditScreen(editing: r),
        ),
      );

      if (res == true && context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text("Kural güncellendi ✅"),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
      }
    }

    final fmt = DateFormat('dd.MM.yyyy');

    return AppScaffold(
      title: "Tekrarlayan İşlemler",
      headerHeight: 220,
      surfaceTopSpacing: 120,
      floatingActionButton: FloatingActionButton(
        onPressed: openAdd,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: AppHeader(
              title: "Tekrarlayan İşlemler 🔁",
              subtitle: "Kira / abonelik / maaş gibi kuralları yönet",
              onSurface: true,
            ),
          ),
          Expanded(
            child: StreamBuilder<List<RecurringRule>>(
              stream: (db.select(db.recurringRules)
                ..orderBy([
                      (t) => OrderingTerm.desc(t.isActive),
                      (t) => OrderingTerm.desc(t.createdAt),
                ]))
                  .watch(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return const Center(
                    child: Text("Henüz kural yok. + ile ekleyebilirsin."),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final r = list[i];

                    // ----- Title -----
                    final titleText = (r.note ?? "").trim().isNotEmpty
                        ? r.note!
                        : (r.isIncome ? "Tekrarlayan Gelir" : "Tekrarlayan Gider");

                    // ----- Top line (existing info) -----
                    final line1 = [
                      _freqLabel(r.frequency),
                      "interval: ${r.interval}",
                      if (r.dayOfPeriod != null) "day: ${r.dayOfPeriod}",
                      "amount: ${r.amount.toStringAsFixed(2)}",
                      r.isIncome ? "Gelir" : "Gider",
                    ].join(" • ");

                    // ----- Last / Next run -----
                    final lastDateOnly =
                    r.lastGeneratedAt == null ? null : _dateOnly(r.lastGeneratedAt!);

                    final nextDateOnly = _nextRunDateOnly(r, now: DateTime.now());

                    final lastText = lastDateOnly == null ? "—" : fmt.format(lastDateOnly);
                    final nextText = nextDateOnly == null ? "—" : fmt.format(nextDateOnly);

                    final line2 = "Son: $lastText • Sonraki: $nextText";

                    return Card(
                      child: ListTile(
                        title: Text(
                          titleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text("$line1\n$line2"),
                        isThreeLine: true,
                        trailing: Switch(
                          value: r.isActive,
                          onChanged: (v) async {
                            await (db.update(db.recurringRules)
                              ..where((t) => t.id.equals(r.id)))
                                .write(
                              RecurringRulesCompanion(isActive: Value(v)),
                            );
                          },
                        ),
                        // ✅ tap = edit
                        onTap: () => openEdit(r),

                        // ✅ long press = delete
                        onLongPress: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Kuralı sil"),
                              content: const Text("Bu kuralı silmek istiyor musun?"),
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

                          if (ok == true) {
                            await (db.delete(db.recurringRules)
                              ..where((t) => t.id.equals(r.id)))
                                .go();

                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                ..clearSnackBars()
                                ..showSnackBar(
                                  const SnackBar(
                                    content: Text("Kural silindi 🗑️"),
                                    behavior: SnackBarBehavior.floating,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                            }
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Helpers ----------------

  static String _freqLabel(String f) {
    switch (f) {
      case "daily":
        return "Günlük";
      case "weekly":
        return "Haftalık";
      case "monthly":
        return "Aylık";
      default:
        return f;
    }
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static int _clampDayOfMonth(int year, int month, int desiredDay) {
    final lastDay = DateTime(year, month + 1, 0).day;
    if (desiredDay < 1) return 1;
    if (desiredDay > lastDay) return lastDay;
    return desiredDay;
  }

  /// r için "cursor" gününde çalışmalı mı?
  static bool _isDueOn(RecurringRule r, DateTime day, DateTime startDateOnly) {
    switch (r.frequency) {
      case "daily":
        final diffDays = day.difference(startDateOnly).inDays;
        return diffDays >= 0 && diffDays % r.interval == 0;

      case "weekly":
        final dow = r.dayOfPeriod;
        if (dow == null) return false;

        if (day.weekday != dow) return false;

        final diffDays = day.difference(startDateOnly).inDays;
        if (diffDays < 0) return false;

        final diffWeeks = diffDays ~/ 7;
        return diffWeeks % r.interval == 0;

      case "monthly":
        final dom = r.dayOfPeriod;
        if (dom == null) return false;

        final targetDay = _clampDayOfMonth(day.year, day.month, dom);
        if (day.day != targetDay) return false;

        final diffMonths =
            (day.year - startDateOnly.year) * 12 + (day.month - startDateOnly.month);

        return diffMonths >= 0 && diffMonths % r.interval == 0;

      default:
        return false;
    }
  }

  /// Bir sonraki çalışacağı tarihi (dateOnly) hesaplar.
  /// Performans için ileriye dönük sınırlı tarıyoruz.
  static DateTime? _nextRunDateOnly(RecurringRule r, {required DateTime now}) {
    final today = _dateOnly(now);
    final start = _dateOnly(r.startDate);

    // daha başlamadıysa, start'tan başla
    DateTime base = today.isBefore(start) ? start : today;

    // bugün zaten üretildiyse yarından başla
    final last = r.lastGeneratedAt == null ? null : _dateOnly(r.lastGeneratedAt!);
    if (last != null && last == today) {
      base = today.add(const Duration(days: 1));
    }

    // tarama limiti:
    // monthly => ~5 yıl, diğerleri => 400 gün yeter
    final int maxDays = (r.frequency == "monthly") ? (31 * 62) : 400;

    for (int i = 0; i <= maxDays; i++) {
      final d = base.add(Duration(days: i));
      if (d.isBefore(start)) continue;
      if (_isDueOn(r, d, start)) return d;
    }
    return null;
  }
}
