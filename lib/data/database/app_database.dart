// lib/data/database/app_database.dart
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

  /// İşlemin ait olduğu hesap (cüzdan / banka / kredi kartı).
  /// Geriye dönük uyumluluk için nullable; null ise "hesapsız" kabul edilir.
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();
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

/// Kullanıcı düzeltince öğrenme (token -> kategori)
class CategoryOverrides extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get token => text()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get count => integer().withDefault(const Constant(1))();

  @override
  List<Set<Column>>? get uniqueKeys => [
    {token}
  ];
}

// Tekrarlayan işlemler (kural tablosu)
class RecurringRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  BoolColumn get isIncome => boolean().withDefault(const Constant(false))();
  RealColumn get amount => real()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get note => text().nullable()();
  TextColumn get frequency => text()();
  IntColumn get interval => integer().withDefault(const Constant(1))();
  IntColumn get dayOfPeriod => integer().nullable()();
  DateTimeColumn get startDate => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastGeneratedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Varlık ve Yatırım Portföyü Tablosu
class Assets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  TextColumn get name => text()();
  RealColumn get quantity => real().withDefault(const Constant(0.0))();
  RealColumn get averagePrice => real().withDefault(const Constant(0.0))();

  /// Güncel fiyat (₺). Döviz için TCMB'den otomatik çekilir, diğer türlerde
  /// kullanıcı manuel girer. null ise kâr/zarar hesaplanamaz (maliyet gösterilir).
  RealColumn get currentPrice => real().nullable()();
  TextColumn get colorHex => text().withDefault(const Constant('#FFD700'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Birikim Hedefleri Tablosu (Kumbara)
class SavingGoals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 50)();
  RealColumn get targetAmount => real()();
  RealColumn get currentAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get colorHex => text().withDefault(const Constant('#3B82F6'))();
  TextColumn get iconName => text().withDefault(const Constant('savings'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// ✅ Borç & Alacak (Debt Management) Tablosu
class Debts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get personName => text().withLength(min: 1, max: 50)(); // Kime/Kimden
  RealColumn get amount => real()(); // Borç miktarı
  BoolColumn get isOwedToMe => boolean()(); // true = Alacağım var, false = Borcum var
  BoolColumn get isSettled => boolean().withDefault(const Constant(false))(); // Ödendi mi?
  DateTimeColumn get dueDate => dateTime().nullable()(); // Son ödeme tarihi
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// ✅ Çoklu Hesap & Cüzdan Tablosu (Nakit / Banka / Kredi Kartı)
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get type => text().withDefault(const Constant('cash'))(); // cash | bank | credit_card
  RealColumn get initialBalance => real().withDefault(const Constant(0.0))();
  TextColumn get colorHex => text().withDefault(const Constant('#3B82F6'))();

  /// İkon anahtarı; UI tarafında Material ikonuna eşlenir.
  TextColumn get iconName => text().withDefault(const Constant('wallet'))();

  // ---- Kredi kartına özel alanlar (diğer türlerde null) ----
  RealColumn get creditLimit => real().nullable()();
  IntColumn get statementDay => integer().nullable()(); // Kesim günü (1-28)
  IntColumn get dueDay => integer().nullable()(); // Son ödeme günü (1-28)

  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// ✅ Hesaplar Arası Transfer Tablosu
/// Gelir-gideri bozmadan yalnızca bakiyeleri taşır.
class Transfers extends Table {
  IntColumn get id => integer().autoIncrement()();
  @ReferenceName('outgoingTransfers')
  IntColumn get fromAccountId => integer().references(Accounts, #id)();
  @ReferenceName('incomingTransfers')
  IntColumn get toAccountId => integer().references(Accounts, #id)();
  RealColumn get amount => real()(); // Her zaman pozitif
  TextColumn get note => text().nullable()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
}

/// ------------------ Database ------------------

@DriftDatabase(tables: [Categories, Transactions, Budgets, CategoryOverrides, RecurringRules, Assets, SavingGoals, Debts, Accounts, Transfers])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(budgets);
      if (from < 3) await m.createTable(categoryOverrides);
      if (from < 4) await m.createTable(recurringRules);
      if (from < 5) await m.createTable(assets);
      if (from < 6) await m.createTable(savingGoals);
      if (from < 7) await m.createTable(debts);
      if (from < 8) {
        await m.createTable(accounts);
        await m.createTable(transfers);
        await m.addColumn(transactions, transactions.accountId);

        // Mevcut kullanıcıların geçmiş işlemlerini kaybetmemek için
        // varsayılan bir nakit cüzdanı oluşturup hepsini ona bağlarız.
        final existing = await (select(accounts).get());
        if (existing.isEmpty) {
          final accountId = await into(accounts).insert(
            AccountsCompanion.insert(
              name: 'Nakit Cüzdan',
              type: const Value('cash'),
              colorHex: const Value('#22C55E'),
              iconName: const Value('wallet'),
            ),
          );
          await customStatement(
            'UPDATE transactions SET account_id = ? WHERE account_id IS NULL',
            [accountId],
          );
        }
      }
      if (from < 9) {
        await m.addColumn(assets, assets.currentPrice);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// İlk açılışta örnek kategoriler (seed)
  Future<void> seed() async {
    final hasAny = await (select(categories).get()).then((rows) => rows.isNotEmpty);
    if (!hasAny) {
      await batch((b) => b.insertAll(categories, [
        CategoriesCompanion.insert(name: 'Yemek', colorHex: const Value('#FF7043')),
        CategoriesCompanion.insert(name: 'Ulaşım', colorHex: const Value('#42A5F5')),
        CategoriesCompanion.insert(name: 'Fatura', colorHex: const Value('#AB47BC')),
        CategoriesCompanion.insert(name: 'Maaş', colorHex: const Value('#66BB6A')),
      ]));
    }

    // Varsayılan nakit cüzdanı yoksa oluştur.
    final accountCount = await (select(accounts).get()).then((rows) => rows.length);
    if (accountCount == 0) {
      await into(accounts).insert(
        AccountsCompanion.insert(
          name: 'Nakit Cüzdan',
          type: const Value('cash'),
          colorHex: const Value('#22C55E'),
          iconName: const Value('wallet'),
        ),
      );
    }
  }

  // ✅ EKSİK OLAN FONKSİYON GERİ GELDİ
  Future<void> seedCategoriesOnly() async {
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

  Future<void> clearAllData() async {
    await transaction(() async {
      await customStatement('DELETE FROM category_overrides');
      await customStatement('DELETE FROM recurring_rules');
      await customStatement('DELETE FROM debts');
      await customStatement('DELETE FROM saving_goals');
      await customStatement('DELETE FROM assets');
      await customStatement('DELETE FROM budgets');
      await customStatement('DELETE FROM transfers');
      await customStatement('DELETE FROM transactions');
      await customStatement('DELETE FROM accounts');
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

  // ------------------ ÖĞRENME (OVERRIDE) ------------------

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
    int? accountId,
    bool clearAccount = false,
  }) {
    final comp = TransactionsCompanion(
      amount: amount != null ? Value(amount) : const Value.absent(),
      categoryId: categoryId != null ? Value(categoryId) : const Value.absent(),
      note: note != null ? Value(note) : const Value.absent(),
      date: date != null ? Value(date) : const Value.absent(),
      accountId: clearAccount
          ? const Value(null)
          : (accountId != null ? Value(accountId) : const Value.absent()),
    );
    return (update(transactions)..where((t) => t.id.equals(id))).write(comp);
  }

  Future<int> deleteTransaction(int id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  Future<({List<double> incomeDaily, List<double> expenseAbsDaily})>
  fetchThisMonthDailyIncomeExpense() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = _endOfDay(DateTime(now.year, now.month + 1, 0));

    final rows = await (select(transactions)
      ..where((t) => t.date.isBiggerOrEqualValue(_startOfDay(start)))
      ..where((t) => t.date.isSmallerOrEqualValue(end)))
        .get();

    final dayCount = now.day;
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

  Stream<List<Tx>> watchTransactions({
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
    int? accountId,
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
    if (accountId != null) {
      join.where(tx.accountId.equals(accountId));
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
          accountId: t.accountId,
        );
      }).toList();
    });
  }

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
        accountId: t.accountId,
      );
      return TxWithCategory(tx: txVm, category: c);
    }).toList();
  }

  // ------------------ RAPORLAR ------------------

  Future<SummaryTotals> fetchSummaryTotals({
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
  }) async {
    final tx = alias(transactions, 'tx');

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
      // ✅ SARI UYARILAR GİDERİLDİ (Ünlemler kaldırıldı)
      final cat = Category(
        id: r.read<int>('c_id'),
        name: r.read<String>('c_name'),
        colorHex: r.read<String>('c_color'),
      );
      final total = r.read<double?>('total_abs') ?? 0.0;
      return CategoryTotal(category: cat, total: total);
    }).toList();
  }

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
        rec['exp'] = (rec['exp'] ?? 0.0) + r.amount;
      }
    }

    final out = <MonthlyTotals>[];
    for (int i = 0; i < monthsBack; i++) {
      final m = DateTime(now.year, now.month - (monthsBack - 1) + i, 1);
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
        // ✅ SARI UYARILAR GİDERİLDİ
        final cat = Category(
          id: r.read<int>('c_id'),
          name: r.read<String>('c_name'),
          colorHex: r.read<String>('c_color'),
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

  // ------------------ VARLIKLAR (ASSETS) ------------------

  Stream<List<AssetItem>> watchAssets() {
    return (select(assets)..orderBy([(a) => OrderingTerm.asc(a.name)])).watch().map((rows) {
      return rows.map((r) => AssetItem(
        id: r.id,
        type: r.type,
        name: r.name,
        quantity: r.quantity,
        averagePrice: r.averagePrice,
        currentPrice: r.currentPrice,
        colorHex: r.colorHex,
        updatedAt: r.updatedAt,
      )).toList();
    });
  }

  Future<int> addAsset(AssetsCompanion data) => into(assets).insert(data);

  Future<int> updateAsset({
    required int id,
    double? quantity,
    double? averagePrice,
    double? currentPrice,
    bool clearCurrentPrice = false,
    String? name,
    DateTime? updatedAt,
  }) {
    final comp = AssetsCompanion(
      quantity: quantity != null ? Value(quantity) : const Value.absent(),
      averagePrice: averagePrice != null ? Value(averagePrice) : const Value.absent(),
      currentPrice: clearCurrentPrice
          ? const Value(null)
          : (currentPrice != null ? Value(currentPrice) : const Value.absent()),
      name: name != null ? Value(name) : const Value.absent(),
      updatedAt: updatedAt != null ? Value(updatedAt) : Value(DateTime.now()),
    );
    return (update(assets)..where((a) => a.id.equals(id))).write(comp);
  }

  Future<int> deleteAsset(int id) => (delete(assets)..where((a) => a.id.equals(id))).go();

  // ------------------ BİRİKİM HEDEFLERİ (SAVING GOALS) ------------------

  Stream<List<SavingGoalItem>> watchSavingGoals() {
    return (select(savingGoals)..orderBy([(g) => OrderingTerm.asc(g.createdAt)])).watch().map((rows) {
      return rows.map((r) => SavingGoalItem(
        id: r.id,
        title: r.title,
        targetAmount: r.targetAmount,
        currentAmount: r.currentAmount,
        targetDate: r.targetDate,
        colorHex: r.colorHex,
        iconName: r.iconName,
        createdAt: r.createdAt,
      )).toList();
    });
  }

  Future<int> addSavingGoal(SavingGoalsCompanion data) => into(savingGoals).insert(data);

  Future<int> updateSavingGoal({
    required int id,
    String? title,
    double? targetAmount,
    DateTime? targetDate,
    String? colorHex,
    String? iconName,
  }) {
    final comp = SavingGoalsCompanion(
      title: title != null ? Value(title) : const Value.absent(),
      targetAmount: targetAmount != null ? Value(targetAmount) : const Value.absent(),
      targetDate: targetDate != null ? Value(targetDate) : const Value.absent(),
      colorHex: colorHex != null ? Value(colorHex) : const Value.absent(),
      iconName: iconName != null ? Value(iconName) : const Value.absent(),
    );
    return (update(savingGoals)..where((g) => g.id.equals(id))).write(comp);
  }

  Future<int> deleteSavingGoal(int id) => (delete(savingGoals)..where((g) => g.id.equals(id))).go();

  Future<void> addMoneyToGoal(int id, double amountToAdd) async {
    final goal = await (select(savingGoals)..where((g) => g.id.equals(id))).getSingleOrNull();
    if (goal != null) {
      final newAmount = goal.currentAmount + amountToAdd;
      await (update(savingGoals)..where((g) => g.id.equals(id))).write(
        SavingGoalsCompanion(currentAmount: Value(newAmount)),
      );
    }
  }

  // ------------------ ✅ BORÇ VE ALACAKLAR (DEBTS) ------------------

  Stream<List<DebtItem>> watchDebts() {
    return (select(debts)..orderBy([(d) => OrderingTerm.desc(d.createdAt)])).watch().map((rows) {
      return rows.map((r) => DebtItem(
        id: r.id,
        personName: r.personName,
        amount: r.amount,
        isOwedToMe: r.isOwedToMe,
        isSettled: r.isSettled,
        dueDate: r.dueDate,
        createdAt: r.createdAt,
      )).toList();
    });
  }

  Future<int> addDebtWithTransaction({
    required String personName,
    required double amount,
    required bool isOwedToMe,
    DateTime? dueDate,
  }) async {
    return transaction(() async {
      final debtId = await into(debts).insert(DebtsCompanion.insert(
        personName: personName,
        amount: amount,
        isOwedToMe: isOwedToMe,
        dueDate: dueDate != null ? Value(dueDate) : const Value.absent(),
      ));

      final cats = await select(categories).get();
      Category? debtCategory;
      try {
        debtCategory = cats.firstWhere((c) => c.name.toLowerCase() == 'borç / alacak');
      } catch (_) {
        final catId = await addCategory(name: 'Borç / Alacak', colorHex: '#EF4444');
        debtCategory = Category(id: catId, name: 'Borç / Alacak', colorHex: '#EF4444');
      }

      final transactionAmount = isOwedToMe ? -amount : amount;
      final transactionNote = isOwedToMe ? '$personName kişisine borç verildi' : '$personName kişisinden borç alındı';

      await addTransaction(TransactionsCompanion.insert(
        amount: transactionAmount,
        categoryId: debtCategory.id,
        note: Value(transactionNote),
        date: Value(DateTime.now()),
      ));

      return debtId;
    });
  }

  Future<void> settleDebtWithTransaction(int id) async {
    return transaction(() async {
      final debt = await (select(debts)..where((d) => d.id.equals(id))).getSingleOrNull();
      if (debt == null || debt.isSettled) return;

      await (update(debts)..where((d) => d.id.equals(id))).write(
        const DebtsCompanion(isSettled: Value(true)),
      );

      final cats = await select(categories).get();
      Category? debtCategory;
      try {
        debtCategory = cats.firstWhere((c) => c.name.toLowerCase() == 'borç / alacak');
      } catch (_) {
        final catId = await addCategory(name: 'Borç / Alacak', colorHex: '#EF4444');
        debtCategory = Category(id: catId, name: 'Borç / Alacak', colorHex: '#EF4444');
      }

      // ✅ KIRMIZI HATA DÜZELTİLDİ: debt.personName olarak güncellendi.
      final transactionAmount = debt.isOwedToMe ? debt.amount : -debt.amount;
      final transactionNote = debt.isOwedToMe ? '${debt.personName} borcunu ödedi' : '${debt.personName} borcum ödendi';

      await addTransaction(TransactionsCompanion.insert(
        amount: transactionAmount,
        categoryId: debtCategory.id,
        note: Value(transactionNote),
        date: Value(DateTime.now()),
      ));
    });
  }

  Future<void> deleteDebt(int id) => (delete(debts)..where((d) => d.id.equals(id))).go();

  // ------------------ ✅ HESAPLAR (ACCOUNTS) ------------------

  /// Tüm hesapları ham satırlar + hesaplanmış işlem/transfer toplamları ile
  /// canlı olarak dinler. Bakiye hesabı domain katmanında yapılır.
  Stream<List<AccountRow>> watchAccountRows() {
    final q = customSelect(
      '''
      SELECT
        a.id              AS id,
        a.name            AS name,
        a.type            AS type,
        a.initial_balance AS initial_balance,
        a.color_hex       AS color_hex,
        a.icon_name       AS icon_name,
        a.credit_limit    AS credit_limit,
        a.statement_day   AS statement_day,
        a.due_day         AS due_day,
        a.is_archived     AS is_archived,
        (SELECT COALESCE(SUM(t.amount), 0)
           FROM transactions t WHERE t.account_id = a.id) AS tx_sum,
        (SELECT COALESCE(SUM(
            CASE WHEN tr.to_account_id = a.id THEN tr.amount ELSE -tr.amount END), 0)
           FROM transfers tr
           WHERE tr.from_account_id = a.id OR tr.to_account_id = a.id) AS transfer_sum
      FROM accounts a
      ORDER BY a.is_archived ASC, a.created_at ASC, a.id ASC
      ''',
      readsFrom: {accounts, transactions, transfers},
    );

    return q.watch().map((rows) {
      return rows.map((r) {
        return AccountRow(
          id: r.read<int>('id'),
          name: r.read<String>('name'),
          type: r.read<String>('type'),
          initialBalance: r.read<double>('initial_balance'),
          colorHex: r.read<String>('color_hex'),
          iconName: r.read<String>('icon_name'),
          creditLimit: r.read<double?>('credit_limit'),
          statementDay: r.read<int?>('statement_day'),
          dueDay: r.read<int?>('due_day'),
          isArchived: r.read<int>('is_archived') != 0,
          transactionSum: r.read<double>('tx_sum'),
          transferSum: r.read<double>('transfer_sum'),
        );
      }).toList();
    });
  }

  /// Kredi kartının cari ekstre dönemindeki toplam harcaması (pozitif).
  Future<double> periodSpendingForAccount({
    required int accountId,
    required DateTime start,
    required DateTime end,
  }) async {
    final q = selectOnly(transactions)
      ..addColumns([transactions.amount.sum()])
      ..where(transactions.accountId.equals(accountId))
      ..where(transactions.amount.isSmallerThanValue(0))
      ..where(transactions.date.isBiggerOrEqualValue(_startOfDay(start)))
      ..where(transactions.date.isSmallerOrEqualValue(_endOfDay(end)));

    final row = await q.getSingle();
    final sum = row.read(transactions.amount.sum()) ?? 0.0;
    return sum.abs();
  }

  Future<List<Account>> allAccounts({bool includeArchived = false}) {
    final q = select(accounts);
    if (!includeArchived) {
      q.where((a) => a.isArchived.equals(false));
    }
    q.orderBy([(a) => OrderingTerm.asc(a.createdAt)]);
    return q.get();
  }

  Future<int> addAccount(AccountsCompanion data) => into(accounts).insert(data);

  Future<int> updateAccount({
    required int id,
    String? name,
    String? type,
    double? initialBalance,
    String? colorHex,
    String? iconName,
    double? creditLimit,
    int? statementDay,
    int? dueDay,
    bool clearCreditDetails = false,
  }) {
    final comp = AccountsCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      type: type != null ? Value(type) : const Value.absent(),
      initialBalance:
          initialBalance != null ? Value(initialBalance) : const Value.absent(),
      colorHex: colorHex != null ? Value(colorHex) : const Value.absent(),
      iconName: iconName != null ? Value(iconName) : const Value.absent(),
      creditLimit: clearCreditDetails
          ? const Value(null)
          : (creditLimit != null ? Value(creditLimit) : const Value.absent()),
      statementDay: clearCreditDetails
          ? const Value(null)
          : (statementDay != null ? Value(statementDay) : const Value.absent()),
      dueDay: clearCreditDetails
          ? const Value(null)
          : (dueDay != null ? Value(dueDay) : const Value.absent()),
    );
    return (update(accounts)..where((a) => a.id.equals(id))).write(comp);
  }

  Future<int> setAccountArchived(int id, bool archived) {
    return (update(accounts)..where((a) => a.id.equals(id)))
        .write(AccountsCompanion(isArchived: Value(archived)));
  }

  Future<int> deleteAccount(int id) =>
      (delete(accounts)..where((a) => a.id.equals(id))).go();

  /// Hesaba bağlı işlem ve transferleri temizler (hesabı silmeden önce).
  Future<void> clearAccountReferences(int accountId) async {
    await transaction(() async {
      await (update(transactions)..where((t) => t.accountId.equals(accountId)))
          .write(const TransactionsCompanion(accountId: Value(null)));
      await (delete(transfers)
        ..where((t) =>
            t.fromAccountId.equals(accountId) | t.toAccountId.equals(accountId)))
          .go();
    });
  }

  // ------------------ ✅ TRANSFERLER ------------------

  Stream<List<TransferItem>> watchTransfers() {
    final from = alias(accounts, 'from_acc');
    final to = alias(accounts, 'to_acc');

    final q = select(transfers).join([
      innerJoin(from, from.id.equalsExp(transfers.fromAccountId)),
      innerJoin(to, to.id.equalsExp(transfers.toAccountId)),
    ])
      ..orderBy([OrderingTerm.desc(transfers.date), OrderingTerm.desc(transfers.id)]);

    return q.watch().map((rows) {
      return rows.map((row) {
        final t = row.readTable(transfers);
        return TransferItem(
          id: t.id,
          fromAccountId: t.fromAccountId,
          toAccountId: t.toAccountId,
          fromName: row.readTable(from).name,
          toName: row.readTable(to).name,
          amount: t.amount,
          note: t.note,
          date: t.date,
        );
      }).toList();
    });
  }

  Stream<List<TransferItem>> watchTransfersForAccount(int accountId) {
    final from = alias(accounts, 'from_acc');
    final to = alias(accounts, 'to_acc');

    final q = select(transfers).join([
      innerJoin(from, from.id.equalsExp(transfers.fromAccountId)),
      innerJoin(to, to.id.equalsExp(transfers.toAccountId)),
    ])
      ..where(transfers.fromAccountId.equals(accountId) |
          transfers.toAccountId.equals(accountId))
      ..orderBy([OrderingTerm.desc(transfers.date), OrderingTerm.desc(transfers.id)]);

    return q.watch().map((rows) {
      return rows.map((row) {
        final t = row.readTable(transfers);
        return TransferItem(
          id: t.id,
          fromAccountId: t.fromAccountId,
          toAccountId: t.toAccountId,
          fromName: row.readTable(from).name,
          toName: row.readTable(to).name,
          amount: t.amount,
          note: t.note,
          date: t.date,
        );
      }).toList();
    });
  }

  Future<int> addTransfer(TransfersCompanion data) => into(transfers).insert(data);

  Future<int> deleteTransfer(int id) =>
      (delete(transfers)..where((t) => t.id.equals(id))).go();
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

  /// İşlemin bağlı olduğu hesap (yoksa null).
  final int? accountId;

  Tx({
    required this.id,
    required this.amount,
    required this.note,
    required this.date,
    required this.category,
    this.accountId,
  });
}

