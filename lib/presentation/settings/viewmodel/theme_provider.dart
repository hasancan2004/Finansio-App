import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ------------------ Keys ------------------
const _kThemeModeKey = 'theme_mode';
const _kAccentKey = 'accent_color';

/// Varsayılan accent (uygulama ilk açıldığında)
const _defaultAccent = AccentColorKey.blue;

/// ------------------ ThemeMode Encode / Decode ------------------

int _encodeThemeMode(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 1;
    case ThemeMode.dark:
      return 2;
    case ThemeMode.system:
    default:
      return 0;
  }
}

ThemeMode _decodeThemeMode(int value) {
  switch (value) {
    case 1:
      return ThemeMode.light;
    case 2:
      return ThemeMode.dark;
    case 0:
    default:
      return ThemeMode.system;
  }
}

/// ------------------ Accent Enum & Yardımcılar ------------------

enum AccentColorKey {
  blue,
  purple,
  green,
  teal,
  orange,
}

AccentColorKey _decodeAccent(int value) {
  if (value < 0 || value >= AccentColorKey.values.length) {
    return _defaultAccent;
  }
  return AccentColorKey.values[value];
}

int _encodeAccent(AccentColorKey key) => key.index;

Color accentColorFromKey(AccentColorKey key) {
  switch (key) {
    case AccentColorKey.blue:
      return const Color(0xFF1565C0);
    case AccentColorKey.purple:
      return const Color(0xFF7E57C2);
    case AccentColorKey.green:
      return const Color(0xFF2E7D32);
    case AccentColorKey.teal:
      return const Color(0xFF00897B);
    case AccentColorKey.orange:
      return const Color(0xFFF57C00);
  }
}

/// ------------------ ThemeController (Mode) ------------------

class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_kThemeModeKey) ?? 0;
    state = _decodeThemeMode(raw);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeModeKey, _encodeThemeMode(mode));
  }

  Future<void> toggleDarkLight() async {
    final next = switch (state) {
      ThemeMode.system => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.light => ThemeMode.system,
    };
    await setThemeMode(next);
  }
}

final themeModeProvider =
StateNotifierProvider<ThemeController, ThemeMode>((ref) {
  return ThemeController();
});

/// ------------------ AccentController ------------------

class AccentController extends StateNotifier<AccentColorKey> {
  AccentController() : super(_defaultAccent) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_kAccentKey);
    if (raw == null) return;
    state = _decodeAccent(raw);
  }

  Future<void> setAccent(AccentColorKey key) async {
    state = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAccentKey, _encodeAccent(key));
  }
}

final accentColorProvider =
StateNotifierProvider<AccentController, AccentColorKey>((ref) {
  return AccentController();
});

/// ------------------ Tema Tanımları (Sade Modern) ------------------

ThemeData buildLightTheme(Color accent) {
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: Brightness.light,
  );

  final radius = BorderRadius.circular(16);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: "Poppins",

    // Daha temiz bir arkaplan
    scaffoldBackgroundColor: const Color(0xFFF7F7FA),

    // AppBar: şov yok, temiz
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFFF7F7FA),
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        fontFamily: "Poppins",
      ),
      iconTheme: IconThemeData(color: scheme.onSurface),
    ),

    // Kartlar: tek tip, temiz
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),

    dividerTheme: DividerThemeData(
      thickness: 1,
      space: 20,
      color: scheme.outlineVariant.withOpacity(0.55),
    ),

    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),

    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 1,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(
        color: scheme.onInverseSurface,
        fontFamily: "Poppins",
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      backgroundColor: scheme.surface,
    ),
  );
}

ThemeData buildDarkTheme(Color accent) {
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: Brightness.dark,
  );

  final radius = BorderRadius.circular(16);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: "Poppins",

    scaffoldBackgroundColor: const Color(0xFF0B0D12),

    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF0B0D12),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        fontFamily: "Poppins",
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),

    cardTheme: CardThemeData(
      color: const Color(0xFF121826),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),

    dividerTheme: DividerThemeData(
      thickness: 1,
      space: 20,
      color: scheme.outlineVariant.withOpacity(0.35),
    ),

    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
      filled: true,
      fillColor: const Color(0xFF121826),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),

    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 1,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(
        color: scheme.onInverseSurface,
        fontFamily: "Poppins",
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      backgroundColor: Color(0xFF0B0D12),
    ),
  );
}
