import 'package:finansio/data/database/app_database.dart';
import 'package:finansio/presentation/transactions/viewmodel/tx_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// UI'ın gösterdiği yıl/ay Home'dan/Screenden yönetebilmek için state

final currentYearProvider = StateProvider<int>((ref) => DateTime.now().year);
final currentMonthProvider = StateProvider<int>((ref) => DateTime.now().month);

// Seçili tarih (yıl/ay) için tüm kategori bütçe durumları (BudgetStatus listesi)
final budgetStatusesProvider =
StreamProvider.autoDispose<List<BudgetStatus>>((ref) {
  final db = ref.watch(dbProvider);
  final year = ref.watch(currentYearProvider);
  final month = ref.watch(currentMonthProvider);
  return db.watchBudgetStatuses(year: year, month: month);
});

/// Herhangi bir kategoride bütçe AŞILMIŞ mı? (progress > 1)
final anyBudgetExceededProvider = Provider.autoDispose<bool>((ref) {
  final async = ref.watch(budgetStatusesProvider);
  return async.maybeWhen(
    data: (list) => list.any((b) => (b.progress ?? 0) > 1.0),
    orElse: () => false,
  );
});

/// İstersek: Limite YAKLAŞMIŞ kategori var mı? (0.8 < progress <= 1)
final anyBudgetNearLimitProvider = Provider.autoDispose<bool>((ref) {
  final async = ref.watch(budgetStatusesProvider);
  return async.maybeWhen(
    data: (list) =>
        list.any((b) => (b.progress ?? 0) > 0.8 && (b.progress ?? 0) <= 1.0),
    orElse: () => false,
  );
});

/// Upsert helper
final upsertBudgetProvider =
FutureProvider.family.autoDispose<void, UpsertBudgetArgs>((ref, args) async {
  final db = ref.read(dbProvider);
  await db.upsertBudget(
    categoryId: args.categoryId,
    year: args.year,
    month: args.month,
    amount: args.amount,
  );
});

/// Delete helper
final deleteBudgetProvider =
FutureProvider.family.autoDispose<void, DeleteBudgetArgs>((ref, args) async {
  final db = ref.read(dbProvider);
  await db.deleteBudget(
    categoryId: args.categoryId,
    year: args.year,
    month: args.month,
  );
});

class UpsertBudgetArgs {
  final int categoryId, year, month;
  final double amount;
  UpsertBudgetArgs({
    required this.categoryId,
    required this.year,
    required this.month,
    required this.amount,
  });
}

class DeleteBudgetArgs {
  final int categoryId, year, month;
  DeleteBudgetArgs({
    required this.categoryId,
    required this.year,
    required this.month,
  });
}
