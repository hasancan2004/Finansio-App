// lib/utils/text_utils.dart
class TextUtils {
  static String normalize(String s) {
    var x = s.toLowerCase().trim();
    x = x
        .replaceAll("ı", "i")
        .replaceAll("ş", "s")
        .replaceAll("ğ", "g")
        .replaceAll("ç", "c")
        .replaceAll("ö", "o")
        .replaceAll("ü", "u");
    x = x.replaceAll(RegExp(r"[^a-z0-9\s]"), " ");
    x = x.replaceAll(RegExp(r"\s+"), " ").trim();
    return x;
  }

  static List<String> extractTokens(String text) {
    final n = normalize(text);
    if (n.isEmpty) return const [];

    final parts = n.split(' ').where((e) => e.trim().isNotEmpty).toList();

    // mini stopwords
    const stop = {
      "ve", "ile", "icin", "icın", "bu", "su", "bir", "ben", "sen", "o",
      "tl", "try", "lira", "adet"
    };

    final out = <String>[];
    for (final p in parts) {
      if (p.length < 2) continue;
      if (stop.contains(p)) continue;
      out.add(p);
    }
    return out;
  }
}
