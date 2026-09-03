import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finansio/data/database/app_database.dart';
import 'package:finansio/domain/models/summary.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// --- Global DB Provider ---
/// main.dart içinde ProviderScope -> overrides ile gerçek DB enjekte edilecek
final dbProvider = Provider<AppDatabase>((ref) => throw UnimplementedError());

/// --- Tarih Aralığı (hızlı filtre) ---
enum FilterRange { all, thisMonth, lastMonth }

final txFilterProvider = StateProvider<FilterRange>((ref) {
  return FilterRange.thisMonth;
});

/// --- Global tarih aralığı ---
/// null => global aralık yok; hızlı chip’ler devreye girer.
final globalDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

/// --- Kategori / Tutar Filtreleri ---
final categoryIdFilterProvider = StateProvider<int?>((ref) => null);
final minAmountFilterProvider = StateProvider<double?>((ref) => null);
final maxAmountFilterProvider = StateProvider<double?>((ref) => null);

/// --- Arama (not / kategori adı)---
final searchQueryProvider = StateProvider<String?>((ref) => null);

/// --- Sıralama ---
enum TxSortBy { date, amount }
enum SortOrder { asc, desc }

final sortByProvider = StateProvider<TxSortBy>((ref) => TxSortBy.date);
final sortOrderProvider = StateProvider<SortOrder>((ref) => SortOrder.desc);

/// Ay yardımcıları
DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);
DateTime _monthEndInclusive(DateTime d) =>
    DateTime(d.year, d.month + 1, 0, 23, 59, 59, 999);

/// ------------------------------------------------------------
/// 1) Ana işlem listesi (kullanıcının seçtiği filtre/sıralama/arama vs.)
/// ------------------------------------------------------------
final txStreamProvider = StreamProvider<List<Tx>>((ref) {
  final db = ref.watch(dbProvider);
  final filter = ref.watch(txFilterProvider);

  // Hızlı tarih aralığı
  final range = ref.watch(globalDateRangeProvider);
  final searchQuery = ref.watch(searchQueryProvider);

  DateTime? start;
  DateTime? end;

  if (range != null) {
    start = DateTime(range.start.year, range.start.month, range.start.day, 0, 0, 0);
    end = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59, 999);
  } else {
    final now = DateTime.now();
    switch (filter) {
      case FilterRange.all:
        break;
      case FilterRange.thisMonth:
        start = _monthStart(now);
        end = _monthEndInclusive(now);
        break;
      case FilterRange.lastMonth:
        final last = DateTime(now.year, now.month - 1, 1);
        start = _monthStart(last);
        end = _monthEndInclusive(last);
        break;
    }
  }

  // Ek filtreler
  final categoryId = ref.watch(categoryIdFilterProvider);
  final minAmount = ref.watch(minAmountFilterProvider);
  final maxAmount = ref.watch(maxAmountFilterProvider);

  // Arama
  final query = searchQuery;

  // Sıralama
  final sortBy = ref.watch(sortByProvider);
  final order = ref.watch(sortOrderProvider);

  return db.watchTransactions(
    startDate: start,
    endDate: end,
    categoryId: categoryId,
    minAmount: minAmount,
    maxAmount: maxAmount,
    sortByAmount: sortBy == TxSortBy.amount,
    sortAsc: order == SortOrder.asc,
    query: query,
  );
});

/// --- Özet (Gelir/Gider/Net) -> ekranda filtrelenmiş listeye göre ---
final summaryProvider = Provider.autoDispose<Summary>((ref) {
  final asyncTxs = ref.watch(txStreamProvider);

  return asyncTxs.maybeWhen(
    data: (list) {
      double income = 0, expense = 0;
      for (final t in list) {
        if (t.amount >= 0) {
          income += t.amount;
        } else {
          expense += t.amount; // negatif
        }
      }
      final net = income + expense;
      return Summary(income: income, expense: expense, net: net);
    },
    orElse: () => const Summary(income: 0, expense: 0, net: 0),
  );
});

/// ------------------------------------------------------------
/// 2) "Bu ay" toplamlarını HER ZAMAN hesaplayan ayrı provider (global limit için)
///    - Home filter değişse de global limit bu ay toplam gider üzerinden çalışır.
/// ------------------------------------------------------------
final thisMonthTxsProvider = StreamProvider<List<Tx>>((ref) {
  final db = ref.watch(dbProvider);
  final now = DateTime.now();
  final start = _monthStart(now);
  final end = _monthEndInclusive(now);

  return db.watchTransactions(
    startDate: start,
    endDate: end,
    categoryId: null,
    minAmount: null,
    maxAmount: null,
    sortByAmount: false,
    sortAsc: false,
    query: null,
  );
});

