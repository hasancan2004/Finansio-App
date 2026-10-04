// lib/presentation/shared/theme/app_surfaces.dart
import 'package:flutter/material.dart';

class AppSurfaces {

  // ==========================================
  // ✅ ESKİ METOTLAR (Diğer sayfaların hata vermemesi için geri getirildi)
  // ==========================================
  static Color cardFill(ColorScheme cs) {
    if (cs.brightness == Brightness.dark) {
      return Color.lerp(const Color(0xFF262A32), cs.primaryContainer, 0.08)!;
    }
    // Açık temada çok daha belirgin, şık bir mavi-buz rengi
    return Color.lerp(Colors.white, cs.primary, 0.08)!;
  }

  static BorderSide cardBorder(ColorScheme cs) {
    final isDark = cs.brightness == Brightness.dark;
    return BorderSide(
      color: cs.primary.withOpacity(isDark ? 0.12 : 0.08),
      width: 1.15,
    );
  }

  static List<BoxShadow> cardShadow(ColorScheme cs) {
    if (cs.brightness == Brightness.dark) return const [];
    return [
      BoxShadow(
        color: cs.primary.withOpacity(0.06),
        blurRadius: 16,
        spreadRadius: -4,
        offset: const Offset(0, 6),
      ),
    ];
  }

  // ==========================================
  // ✅ YENİ PREMIUM METOTLAR (Ana Ekran ve Ayarlar için)
  // ==========================================

  // Ayarlar ekranındaki mükemmel Premium kart tasarımı
  static BoxDecoration cardDecoration(ColorScheme cs) {
    final isDark = cs.brightness == Brightness.dark;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
          Color.lerp(const Color(0xFF2A2E36), cs.primaryContainer, 0.08)!,
          const Color(0xFF1E2228),
        ]
            : [
          Color.lerp(Colors.white, cs.primary, 0.12)!,
          Color.lerp(Colors.white, cs.primary, 0.22)!,
        ],
      ),
      border: Border.all(
        color: cs.primary.withOpacity(isDark ? 0.16 : 0.15),
      ),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withOpacity(0.35)
              : cs.primary.withOpacity(0.06),
          blurRadius: 20,
          spreadRadius: -6,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  // Bottom Sheet (Aşağıdan açılan menü) için tatlı gradient
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
          Color.lerp(Colors.white, cs.primaryContainer, 0.25)!,
          Color.lerp(Colors.white, cs.primary, 0.15)!,
          Color.lerp(Colors.white, cs.primaryContainer, 0.45)!,
        ],
        stops: isDark ? const [0, 0.42, 1] : const [0, 0.40, 1],
      ),
      border: Border.all(color: cs.primary.withOpacity(isDark ? 0.14 : 0.15)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.35 : 0.15),
          blurRadius: 28,
          spreadRadius: -8,
          offset: const Offset(0, -8),
        ),
      ],
    );
  }
}