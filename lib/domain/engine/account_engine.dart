import '../models/account.dart';

/// Hesap bakiyesi ve kredi kartı ekstre hesaplamalarını yapan saf iş kuralı motoru.
///
/// Bu sınıf Flutter / veritabanı bağımlılığı içermez. Veritabanından gelen ham
/// değerler [summarize] metoduna verilir ve UI'ın kullanacağı
/// [AccountSummary] üretilir.
class AccountEngine {
  const AccountEngine._();

  /// Ham değerlerden hesaplanmış özet üretir.
  static AccountSummary summarize({
    required int id,
    required String name,
    required AccountType type,
    required double initialBalance,
    required double transactionSum,
    required double transferSum,
    required String colorHex,
    required String iconName,
    required bool isArchived,
    double periodSpent = 0,
    double? creditLimit,
    int? statementDay,
    int? dueDay,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final balance = initialBalance + transactionSum + transferSum;

    DateTime? statementStart;
    DateTime? statementEnd;
    DateTime? dueDate;

    if (type.isCreditCard && statementDay != null) {
      final period = statementPeriod(today, statementDay);
      statementStart = period.start;
      statementEnd = period.end;
      if (dueDay != null) {
        dueDate = dueDateFor(period.end, dueDay);
      }
    }

    return AccountSummary(
      id: id,
      name: name,
      type: type,
      initialBalance: initialBalance,
      currentBalance: balance,
      periodSpent: periodSpent,
      colorHex: colorHex,
      iconName: iconName,
      isArchived: isArchived,
      creditLimit: creditLimit,
      statementDay: statementDay,
      dueDay: dueDay,
      statementStart: statementStart,
      statementEnd: statementEnd,
      dueDate: dueDate,
    );
  }

  /// `statementDay` (kesim günü) baz alınarak içinde bulunulan ekstre dönemini
  /// `[start, end)` olarak döner. `start` en son kesim, `end` bir sonraki kesim.
  static ({DateTime start, DateTime end}) statementPeriod(
    DateTime now,
    int statementDay,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final thisMonthCut = _clampDay(now.year, now.month, statementDay);

    final DateTime start;
    if (!today.isBefore(thisMonthCut)) {
      start = thisMonthCut;
    } else {
      final prev = DateTime(now.year, now.month - 1, 1);
      start = _clampDay(prev.year, prev.month, statementDay);
    }

    final nextMonth = DateTime(start.year, start.month + 1, 1);
    final end = _clampDay(nextMonth.year, nextMonth.month, statementDay);
    return (start: start, end: end);
  }

  /// Bir sonraki son ödeme tarihini (vade) hesaplar.
  ///
  /// `dueDay`, kesim tarihinden sonraki (veya aynı gün) ilk uygun güne denk gelir.
  static DateTime dueDateFor(DateTime statementEnd, int dueDay) {
    final sameMonth = _clampDay(statementEnd.year, statementEnd.month, dueDay);
    if (!sameMonth.isBefore(statementEnd)) return sameMonth;

    final nextMonth = DateTime(statementEnd.year, statementEnd.month + 1, 1);
    return _clampDay(nextMonth.year, nextMonth.month, dueDay);
  }

  /// Tüm hesapların net değeri. Kredi kartı borçları negatif bakiye olarak
  /// zaten toplama yansır.
  static double totalNetWorth(List<AccountSummary> accounts) {
    return accounts
        .where((a) => !a.isArchived)
        .fold(0.0, (sum, a) => sum + a.currentBalance);
  }

  /// Yalnızca likit varlıkların (nakit + banka) toplamı.
  static double totalAssets(List<AccountSummary> accounts) {
    return accounts
        .where((a) => !a.isArchived && a.type.isAsset)
        .fold(0.0, (sum, a) => sum + a.currentBalance);
  }

  /// Toplam kredi kartı borcu (pozitif).
  static double totalCardDebt(List<AccountSummary> accounts) {
    return accounts
        .where((a) => !a.isArchived && a.isCreditCard)
        .fold(0.0, (sum, a) => sum + a.debt);
  }

  static int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  static DateTime _clampDay(int year, int month, int day) {
    final last = _daysInMonth(year, month);
    final safe = day < 1 ? 1 : (day > last ? last : day);
    return DateTime(year, month, safe);
  }
}