final thisMonthSummaryProvider = Provider<Summary>((ref) {
  final asyncTxs = ref.watch(thisMonthTxsProvider);

  return asyncTxs.maybeWhen(
    data: (list) {
      double income = 0, expense = 0;
      for (final t in list) {
        if (t.amount >= 0) {
          income += t.amount;
        } else {
          expense += t.amount;
        }
      }
      final net = income + expense;
      return Summary(income: income, expense: expense, net: net);
    },
    orElse: () => const Summary(income: 0, expense: 0, net: 0),
  );
});

/// ------------------------------------------------------------
/// 3) GENEL AYLIK LIMIT (SharedPreferences)
/// ------------------------------------------------------------
class GlobalLimitState {
  final bool enabled;
  final double amount; // limit (₺)

  const GlobalLimitState({
    required this.enabled,
    required this.amount,
  });

  GlobalLimitState copyWith({bool? enabled, double? amount}) {
    return GlobalLimitState(
      enabled: enabled ?? this.enabled,
      amount: amount ?? this.amount,
    );
  }
}

class GlobalLimitNotifier extends StateNotifier<GlobalLimitState> {
  GlobalLimitNotifier() : super(const GlobalLimitState(enabled: false, amount: 0)) {
    _load();
  }

  static const _kEnabled = 'global_monthly_limit_enabled';
  static const _kAmount = 'global_monthly_limit_amount';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kEnabled) ?? false;
    final amount = prefs.getDouble(_kAmount) ?? 0.0;
    state = GlobalLimitState(enabled: enabled, amount: amount);
  }

  Future<void> setEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, v);
    state = state.copyWith(enabled: v);
  }

  Future<void> setAmount(double v) async {
    final safe = v < 0 ? 0.0 : v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kAmount, safe);
    state = state.copyWith(amount: safe);
  }
}

final globalMonthlyLimitProvider =
StateNotifierProvider<GlobalLimitNotifier, GlobalLimitState>((ref) {
  return GlobalLimitNotifier();
});

class GlobalLimitStatus {
  final bool enabled;
  final double limit;
  final double spent; // bu ay toplam gider (pozitif)
  final double progress; // spent / limit
  final bool near; // >= 0.8 && < 1.0
  final bool exceeded; // >= 1.0

  const GlobalLimitStatus({
    required this.enabled,
    required this.limit,
    required this.spent,
    required this.progress,
    required this.near,
    required this.exceeded,
  });
}

/// Global limit durumu (bu ay toplam gider üstünden)
final globalLimitStatusProvider = Provider<GlobalLimitStatus>((ref) {
  final limitState = ref.watch(globalMonthlyLimitProvider);
  final monthSummary = ref.watch(thisMonthSummaryProvider);

  final spent = monthSummary.expense.abs(); // expense negatif, abs alıyoruz

  if (!limitState.enabled || limitState.amount <= 0) {
    return GlobalLimitStatus(
      enabled: false,
      limit: limitState.amount,
      spent: spent,
      progress: 0,
      near: false,
      exceeded: false,
    );
  }

  final progress = spent / limitState.amount;
  final exceeded = progress >= 1.0;
  final near = progress >= 0.8 && progress < 1.0;

  return GlobalLimitStatus(
    enabled: true,
    limit: limitState.amount,
    spent: spent,
    progress: progress,
    near: near,
    exceeded: exceeded,
  );
});

/// BottomNav / UI badge için hızlı bool
final anyGlobalLimitAlertProvider = Provider<bool>((ref) {
  final s = ref.watch(globalLimitStatusProvider);
  return s.enabled && (s.near || s.exceeded);
});

final anyGlobalLimitExceededProvider = Provider<bool>((ref) {
  final s = ref.watch(globalLimitStatusProvider);
  return s.enabled && s.exceeded;
});

/// --- UI etiketi yardımcıları ---
extension FilterRangeLabel on FilterRange {
  String get label {
    switch (this) {
      case FilterRange.all:
        return 'Tümü';
      case FilterRange.thisMonth:
        return 'Bu Ay';
      case FilterRange.lastMonth:
        return 'Geçen Ay';
    }
  }
}
