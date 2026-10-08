import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../domain/engine/account_engine.dart';
import '../../../domain/models/account.dart';
import '../../transactions/viewmodel/tx_providers.dart';

/// ------------------------------------------------------------
/// 1) Hesapları (hesaplanmış bakiye/kart bilgisiyle) canlı dinler
/// ------------------------------------------------------------
final accountsStreamProvider =
    StreamProvider.autoDispose<List<AccountSummary>>((ref) {
  final db = ref.watch(dbProvider);

  return db.watchAccountRows().asyncMap((rows) async {
    final now = DateTime.now();
    final out = <AccountSummary>[];

    for (final r in rows) {
      final type = AccountType.fromDb(r.type);

      double periodSpent = 0;
      if (type.isCreditCard && r.statementDay != null) {
        final period = AccountEngine.statementPeriod(now, r.statementDay!);
        periodSpent = await db.periodSpendingForAccount(
          accountId: r.id,
          start: period.start,
          end: period.end,
        );
      }

      out.add(AccountEngine.summarize(
        id: r.id,
        name: r.name,
        type: type,
        initialBalance: r.initialBalance,
        transactionSum: r.transactionSum,
        transferSum: r.transferSum,
        colorHex: r.colorHex,
        iconName: r.iconName,
        isArchived: r.isArchived,
        periodSpent: periodSpent,
        creditLimit: r.creditLimit,
        statementDay: r.statementDay,
        dueDay: r.dueDay,
        now: now,
      ));
    }

    return out;
  });
});

/// Arşivlenmemiş hesaplar (dropdown / seçim için).
final activeAccountsProvider =
    Provider.autoDispose<List<AccountSummary>>((ref) {
  final async = ref.watch(accountsStreamProvider);
  return async.maybeWhen(
    data: (list) => list.where((a) => !a.isArchived).toList(),
    orElse: () => const [],
  );
});

/// ------------------------------------------------------------
/// 2) Genel özet (net değer / varlık / kart borcu)
/// ------------------------------------------------------------
class AccountsSummary {
  final double netWorth;
  final double assets;
  final double cardDebt;
  final int accountCount;

  const AccountsSummary({
    required this.netWorth,
    required this.assets,
    required this.cardDebt,
    required this.accountCount,
  });

  const AccountsSummary.empty()
      : netWorth = 0,
        assets = 0,
        cardDebt = 0,
        accountCount = 0;
}

final accountsSummaryProvider = Provider.autoDispose<AccountsSummary>((ref) {
  final async = ref.watch(accountsStreamProvider);
  return async.maybeWhen(
    data: (list) {
      final active = list.where((a) => !a.isArchived).toList();
      return AccountsSummary(
        netWorth: AccountEngine.totalNetWorth(active),
        assets: AccountEngine.totalAssets(active),
        cardDebt: AccountEngine.totalCardDebt(active),
        accountCount: active.length,
      );
    },
    orElse: () => const AccountsSummary.empty(),
  );
});

/// ------------------------------------------------------------
/// 3) Transferler
/// ------------------------------------------------------------
final transfersStreamProvider =
    StreamProvider.autoDispose<List<TransferItem>>((ref) {
  final db = ref.watch(dbProvider);
  return db.watchTransfers();
});

/// Bir hesaba ait işlemler.
final accountTransactionsProvider = StreamProvider.autoDispose
    .family<List<Tx>, int>((ref, accountId) {
  final db = ref.watch(dbProvider);
  return db.watchTransactions(accountId: accountId);
});

/// Bir hesaba ait transferler.
final accountTransfersProvider = StreamProvider.autoDispose
    .family<List<TransferItem>, int>((ref, accountId) {
  final db = ref.watch(dbProvider);
  return db.watchTransfersForAccount(accountId);
});

/// ------------------------------------------------------------
/// 4) Controller (ekle / güncelle / sil / transfer)
/// ------------------------------------------------------------
final accountsControllerProvider =
    Provider.autoDispose<AccountsController>((ref) {
  final db = ref.watch(dbProvider);
  return AccountsController(db);
});

class AccountsController {
  final AppDatabase _db;
  AccountsController(this._db);

  Future<int> addAccount({
    required String name,
    required AccountType type,
    required double initialBalance,
    required String colorHex,
    required String iconName,
    double? creditLimit,
    int? statementDay,
    int? dueDay,
  }) {
    return _db.addAccount(AccountsCompanion.insert(
      name: name,
      type: Value(type.dbValue),
      initialBalance: Value(initialBalance),
      colorHex: Value(colorHex),
      iconName: Value(iconName),
      creditLimit:
          creditLimit != null ? Value(creditLimit) : const Value.absent(),
      statementDay:
          statementDay != null ? Value(statementDay) : const Value.absent(),
      dueDay: dueDay != null ? Value(dueDay) : const Value.absent(),
    ));
  }

  Future<void> updateAccount({
    required int id,
    required String name,
    required AccountType type,
    required double initialBalance,
    required String colorHex,
    required String iconName,
    double? creditLimit,
    int? statementDay,
    int? dueDay,
  }) {
    final isCard = type.isCreditCard;
    return _db.updateAccount(
      id: id,
      name: name,
      type: type.dbValue,
      initialBalance: initialBalance,
      colorHex: colorHex,
      iconName: iconName,
      creditLimit: isCard ? (creditLimit ?? 0) : null,
      statementDay: isCard ? statementDay : null,
      dueDay: isCard ? dueDay : null,
      clearCreditDetails: !isCard,
    );
  }

  Future<void> setArchived(int id, bool archived) =>
      _db.setAccountArchived(id, archived);

  /// Hesabı siler. Bağlı işlemlerin hesap bağlantısı kaldırılır,
  /// bağlı transferler silinir.
  Future<void> deleteAccount(int id) async {
    await _db.clearAccountReferences(id);
    await _db.deleteAccount(id);
  }

  Future<void> addTransfer({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    DateTime? date,
    String? note,
  }) {
    return _db.addTransfer(TransfersCompanion.insert(
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      amount: amount,
      note: note != null && note.trim().isNotEmpty
          ? Value(note.trim())
          : const Value.absent(),
      date: date != null ? Value(date) : const Value.absent(),
    ));
  }

  Future<void> deleteTransfer(int id) => _db.deleteTransfer(id);
}
