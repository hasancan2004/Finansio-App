// Banka SMS / bildirim metinlerinden işlem çözümleyen saf parser.
//
// Flutter / Drift bağımlılığı içermez; yalnızca metinden tutar, yön
// (gelir/gider) ve kategori tahmini üretir. Otomatik işlem yakalama
// özelliğinin kalbidir.

class ParsedTransaction {
  final double amount;
  final bool isIncome;
  final String note;
  final String? categoryName;

  const ParsedTransaction({
    required this.amount,
    required this.isIncome,
    required this.note,
    this.categoryName,
  });
}

class TransactionParser {
  TransactionParser._();

  /// Metni çözümler; tutar bulunamazsa null döner.
  static ParsedTransaction? parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final amount = _extractAmount(text);
    if (amount == null || amount <= 0) return null;

    return ParsedTransaction(
      amount: amount,
      isIncome: _isIncome(text),
      note: _cleanNote(text),
      categoryName: _guessCategory(text),
    );
  }

  /// "1.234,56 TL", "500 TL", "500₺", "250.75" gibi kalıpları yakalar.
  static double? _extractAmount(String text) {
    final regex = RegExp(
      r'(\d{1,3}(?:\.\d{3})*|\d+)(?:,\d{1,2})?\s*(?:TL|₺)',
      caseSensitive: false,
    );
    final m = regex.firstMatch(text);
    if (m == null) return null;

    var raw = m.group(0)!;
    raw = raw.replaceAll(RegExp(r'\s*(TL|₺)\s*$', caseSensitive: false), '');
    raw = raw.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(raw);
  }

  static bool _isIncome(String text) {
    final lower = _norm(text);
    final income = [
      'geldi',
      'yatti',
      'yattı',
      'iade',
      'alacak',
      'havale geldi',
      'hesabınıza',
      'hesabiniza',
      'hesaba ge',
      'yatan',
      'aktarıldı',
    ];
    final expense = [
      'harcama',
      'harcandı',
      'harcandi',
      'cekildi',
      'çekildi',
      'odeme',
      'ödeme',
      'alışveriş',
      'alisveris',
      'pos',
      'tahsilat',
    ];
    for (final w in income) {
      if (lower.contains(w)) return true;
    }
    for (final w in expense) {
      if (lower.contains(w)) return false;
    }
    return false; // varsayılan: gider
  }

  static String _cleanNote(String text) {
    var note = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (note.length > 80) note = '${note.substring(0, 80)}…';
    return note;
  }

  static String? _guessCategory(String text) {
    final lower = _norm(text);

    const rules = <String, List<String>>{
      'Yemek': ['market', 'bakkal', 'yemek', 'restoran', 'kafe', 'cafe', 'migros', 'a101', 'bim'],
      'Ulaşım': ['benzin', 'akaryakit', 'akaryakıt', 'taksi', 'otobus', 'otobüs', 'metro', 'tramvay', 'kargo'],
      'Fatura': ['fatura', 'elektrik', 'su ', 'dogalgaz', 'doğalgaz', 'internet', 'telekom', 'gsm', 'aidat'],
      'Abonelik': ['netflix', 'spotify', 'youtube', 'disney', 'icloud', 'blutv', 'exxen', 'premium'],
      'Maaş': ['maas', 'maaş', 'ucret', 'ücret', 'odeme alindi', 'ödeme alındı'],
      'Eğlence': ['sinema', 'oyun', 'steam', 'playstation', 'ps store', 'ticket'],
      'Sağlık': ['eczane', 'doktor', 'hastane', 'ilac', 'ilaç'],
    };

    for (final e in rules.entries) {
      for (final k in e.value) {
        if (lower.contains(k)) return e.key;
      }
    }
    return null;
  }

  static String _norm(String s) {
    return s
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ç', 'c')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u');
  }
}
