import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import '../data/app_database.dart';

class CsvImportService {
  // Beklenen CSV dosya adları
  static const txFile = 'transactions.csv';
  static const budgetsFile = 'budgets.csv';
  static const overridesFile = 'category_overrides.csv';

  /// Default: replaceAll = true (tam sıfırla: tx + budgets + overrides)
  static Future<void> importAllCsv(
      AppDatabase db, {
        required File transactionsCsv,
        required File budgetsCsv,
        required File overridesCsv,
        bool replaceAll = true,
      }) async {
    final txRows = await _readCsv(transactionsCsv);
    final bRows = await _readCsv(budgetsCsv);
    final oRows = await _readCsv(overridesCsv);

    if (txRows.isEmpty || bRows.isEmpty || oRows.isEmpty) {
      throw Exception('CSV dosyalarından biri boş görünüyor.');
    }

    await db.transaction(() async {
      if (replaceAll) {
        // FK yüzünden sıraya dikkat: child tablolardan başla
        await db.delete(db.transactions).go();
        await db.delete(db.budgets).go();
        await db.delete(db.categoryOverrides).go();
        // kategorileri silmiyoruz
      }

      // --- 0) Kategoriler map'i (name -> id) ---
      final catNameToId = await _buildCategoryNameIndex(db);

      // --- 1) Budgets ---
      // Export format: id;yil;ay;kategori_id;kategori;butce
      // Legacy format: id;category_id;year;month;amount
      final bHeader = _headerIndex(bRows.first);

      final hasYearTR = bHeader.containsKey('yil');
      final hasYearEN = bHeader.containsKey('year');

      for (int i = 1; i < bRows.length; i++) {
        final r = bRows[i];
        if (_isBlankRow(r)) continue;

        int? categoryId;

        // TR export'ta kategori_id var (kullan)
        final catIdKey = hasYearTR ? 'kategori_id' : 'category_id';
        final catIdRaw = _toInt(_cell(r, bHeader, catIdKey));
        if (catIdRaw != null) {
          categoryId = catIdRaw;
        } else {
          // kategori adı varsa id bul / yoksa oluştur
          final catNameKey = hasYearTR ? 'kategori' : 'category';
          final catName = _cell(r, bHeader, catNameKey)?.trim();
          if (catName != null && catName.isNotEmpty) {
            categoryId = await _ensureCategory(db, catNameToId, catName);
          }
        }

        final yearKey = hasYearTR ? 'yil' : 'year';
        final monthKey = hasYearTR ? 'ay' : 'month';
        final amountKey = hasYearTR ? 'butce' : 'amount';

        final year = _toInt(_cell(r, bHeader, yearKey));
        final month = _toInt(_cell(r, bHeader, monthKey));
        final amount = _toDouble(_cell(r, bHeader, amountKey));

        if (categoryId == null || year == null || month == null || amount == null) {
          continue;
        }

        await db.upsertBudget(
          categoryId: categoryId,
          year: year,
          month: month,
          amount: amount,
        );
      }

      // --- 2) CategoryOverrides ---
      // Export format: id;token;kategori_id;kategori;count
      // Legacy format: id;token;category_id;count
      final oHeader = _headerIndex(oRows.first);

      final hasCatIdTR = oHeader.containsKey('kategori_id');
      final hasCatIdEN = oHeader.containsKey('category_id');

      for (int i = 1; i < oRows.length; i++) {
        final r = oRows[i];
        if (_isBlankRow(r)) continue;

        final token = _cell(r, oHeader, 'token')?.trim();
        if (token == null || token.isEmpty) continue;

        int? categoryId;

        // ✅ FIX: boş key ile _cell çağırma yok
        if (hasCatIdTR) {
          categoryId = _toInt(_cell(r, oHeader, 'kategori_id'));
        } else if (hasCatIdEN) {
          categoryId = _toInt(_cell(r, oHeader, 'category_id'));
        }

        if (categoryId == null) {
          final catName = _cell(r, oHeader, 'kategori')?.trim();
          if (catName != null && catName.isNotEmpty) {
            categoryId = await _ensureCategory(db, catNameToId, catName);
          }
        }

        if (categoryId == null) continue;

        final count = _toInt(_cell(r, oHeader, 'count')) ?? 1;

        final existing = await (db.select(db.categoryOverrides)
          ..where((o) => o.token.equals(token)))
            .getSingleOrNull();

        if (existing == null) {
          await db.into(db.categoryOverrides).insert(
            CategoryOverridesCompanion.insert(
              token: token,
              categoryId: categoryId,
              count: Value(count),
            ),
          );
        } else {
          await (db.update(db.categoryOverrides)
            ..where((o) => o.token.equals(token)))
              .write(
            CategoryOverridesCompanion(
              categoryId: Value(categoryId),
              count: Value(count),
            ),
          );
        }
      }

      // --- 3) Transactions ---
      // TR export: id;tarih;kategori;tip;gelir;gider;not
      // Legacy:    id;amount;note;category_id;date_iso
      final tHeader = _headerIndex(txRows.first);

      final isTrExport = tHeader.containsKey('tarih') &&
          tHeader.containsKey('kategori') &&
          (tHeader.containsKey('gelir') || tHeader.containsKey('gider'));

      for (int i = 1; i < txRows.length; i++) {
        final r = txRows[i];
        if (_isBlankRow(r)) continue;

        double? amount;
        String? note;
        int? categoryId;
        DateTime date = DateTime.now();

        if (isTrExport) {
          final dateStr = _cell(r, tHeader, 'tarih')?.trim();
          final catName = _cell(r, tHeader, 'kategori')?.trim();
          final tip = _cell(r, tHeader, 'tip')?.trim().toLowerCase();

          // ✅ FIX: TR sayıları da parse edebilen double
          final gelir = _toDouble(_cell(r, tHeader, 'gelir')) ?? 0.0;
          final gider = _toDouble(_cell(r, tHeader, 'gider')) ?? 0.0;

          note = _cell(r, tHeader, 'not');

          if (dateStr != null && dateStr.isNotEmpty) {
            final parsed = _tryParseTrDateTime(dateStr);
            if (parsed != null) date = parsed;
          }

          if (catName == null || catName.isEmpty) continue;
          categoryId = await _ensureCategory(db, catNameToId, catName);

          final isIncome = (tip == 'gelir') || (gelir > 0 && gider == 0);
          if (isIncome) {
            amount = gelir;
            if (amount <= 0) continue;
          } else {
            final exp = gider > 0 ? gider : 0.0;
            if (exp <= 0) continue;
            amount = -exp;
          }
        } else {
          // --- Legacy/raw parse ---
          amount = _toDouble(_cell(r, tHeader, 'amount'));
          note = _cell(r, tHeader, 'note');
          categoryId = _toInt(_cell(r, tHeader, 'category_id'));
          final dateIso = _cell(r, tHeader, 'date_iso');

          if (amount == null || categoryId == null) continue;

          if (dateIso != null && dateIso.trim().isNotEmpty) {
            final parsed = DateTime.tryParse(dateIso.trim());
            if (parsed != null) date = parsed;
          }
        }

        if (amount == null || categoryId == null) continue;

        await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            amount: amount,
            categoryId: categoryId,
            note: (note == null || note.trim().isEmpty)
                ? const Value.absent()
                : Value(note.trim()),
            date: Value(date),
          ),
          mode: InsertMode.insert,
        );
      }
    });
  }

  // ---------------- Category helpers ----------------

  static Future<Map<String, int>> _buildCategoryNameIndex(AppDatabase db) async {
    final cats = await db.select(db.categories).get();
    final map = <String, int>{};
    for (final c in cats) {
      map[_norm(c.name)] = c.id;
    }
    return map;
  }

  static Future<int> _ensureCategory(
      AppDatabase db,
      Map<String, int> cache,
      String name,
      ) async {
    final key = _norm(name);
    final cached = cache[key];
    if (cached != null) return cached;

    final existing = await (db.select(db.categories)
      ..where((c) => c.name.equals(name)))
        .getSingleOrNull();
    if (existing != null) {
      cache[key] = existing.id;
      return existing.id;
    }

    final newId = await db.into(db.categories).insert(
      CategoriesCompanion.insert(
        name: name.trim(),
        colorHex: const Value('#CCCCCC'),
      ),
    );
    cache[key] = newId;
    return newId;
  }

  static String _norm(String s) {
    var x = s.toLowerCase().trim();
    x = x
        .replaceAll("ı", "i")
        .replaceAll("ş", "s")
        .replaceAll("ğ", "g")
        .replaceAll("ç", "c")
        .replaceAll("ö", "o")
        .replaceAll("ü", "u");
    x = x.replaceAll(RegExp(r"\s+"), " ").trim();
    return x;
  }

  static DateTime? _tryParseTrDateTime(String s) {
    // dd.MM.yyyy HH:mm
    final m = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})\s+(\d{2}):(\d{2})$')
        .firstMatch(s.trim());
    if (m == null) return null;
    final dd = int.tryParse(m.group(1)!);
    final mm = int.tryParse(m.group(2)!);
    final yyyy = int.tryParse(m.group(3)!);
    final hh = int.tryParse(m.group(4)!);
    final min = int.tryParse(m.group(5)!);
    if ([dd, mm, yyyy, hh, min].any((v) => v == null)) return null;
    return DateTime(yyyy!, mm!, dd!, hh!, min!);
  }

  // ---------------- CSV Helpers ----------------

  static Future<List<List<String>>> _readCsv(File f) async {
    final bytes = await f.readAsBytes();
    var text = utf8.decode(bytes, allowMalformed: true);
    text = text.replaceFirst('\uFEFF', ''); // BOM temizle

    final lines = const LineSplitter().convert(text);
    final out = <List<String>>[];

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      out.add(_parseCsvLine(line, delimiter: ';'));
    }
    return out;
  }

  static List<String> _parseCsvLine(String line, {required String delimiter}) {
    final res = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];

      if (ch == '"') {
        final nextIsQuote = (i + 1 < line.length && line[i + 1] == '"');
        if (inQuotes && nextIsQuote) {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }

      if (!inQuotes && ch == delimiter) {
        res.add(buf.toString());
        buf.clear();
        continue;
      }

      buf.write(ch);
    }

    res.add(buf.toString());
    return res;
  }

  static bool _isBlankRow(List<String> row) {
    return row.every((c) => c.trim().isEmpty);
  }

  static Map<String, int> _headerIndex(List<String> headerRow) {
    final map = <String, int>{};
    for (int i = 0; i < headerRow.length; i++) {
      final key = headerRow[i].trim().toLowerCase();
      if (key.isEmpty) continue;
      map[key] = i;
    }
    return map;
  }

  static String? _cell(List<String> row, Map<String, int> idx, String key) {
    final k = key.trim().toLowerCase();
    if (k.isEmpty) return null;
    final i = idx[k];
    if (i == null) return null;
    if (i < 0 || i >= row.length) return null;
    return row[i];
  }

  static int? _toInt(String? s) {
    if (s == null) return null;
    final x = s.trim();
    if (x.isEmpty) return null;

    // "1.000" gibi gelirse
    final cleaned = x.replaceAll(RegExp(r'[^0-9\-]'), '');
    return int.tryParse(cleaned);
  }

  static double? _toDouble(String? s) {
    if (s == null) return null;
    var x = s.trim();
    if (x.isEmpty) return null;

    // ✅ Para sembolü, boşluk vs temizle
    x = x.replaceAll('₺', '').replaceAll('TL', '').replaceAll('tl', '');
    x = x.replaceAll(' ', '');

    // ✅ TR format: 20.050,00  / 20.050  / 20050,00
    // Heuristik:
    // - hem '.' hem ',' varsa: '.' binlik, ',' ondalık -> '.' sil, ',' -> '.'
    // - sadece ',' varsa: ',' -> '.'
    // - sadece '.' varsa:
    //    - eğer sonrasında 3 hane varsa binlik olabilir (20.050) -> '.' sil
    //    - değilse ondalık olabilir (12.5) -> bırak
    if (x.contains('.') && x.contains(',')) {
      x = x.replaceAll('.', '');
      x = x.replaceAll(',', '.');
    } else if (x.contains(',')) {
      x = x.replaceAll(',', '.');
    } else if (x.contains('.')) {
      // 20.050 gibi binlik mi?
      final parts = x.split('.');
      if (parts.length == 2 && parts[1].length == 3) {
        x = x.replaceAll('.', '');
      }
    }

    // Son temizlik: sayı dışı karakter
    x = x.replaceAll(RegExp(r'[^0-9\.\-]'), '');

    return double.tryParse(x);
  }
}