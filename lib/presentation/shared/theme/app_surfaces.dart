import 'package:flutter/material.dart';

/// Açık temada kart / sheet yüzeyleri: zeminle aynı tona düşmesin.
class AppSurfaces {
  static Color cardFill(ColorScheme cs) {
    if (cs.brightness == Brightness.dark) {
      return Color.lerp(const Color(0xFF262A32), cs.primaryContainer, 0.08)!;
    }
    // Canvas (#B7CFE0) ile beyazın ortası: buz mavisi, okunaklı ama #FFFFFF değil.
    return Color.lerp(const Color(0xFFD4E5F1), cs.primaryContainer, 0.42)!;
  }

  static BorderSide cardBorder(ColorScheme cs) {
    final isDark = cs.brightness == Brightness.dark;
    return BorderSide(
      color: cs.primary.withOpacity(isDark ? 0.12 : 0.22),
      width: 1.15,
    );
  }

  static List<BoxShadow> cardShadow(ColorScheme cs) {
    if (cs.brightness == Brightness.dark) return const [];
    return [
      BoxShadow(
        color: cs.primary.withOpacity(0.12),
        blurRadius: 18,
        spreadRadius: -8,
        offset: const Offset(0, 8),
      ),
    ];
  }

  static BoxDecoration sheetDecoration(ColorScheme cs) {
    final isDark = cs.brightness == Brightness.dark;
    return BoxDecoration(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                Color.lerp(const Color(0xFF2E333C), cs.primary, 0.08)!,
                const Color(0xFF262A32),
                const Color(0xFF22262C),
              ]
            : [
                cs.primaryContainer.withOpacity(0.70),
                Color.lerp(
                  const Color(0xFFD8E8F3),
                  cs.secondaryContainer,
                  0.42,
                )!,
                Color.lerp(
                  const Color(0xFFE0EEF6),
                  cs.primaryContainer,
                  0.32,
                )!,
              ],
        stops: isDark ? const [0, 0.42, 1] : const [0, 0.26, 1],
      ),
      border: Border.all(color: cs.primary.withOpacity(isDark ? 0.14 : 0.16)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.35 : 0.14),
          blurRadius: 28,
          spreadRadius: -8,
          offset: const Offset(0, -8),
        ),
      ],
    );
  }
}
