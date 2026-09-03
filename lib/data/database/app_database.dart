// lib/data/app_database.dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_sqflite/drift_sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// ------------------ Tablolar ------------------

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get colorHex =>
      text().withDefault(const Constant('#CCCCCC'))(); // Örn: #FF7043
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get amount => real()(); // + gelir, - gider
  TextColumn get note => text().nullable()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
}

/// Aylık kategori bazlı bütçeler
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get year => integer()(); // YYYY
  IntColumn get month => integer()(); // 1..12
  RealColumn get amount => real()(); // Pozitif bütçe

  @override
  List<Set<Column>>? get uniqueKeys => [
    {categoryId, year, month}
  ];
}

/// ✅ Kullanıcı düzeltince öğrenme (token -> kategori)
class CategoryOverrides extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// normalize edilmiş token
  TextColumn get token => text()();

  /// bu token görünce hangi kategori önerilsin
  IntColumn get categoryId => integer().references(Categories, #id)();

  /// kaç kere bu eşleşme seçildi
  IntColumn get count => integer().withDefault(const Constant(1))();

  @override
  List<Set<Column>>? get uniqueKeys => [
    {token}
  ];
}
// ✅ Tekrarlayan işlemler (kural tablosu)
class RecurringRules extends Table {
  IntColumn get id => integer().autoIncrement()();

  // Bu kural bir gider mi gelir mi? (Transactions.amount işaretini buna göre belirleyeceğiz)
  BoolColumn get isIncome => boolean().withDefault(const Constant(false))();

  // Pozitif tutar (biz transaction eklerken giderse -amount yapacağız)
  RealColumn get amount => real()();

