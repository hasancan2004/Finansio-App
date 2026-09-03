import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finansio/data/database/app_database.dart';

class CsvExportService {
  /// Excel/TR için: ; ayırıcı + UTF-8 BOM
  static Future<Directory> exportAllCsv(AppDatabase db) async {
    final dir = await getApplicationDocumentsDirectory();
    final folderName =
        'finansio_export_${DateTime.now().toIso8601String().replaceAll(":", "-")}';
    final outDir = Directory('${dir.path}/$folderName');

    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    final txFile = await exportTransactionsCsv(db, directory: outDir);
    final budgetsFile = await exportBudgetsCsv(db, directory: outDir);
    final overridesFile =
    await exportCategoryOverridesCsv(db, directory: outDir);

    // sadece referans olsun diye (kullanmak istersen)
    // ignore: unused_local_variable
    final files = [txFile, budgetsFile, overridesFile];

    return outDir;
  }

  static Future<File> exportTransactionsCsv(
      AppDatabase db, {
        Directory? directory,
      }) async {
    final rows = await db.customSelect(
      '''
      SELECT
        t.id                        AS tx_id,
        t.date                      AS tx_date,
        CAST(t.amount AS REAL)      AS tx_amount,   -- ✅ FIX: num yerine REAL
        t.note                      AS tx_note,
        c.name                      AS cat_name
      FROM transactions t
      JOIN categories c ON c.id = t.category_id
      ORDER BY t.date DESC, t.id DESC
      ''',
      readsFrom: {db.transactions, db.categories},
    ).get();

    final fmt = DateFormat('dd.MM.yyyy HH:mm');
    final sb = StringBuffer()..write('\uFEFF');
    sb.writeln('id;tarih;kategori;tip;gelir;gider;not');

    for (final r in rows) {
      final id = r.read<int>('tx_id') ?? 0;
      final date = r.read<DateTime>('tx_date') ?? DateTime.now();

      // ✅ FIX: read<num> yok, REAL -> double
      final amount = (r.read<double>('tx_amount') ?? 0.0);

      final note = r.read<String?>('tx_note') ?? '';
      final catName = r.read<String>('cat_name') ?? '';

      final isIncome = amount >= 0;
      final income = isIncome ? amount : 0.0;
      final expense = isIncome ? 0.0 : amount.abs();

      sb.writeln(
        '${id};'
            '${_esc(fmt.format(date))};'
            '${_esc(catName)};'
            '${isIncome ? 'Gelir' : 'Gider'};'
            '${income.toStringAsFixed(2)};'
            '${expense.toStringAsFixed(2)};'
            '${_esc(note)}',
      );
    }

    final outDir = directory ?? await getApplicationDocumentsDirectory();
    final file = File('${outDir.path}/transactions.csv');
    await file.writeAsString(sb.toString(), flush: true);
    return file;
  }

  static Future<File> exportBudgetsCsv(
      AppDatabase db, {
        Directory? directory,
      }) async {
    final rows = await db.customSelect(
      '''
      SELECT
        b.id                        AS b_id,
        b.year                      AS b_year,
        b.month                     AS b_month,
        CAST(b.amount AS REAL)      AS b_amount,    -- ✅ FIX
        b.category_id               AS b_cat_id,
        c.name                      AS c_name
      FROM budgets b
      JOIN categories c ON c.id = b.category_id
      ORDER BY b.year DESC, b.month DESC, c.name ASC
      ''',
      readsFrom: {db.budgets, db.categories},
    ).get();

    final sb = StringBuffer()..write('\uFEFF');
    sb.writeln('id;yil;ay;kategori_id;kategori;butce');

    for (final r in rows) {
      final id = r.read<int>('b_id') ?? 0;
      final year = r.read<int>('b_year') ?? 0;
      final month = r.read<int>('b_month') ?? 0;

      // ✅ FIX: num yok
      final amount = (r.read<double>('b_amount') ?? 0.0);

      final catId = r.read<int>('b_cat_id') ?? 0;
      final catName = r.read<String>('c_name') ?? '';

      sb.writeln(
        '${id};'
            '$year;'
            '$month;'
            '$catId;'
            '${_esc(catName)};'
            '${amount.toStringAsFixed(2)}',
      );
    }

    final outDir = directory ?? await getApplicationDocumentsDirectory();
    final file = File('${outDir.path}/budgets.csv');
    await file.writeAsString(sb.toString(), flush: true);
    return file;
  }

  static Future<File> exportCategoryOverridesCsv(
      AppDatabase db, {
        Directory? directory,
      }) async {
    final rows = await db.customSelect(
      '''
      SELECT
        o.id            AS o_id,
        o.token         AS o_token,
        o.count         AS o_count,
        o.category_id   AS o_cat_id,
        c.name          AS c_name
      FROM category_overrides o
      JOIN categories c ON c.id = o.category_id
      ORDER BY o.count DESC, o.id DESC
      ''',
      readsFrom: {db.categoryOverrides, db.categories},
    ).get();

    final sb = StringBuffer()..write('\uFEFF');
    sb.writeln('id;token;kategori_id;kategori;count');

    for (final r in rows) {
      final id = r.read<int>('o_id') ?? 0;
      final token = r.read<String>('o_token') ?? '';
      final count = r.read<int>('o_count') ?? 0;
      final catId = r.read<int>('o_cat_id') ?? 0;
      final catName = r.read<String>('c_name') ?? '';

      sb.writeln(
        '${id};'
            '${_esc(token)};'
            '$catId;'
            '${_esc(catName)};'
            '$count',
      );
    }

    final outDir = directory ?? await getApplicationDocumentsDirectory();
    final file = File('${outDir.path}/category_overrides.csv');
    await file.writeAsString(sb.toString(), flush: true);
    return file;
  }

  static String _esc(String s) {
    var x = s.replaceAll('\n', ' ').replaceAll('\r', ' ');
    if (x.contains(';') || x.contains('"')) {
      x = x.replaceAll('"', '""');
      return '"$x"';
    }
    return x;
  }
}