class TxWithCategory {
  final Tx tx;
  final Category category;
  TxWithCategory({required this.tx, required this.category});
}

class SummaryTotals {
  final double income;
  final double expense;
  double get net => income - expense;
  SummaryTotals({required this.income, required this.expense});
}

class CategoryTotal {
  final Category category;
  final double total;
  CategoryTotal({required this.category, required this.total});
}

class MonthlyTotals {
  final DateTime month;
  final double income;
  final double expense;
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

class AssetItem {
  final int id;
  final String type;
  final String name;
  final double quantity;
  final double averagePrice;
  final double? currentPrice;
  final String colorHex;
  final DateTime updatedAt;

  double get totalCost => quantity * averagePrice;

  /// Güncel değer. Fiyat girilmemişse maliyete eşit kabul edilir.
  double get currentValue => quantity * (currentPrice ?? averagePrice);

  double get profitLoss => currentValue - totalCost;

  double get profitLossPercent {
    if (totalCost <= 0) return 0;
    return profitLoss / totalCost;
  }

  bool get hasLivePrice => currentPrice != null;

  AssetItem({
    required this.id,
    required this.type,
    required this.name,
    required this.quantity,
    required this.averagePrice,
    required this.currentPrice,
    required this.colorHex,
    required this.updatedAt,
  });
}

class SavingGoalItem {
  final int id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final String colorHex;
  final String iconName;
  final DateTime createdAt;