  // Kategori
  IntColumn get categoryId => integer().references(Categories, #id)();

  // Not / açıklama
  TextColumn get note => text().nullable()();

  // Frekans: daily / weekly / monthly
  TextColumn get frequency => text()();

  // Her kaç birimde bir? (örn: 1 ayda bir, 2 haftada bir)
  IntColumn get interval => integer().withDefault(const Constant(1))();

  // Weekly için: 1..7 (1=Mon, 7=Sun). Monthly için: 1..31
  IntColumn get dayOfPeriod => integer().nullable()();

  // Başlangıç tarihi (kuralın çalışmaya başladığı tarih)
  DateTimeColumn get startDate => dateTime().withDefault(currentDateAndTime)();

  // Kural aktif mi?
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  // En son ne zaman “işlem üretildi” / onaylandı (double üretimi engeller)
  DateTimeColumn get lastGeneratedAt => dateTime().nullable()();

  // Oluşturulma
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// ------------------ Database ------------------

@DriftDatabase(tables: [Categories, Transactions, Budgets, CategoryOverrides, RecurringRules])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  /// ✅ ŞEMA VERSIYONU 3
  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // v1 -> v2: budgets
      if (from < 2) {
        await m.createTable(budgets);
      }
      // v2 -> v3: category_overrides
      if (from < 3) {
        await m.createTable(categoryOverrides);
      }
      if (from < 4) {
        await m.createTable(recurringRules);
      }
    },
  );

  /// İlk açılışta örnek kategoriler (seed)
  Future<void> seed() async {
    final hasAny =
    await (select(categories).get()).then((rows) => rows.isNotEmpty);
    if (!hasAny) {
      await batch((b) => b.insertAll(categories, [
        CategoriesCompanion.insert(
            name: 'Yemek', colorHex: const Value('#FF7043')),
        CategoriesCompanion.insert(
            name: 'Ulaşım', colorHex: const Value('#42A5F5')),
        CategoriesCompanion.insert(
            name: 'Fatura', colorHex: const Value('#AB47BC')),
        CategoriesCompanion.insert(
            name: 'Maaş', colorHex: const Value('#66BB6A')),
      ]));
    }
  }

  // Sadece temel kategorileri oluşturan fonksiyon (Demo harcamaları eklemez)
  Future<void> seedCategoriesOnly() async {
    // Eğer daha önce kategoriler silindiyse veya hiç yoksa temel kategorileri ekle
    // (Mevcut seed mantığındaki kategori ekleme kodlarını buraya koyabilirsin)
    await batch((batch) {
      batch.insertAll(
        categories,
        [
          CategoriesCompanion.insert(name: 'Mutfak', colorHex: const Value('#FF5733')),
          CategoriesCompanion.insert(name: 'Fatura', colorHex: const Value('#33FF57')),
          CategoriesCompanion.insert(name: 'Ulaşım', colorHex: const Value('#3357FF')),
          CategoriesCompanion.insert(name: 'Eğlence', colorHex: const Value('#F333FF')),
        ],
        mode: InsertMode.insertOrIgnore,
      );
    });
  }


  // AppDatabase class içi
  Future<void> clearAllData() async {
    await transaction(() async {
      // sırayı böyle yapınca FK varsa da sorun çıkmaz
      await customStatement('DELETE FROM category_overrides');
      await customStatement('DELETE FROM recurring_rules');
      await customStatement('DELETE FROM budgets');
      await customStatement('DELETE FROM transactions');
      // kategori genelde sabit kalabilir ama "tam sıfırla" dediğin için siliyorum:
      await customStatement('DELETE FROM categories');
    });
  }


  // ------------------ KATEGORİ ------------------

  Future<List<Category>> allCategories() => select(categories).get();

  Stream<List<Category>> watchCategories() =>
      (select(categories)..orderBy([(c) => OrderingTerm.asc(c.name)])).watch();

  Future<bool> categoryNameExists(String name, {int? exceptId}) async {
    final q = select(categories)..where((c) => c.name.equals(name));
    final rows = await q.get();
    if (exceptId == null) return rows.isNotEmpty;
    return rows.any((e) => e.id != exceptId);
  }

  Future<int> addCategory({required String name, required String colorHex}) {
    return into(categories).insert(
      CategoriesCompanion.insert(name: name, colorHex: Value(colorHex)),
    );
  }

  Future<int> updateCategory({
    required int id,
    String? name,
    String? colorHex,
  }) {
    final comp = CategoriesCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      colorHex: colorHex != null ? Value(colorHex) : const Value.absent(),
    );
    return (update(categories)..where((c) => c.id.equals(id))).write(comp);
  }

  Future<int> deleteCategory(int id) =>
      (delete(categories)..where((c) => c.id.equals(id))).go();

  // ------------------ ✅ ÖĞRENME (OVERRIDE) ------------------

  Future<void> learnCategoryOverride({
    required String token,
    required int categoryId,
  }) async {
    final existing = await (select(categoryOverrides)
      ..where((o) => o.token.equals(token)))
        .getSingleOrNull();

    if (existing == null) {
      await into(categoryOverrides).insert(
        CategoryOverridesCompanion.insert(
          token: token,
          categoryId: categoryId,
          count: const Value(1),
        ),
      );
    } else {
      await (update(categoryOverrides)..where((o) => o.id.equals(existing.id)))
          .write(
        CategoryOverridesCompanion(
          categoryId: Value(categoryId),
          count: Value(existing.count + 1),
        ),
      );
    }
  }

  /// Token listesinde en güçlü override kategoriId’sini döndürür
  Future<int?> fetchBestOverrideCategoryId(List<String> tokens) async {
    if (tokens.isEmpty) return null;

    final q = (select(categoryOverrides)
      ..where((o) => o.token.isIn(tokens))
      ..orderBy([
            (o) => OrderingTerm.desc(o.count),
            (o) => OrderingTerm.desc(o.id),
      ])
      ..limit(1));

    final row = await q.getSingleOrNull();
    return row?.categoryId;
  }

  // ------------------ TRANSACTION ------------------

  Future<int> addTransaction(TransactionsCompanion data) =>
      into(transactions).insert(data);

  Future<int> updateTransaction({
    required int id,
    double? amount,
    int? categoryId,
    String? note,
    DateTime? date,
  }) {
    final comp = TransactionsCompanion(
      amount: amount != null ? Value(amount) : const Value.absent(),
      categoryId: categoryId != null ? Value(categoryId) : const Value.absent(),
      note: note != null ? Value(note) : const Value.absent(),
      date: date != null ? Value(date) : const Value.absent(),
    );
    return (update(transactions)..where((t) => t.id.equals(id))).write(comp);
  }

  Future<int> deleteTransaction(int id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  /// ✅ Bu ay için gün gün gelir/gider
  Future<({List<double> incomeDaily, List<double> expenseAbsDaily})>
  fetchThisMonthDailyIncomeExpense() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = _endOfDay(DateTime(now.year, now.month + 1, 0));

    final rows = await (select(transactions)
      ..where((t) => t.date.isBiggerOrEqualValue(_startOfDay(start)))
      ..where((t) => t.date.isSmallerOrEqualValue(end)))
        .get();

    final dayCount = now.day; // bugüne kadar
    final income = List<double>.filled(dayCount, 0.0);
    final expenseAbs = List<double>.filled(dayCount, 0.0);

    for (final r in rows) {
      final d = r.date.day;
      if (d < 1 || d > dayCount) continue;
      final idx = d - 1;

      if (r.amount >= 0) {
        income[idx] += r.amount;
      } else {
        expenseAbs[idx] += r.amount.abs();
      }
    }

    return (incomeDaily: income, expenseAbsDaily: expenseAbs);
  }

  /// ✅ Son X günde yapılan kategori giderleri (ABS)
  Future<List<double>> fetchRecentExpenseAbsForCategory({
    required int categoryId,
    required DateTime start,
    required DateTime end,
    int limit = 200,
  }) async {
    final q = (select(transactions)
      ..where((t) => t.categoryId.equals(categoryId))
      ..where((t) => t.amount.isSmallerThanValue(0))
      ..where((t) => t.date.isBiggerOrEqualValue(_startOfDay(start)))
      ..where((t) => t.date.isSmallerOrEqualValue(_endOfDay(end)))
      ..orderBy([(t) => OrderingTerm.desc(t.date)])
      ..limit(limit));

    final rows = await q.get();
    return rows.map((r) => r.amount.abs()).toList();
  }

  /// ✅ Son X günde yapılan tüm giderler (ABS)
  Future<List<double>> fetchRecentExpenseAbsGlobal({
    required DateTime start,
    required DateTime end,
    int limit = 400,
  }) async {
    final q = (select(transactions)
      ..where((t) => t.amount.isSmallerThanValue(0))
      ..where((t) => t.date.isBiggerOrEqualValue(_startOfDay(start)))
      ..where((t) => t.date.isSmallerOrEqualValue(_endOfDay(end)))
      ..orderBy([(t) => OrderingTerm.desc(t.date)])
      ..limit(limit));

    final rows = await q.get();
    return rows.map((r) => r.amount.abs()).toList();
  }

  /// ✅ Canlı işlem listesi (Home/Filter/Search için)
  Stream<List<Tx>> watchTransactions({
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
    double? minAmount,
    double? maxAmount,
    bool sortByAmount = false,
    bool sortAsc = false,
    String? query,
  }) {
    final tx = alias(transactions, 'tx');

    final join = select(tx).join([
      innerJoin(categories, categories.id.equalsExp(tx.categoryId)),
    ]);

    if (startDate != null) {
      join.where(tx.date.isBiggerOrEqualValue(_startOfDay(startDate)));
    }
    if (endDate != null) {
      join.where(tx.date.isSmallerOrEqualValue(_endOfDay(endDate)));
    }
    if (categoryId != null) {
      join.where(tx.categoryId.equals(categoryId));
    }
    if (minAmount != null) {
      join.where(tx.amount.isBiggerOrEqualValue(minAmount));
    }
    if (maxAmount != null) {
      join.where(tx.amount.isSmallerOrEqualValue(maxAmount));
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim()}%';
      join.where(tx.note.like(q) | categories.name.like(q));
    }

    if (sortByAmount) {
      join.orderBy([
        sortAsc ? OrderingTerm.asc(tx.amount) : OrderingTerm.desc(tx.amount),
        OrderingTerm.desc(tx.date),
      ]);
    } else {
      join.orderBy([
        sortAsc ? OrderingTerm.asc(tx.date) : OrderingTerm.desc(tx.date),
        OrderingTerm.desc(tx.id),
      ]);
    }

    return join.watch().map((rows) {
      return rows.map((r) {
        final t = r.readTable(tx);
        final c = r.readTable(categories);
        return Tx(
          id: t.id,
          amount: t.amount,
          note: t.note,
          date: t.date,
          category: c,
        );
      }).toList();
    });
  }

  /// ✅ Detay ekranı için tek seferlik filtreli liste
  Future<List<TxWithCategory>> filteredTransactions({
    int? categoryId,
    DateTime? start,
    DateTime? end,
  }) async {
    final tx = alias(transactions, 'tx');

    final join = select(tx).join([
      innerJoin(categories, categories.id.equalsExp(tx.categoryId)),
    ]);

    if (categoryId != null) {
      join.where(tx.categoryId.equals(categoryId));
    }
    if (start != null) {
      join.where(tx.date.isBiggerOrEqualValue(_startOfDay(start)));
    }
    if (end != null) {
      join.where(tx.date.isSmallerOrEqualValue(_endOfDay(end)));
    }

    join.orderBy([
      OrderingTerm.desc(tx.date),
      OrderingTerm.desc(tx.id),
    ]);

    final rows = await join.get();

    return rows.map((row) {
      final t = row.readTable(tx);
      final c = row.readTable(categories);

      final txVm = Tx(
        id: t.id,
        amount: t.amount,
        note: t.note,
        date: t.date,
        category: c,
      );
      return TxWithCategory(tx: txVm, category: c);
    }).toList();
  }

  // ------------------ RAPORLAR ------------------

  /// ✅ Reports summary için en doğru kaynak (income/expense)
  Future<SummaryTotals> fetchSummaryTotals({
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
  }) async {
    final tx = alias(transactions, 'tx');

    // GELİR
    final qIncome = selectOnly(tx)..addColumns([tx.amount.sum()]);
    qIncome.where(tx.amount.isBiggerThanValue(0));
    if (startDate != null) {
      qIncome.where(tx.date.isBiggerOrEqualValue(_startOfDay(startDate)));
    }
    if (endDate != null) {
      qIncome.where(tx.date.isSmallerOrEqualValue(_endOfDay(endDate)));
    }
    if (categoryId != null) qIncome.where(tx.categoryId.equals(categoryId));
    final incomeRow = await qIncome.getSingle();
    final income = incomeRow.read(tx.amount.sum()) ?? 0.0;

    // GİDER (negatif toplam)
    final qExpense = selectOnly(tx)..addColumns([tx.amount.sum()]);
    qExpense.where(tx.amount.isSmallerThanValue(0));
    if (startDate != null) {
      qExpense.where(tx.date.isBiggerOrEqualValue(_startOfDay(startDate)));
    }
    if (endDate != null) {
      qExpense.where(tx.date.isSmallerOrEqualValue(_endOfDay(endDate)));
    }
    if (categoryId != null) qExpense.where(tx.categoryId.equals(categoryId));
    final expenseRow = await qExpense.getSingle();
    final negativeSum = expenseRow.read(tx.amount.sum()) ?? 0.0;

    return SummaryTotals(income: income, expense: -negativeSum);
  }

  /// ✅ Pasta grafik için giderleri kategoriye göre toplar (pozitif)
  Future<List<CategoryTotal>> sumExpensesByCategory({
    DateTime? start,
    DateTime? end,
  }) async {
    final List<Variable> variables = [];
    final whereParts = <String>['t.amount < 0'];

    if (start != null) {
      whereParts.add('t.date >= ?');
      variables.add(Variable<DateTime>(_startOfDay(start)));
    }
    if (end != null) {
      whereParts.add('t.date <= ?');
      variables.add(Variable<DateTime>(_endOfDay(end)));
    }

    final whereSql = whereParts.isEmpty ? '' : 'WHERE ${whereParts.join(' AND ')}';

    final rows = await customSelect(
      '''
      SELECT
        c.id         AS c_id,
        c.name       AS c_name,
        c.color_hex  AS c_color,
        SUM(ABS(t.amount)) AS total_abs
      FROM transactions t
      JOIN categories c ON c.id = t.category_id
      $whereSql
      GROUP BY c.id, c.name, c.color_hex
      ORDER BY total_abs DESC
      ''',
      variables: variables,
      readsFrom: {transactions, categories},
    ).get();

    return rows.map((r) {
      final cat = Category(
        id: r.read<int>('c_id')!,
        name: r.read<String>('c_name')!,
        colorHex: r.read<String>('c_color')!,
      );
      final total = r.read<double?>('total_abs') ?? 0.0;
      return CategoryTotal(category: cat, total: total);
    }).toList();
  }

  /// ✅ Son N ay için gelir/gider (ay bazında)
  Future<List<MonthlyTotals>> monthlyTotals({int monthsBack = 6}) async {
    final now = DateTime.now();
    final firstMonth = DateTime(now.year, now.month - (monthsBack - 1), 1);

    final tx = alias(transactions, 'tx');

    final rows = await (select(tx)
      ..where((t) => t.date.isBiggerOrEqualValue(_startOfDay(firstMonth))))
        .get();

    final map = <String, Map<String, double>>{};
    for (final r in rows) {
      final m = DateTime(r.date.year, r.date.month, 1);
      final key =
          '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}';
      final rec = map.putIfAbsent(key, () => {'inc': 0.0, 'exp': 0.0});
      if (r.amount >= 0) {
        rec['inc'] = (rec['inc'] ?? 0.0) + r.amount;
      } else {
        rec['exp'] = (rec['exp'] ?? 0.0) + r.amount; // negatif birikiyor
      }
    }

    final out = <MonthlyTotals>[];
    for (int i = 0; i < monthsBack; i++) {
      final m = DateTime(now.year, now.month - (monthsBack - 1 - i), 1);
      final key =
          '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}';
      final rec = map[key];
      final income = (rec?['inc'] ?? 0.0);
      final expense = (rec?['exp'] ?? 0.0);
      out.add(MonthlyTotals(month: m, income: income, expense: expense));
    }
    return out;
  }

  // ------------------ BÜTÇE ------------------

  Future<void> upsertBudget({
    required int categoryId,
    required int year,
    required int month,
    required double amount,
  }) async {
    final existing = await (select(budgets)
      ..where((b) =>
      b.categoryId.equals(categoryId) &
      b.year.equals(year) &
      b.month.equals(month)))
        .getSingleOrNull();

    if (existing == null) {
      await into(budgets).insert(BudgetsCompanion.insert(
        categoryId: categoryId,
        year: year,
        month: month,
        amount: amount,
      ));
    } else {
      await (update(budgets)..where((b) => b.id.equals(existing.id))).write(
        BudgetsCompanion(amount: Value(amount)),
      );
    }
  }

  Future<void> deleteBudget({
    required int categoryId,
    required int year,
    required int month,
  }) {
    return (delete(budgets)
      ..where((b) =>
      b.categoryId.equals(categoryId) &
      b.year.equals(year) &
      b.month.equals(month)))
        .go();
  }

  /// Seçilen ay için bütçe durumları
  Stream<List<BudgetStatus>> watchBudgetStatuses({
    required int year,
    required int month,
  }) {
    final start = DateTime(year, month, 1);
    final end = _endOfDay(DateTime(year, month + 1, 0));

    final q = customSelect(
      '''
      SELECT
        c.id        AS c_id,
        c.name      AS c_name,
        c.color_hex AS c_color,
        b.amount    AS b_amount,
        (
          SELECT COALESCE(SUM(ABS(t.amount)), 0)
          FROM transactions t
          WHERE t.category_id = c.id
            AND t.amount < 0
            AND t.date >= ?
            AND t.date <= ?
        ) AS spent_abs
      FROM categories c
      LEFT JOIN budgets b
        ON b.category_id = c.id AND b.year = ? AND b.month = ?
      ORDER BY c.name ASC
      ''',
      variables: [
        Variable<DateTime>(_startOfDay(start)),
        Variable<DateTime>(end),
        Variable<int>(year),
        Variable<int>(month),
      ],
      readsFrom: {categories, budgets, transactions},
    );

    return q.watch().map((rows) {
      return rows.map((r) {
        final cat = Category(
          id: r.read<int>('c_id')!,
          name: r.read<String>('c_name')!,
          colorHex: r.read<String>('c_color')!,
        );
        final budget = r.read<double?>('b_amount');
        final spent = r.read<double?>('spent_abs') ?? 0.0;
        final remaining = budget != null ? (budget - spent) : null;
        final progress = (budget != null && budget > 0)
            ? (spent / budget).clamp(0, 999).toDouble()
            : null;

        return BudgetStatus(
          category: cat,
          year: year,
          month: month,
          budget: budget,
          spent: spent,
          remaining: remaining,
          progress: progress,
        );
      }).toList();
    });
  }
}

