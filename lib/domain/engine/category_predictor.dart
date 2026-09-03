// lib/ai/category_predictor.dart
enum PredictionConfidenceLevel { high, medium, low }

class CategoryPrediction {
  final String categoryName;
  final double confidence; // 0.0 - 1.0
  final List<String> matchedKeywords;
  final PredictionConfidenceLevel level;

  const CategoryPrediction({
    required this.categoryName,
    required this.confidence,
    required this.matchedKeywords,
    required this.level,
  });
}

class CategoryPredictor {
  // Kategori -> keyword listesi (TR + marka isimleri)
  static const Map<String, List<String>> _keywords = {
    "Market": ["a101", "bim", "şok", "sok", "migros", "carrefour", "market"],
    "Yeme-İçme": ["burger", "pizza", "kfc", "mcdonald", "starbucks", "kafe", "restoran", "yemek"],
    "Ulaşım": ["uber", "bitaksi", "taksi", "metro", "otobüs", "tramvay", "iett"],
    "Fatura": ["elektrik", "su", "doğalgaz", "internet", "fatura", "vodafone", "turkcell", "turktelekom"],
    "Eğlence": ["netflix", "spotify", "sinema", "oyun", "steam"],
    "Sağlık": ["eczane", "hastane", "doktor", "ilaç"],
    "Alışveriş": ["trendyol", "hepsiburada", "amazon", "n11", "lcw", "defacto"],
  };

  static CategoryPrediction predict(String description) {
    final text = _normalize(description);

    // hiç açıklama yoksa
    if (text.trim().isEmpty) {
      return const CategoryPrediction(
        categoryName: "Diğer",
        confidence: 0.0,
        matchedKeywords: [],
        level: PredictionConfidenceLevel.low,
      );
    }

    String bestCategory = "Diğer";
    int bestScore = 0;
    List<String> bestMatches = [];

    for (final entry in _keywords.entries) {
      final category = entry.key;
      final words = entry.value;

      int score = 0;
      final matches = <String>[];

      for (final w in words) {
        if (text.contains(w)) {
          score += _scoreOf(w);
          matches.add(w);
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestCategory = category;
        bestMatches = matches;
      }
    }

    // confidence: kaba bir oran (keyword sayısı + toplam skor)
    final confidence = bestScore == 0
        ? 0.0
        : (bestScore / 10.0).clamp(0.0, 1.0); // 10 üstünü 1'e kırp
    final lvl = confidence >= 0.80
         ? PredictionConfidenceLevel.high
        : (confidence >= 0.55 ? PredictionConfidenceLevel.medium : PredictionConfidenceLevel.low);
    return CategoryPrediction(
      categoryName: bestScore == 0 ? "Diğer" : bestCategory,
      confidence: confidence,
      matchedKeywords: bestMatches,
      level: lvl,
    );
  }

  static String _normalize(String s) {
    var x = s.toLowerCase().trim();

    // Türkçe karakter normalize (basit)
    x = x
        .replaceAll("ı", "i")
        .replaceAll("ş", "s")
        .replaceAll("ğ", "g")
        .replaceAll("ç", "c")
        .replaceAll("ö", "o")
        .replaceAll("ü", "u");

    // noktalama temizle (basit)
    x = x.replaceAll(RegExp(r"[^a-z0-9\s]"), " ");

    // çoklu boşluk
    x = x.replaceAll(RegExp(r"\s+"), " ");

    return x;
  }

  static int _scoreOf(String keyword) {
    // marka/özel kelimelere biraz daha puan verelim
    if (keyword.length >= 7) return 3;
    return 2;
  }
}