  double get progress => targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
  double get remainingAmount => (targetAmount - currentAmount).clamp(0.0, double.infinity);

  SavingGoalItem({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
    required this.colorHex,
    required this.iconName,
    required this.createdAt,
  });
}

class DebtItem {
  final int id;
  final String personName;
  final double amount;
  final bool isOwedToMe;
  final bool isSettled;
  final DateTime? dueDate;
  final DateTime createdAt;

  DebtItem({
    required this.id,
    required this.personName,
    required this.amount,
    required this.isOwedToMe,
    required this.isSettled,
    this.dueDate,
    required this.createdAt,
  });
}

/// Hesabın ham veritabanı satırı + hesaplanmış işlem/transfer toplamları.
/// Bakiye ve kredi kartı hesapları domain katmanında ([AccountEngine]) yapılır.
class AccountRow {
  final int id;
  final String name;
  final String type;
  final double initialBalance;
  final String colorHex;
  final String iconName;
  final double? creditLimit;
  final int? statementDay;
  final int? dueDay;
  final bool isArchived;
  final double transactionSum;
  final double transferSum;

  AccountRow({
    required this.id,
    required this.name,
    required this.type,
    required this.initialBalance,
    required this.colorHex,
    required this.iconName,
    required this.isArchived,
    required this.transactionSum,
    required this.transferSum,
    this.creditLimit,
    this.statementDay,
    this.dueDay,
  });
}

/// Hesaplar arası transfer kaydı (hesap adları dahil).
class TransferItem {
  final int id;
  final int fromAccountId;
  final int toAccountId;
  final String fromName;
  final String toName;
  final double amount;
  final String? note;
  final DateTime date;

  TransferItem({
    required this.id,
    required this.fromAccountId,
    required this.toAccountId,
    required this.fromName,
    required this.toName,
    required this.amount,
    required this.note,
    required this.date,
  });
}