/// ------------------ DB Açılışı ------------------

LazyDatabase _open() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'finansio.db'));
    return SqfliteQueryExecutor(path: file.path, logStatements: false);
  });
}

/// ------------------ Tarih yardımcıları ------------------

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 0, 0, 0);
DateTime _endOfDay(DateTime d) =>
    DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

/// ------------------ ViewModel & DTO'lar ------------------

class Tx {
  final int id;
  final double amount;
  final String? note;
  final DateTime date;
  final Category category;

  Tx({
    required this.id,
    required this.amount,
    required this.note,
    required this.date,
    required this.category,
  });
}

class TxWithCategory {
  final Tx tx;
  final Category category;
  TxWithCategory({required this.tx, required this.category});
}

class SummaryTotals {
  final double income; // > 0
  final double expense; // pozitif expense (ABS)
  double get net => income - expense;
  SummaryTotals({required this.income, required this.expense});
}

class CategoryTotal {
  final Category category;
  final double total; // gider toplamı (ABS)
  CategoryTotal({required this.category, required this.total});
}

class MonthlyTotals {
  final DateTime month;
  final double income;
  final double expense; // negatif birikiyor
  MonthlyTotals({
    required this.month,
    required this.income,
    required this.expense,
  });
}

class BudgetStatus {
  final Category category;
  final int year;
  final int month;
  final double? budget;
  final double spent;
  final double? remaining;
  final double? progress;
  BudgetStatus({
    required this.category,
    required this.year,
    required this.month,
    required this.budget,
    required this.spent,
    required this.remaining,
    required this.progress,
  });
}


