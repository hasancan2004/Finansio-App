// Çoklu Hesap & Kredi Kartı modülünün domain modelleri.
//
// Bu katman Flutter / Drift bağımlılığı içermez; yalnızca iş kurallarını
// ve hesaplanmış değerleri taşır. Veritabanı satırları `domain/engine`
// içindeki AccountEngine ile bu modellere dönüştürülür.

/// Desteklenen hesap türleri.
enum AccountType {
  cash('cash', 'Nakit Cüzdan'),
  bank('bank', 'Banka Hesabı'),
  creditCard('credit_card', 'Kredi Kartı');

  /// Drift tablosundaki `type` alanına yazılan değer.
  final String dbValue;

  /// Kullanıcıya gösterilen etiket.
  final String label;

  const AccountType(this.dbValue, this.label);

  bool get isCreditCard => this == AccountType.creditCard;

  /// Kredi kartı dışındaki "likit/varlık" hesapları mı?
  bool get isAsset => this != AccountType.creditCard;

  static AccountType fromDb(String value) {
    return AccountType.values.firstWhere(
      (t) => t.dbValue == value,
      orElse: () => AccountType.cash,
    );
  }
}

/// Bir hesabın, işlem ve transferler dahil edilerek hesaplanmış özeti.
class AccountSummary {
  final int id;
  final String name;
  final AccountType type;

  /// Hesabın açılış bakiyesi (kredi kartlarında negatif = açılış borcu).
  final double initialBalance;

  /// Başlangıç bakiyesi + hesaba bağlı işlemler + transferler.
  /// Kredi kartları için negatif değer borcu ifade eder.
  final double currentBalance;

  /// Cari ekstre dönemindeki harcama toplamı (kredi kartları için).
  final double periodSpent;

  final String colorHex;
  final String iconName;
  final bool isArchived;

  final double? creditLimit;
  final int? statementDay;
  final int? dueDay;

  /// Cari dönemin başlangıcı (önceki kesim) ve sonu (sonraki kesim).
  final DateTime? statementStart;
  final DateTime? statementEnd;

  /// Bir sonraki son ödeme tarihi.
  final DateTime? dueDate;

  const AccountSummary({
    required this.id,
    required this.name,
    required this.type,
    required this.initialBalance,
    required this.currentBalance,
    required this.colorHex,
    required this.iconName,
    required this.isArchived,
    this.periodSpent = 0,
    this.creditLimit,
    this.statementDay,
    this.dueDay,
    this.statementStart,
    this.statementEnd,
    this.dueDate,
  });

  bool get isCreditCard => type.isCreditCard;

  /// Kredi kartı için toplam borç (negatif bakiye varsa pozitif döner).
  double get debt {
    if (!isCreditCard) return 0;
    return currentBalance < 0 ? -currentBalance : 0;
  }

  /// Kullanılabilir limit.
  double? get availableLimit {
    if (!isCreditCard || creditLimit == null) return null;
    return (creditLimit! - debt).clamp(0.0, double.infinity);
  }

  /// Limit kullanım oranı (0..1).
  double? get utilization {
    if (!isCreditCard || creditLimit == null || creditLimit! <= 0) return null;
    return (debt / creditLimit!).clamp(0.0, 1.0);
  }

  /// Son ödeme tarihi 7 gün içinde mi?
  bool get isDueSoon {
    final due = dueDate;
    if (due == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    final diff = dueDay.difference(today).inDays;
    return diff >= 0 && diff <= 7;
  }

  /// Vade geçti mi?
  bool get isOverdue {
    final due = dueDate;
    if (due == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    return dueDay.isBefore(today) && debt > 0;
  }
}
