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

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// ------------------ Tema Tanımları (Sade Modern) ------------------

ThemeData buildLightTheme(Color accent) {
  final seeded = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: Brightness.light,
  );

  // Zemin doygun; kartlar buz mavisi — beyaz değil, zeminden de açık.
  final canvas = _mix(const Color(0xFFB7CFE0), accent, 0.18);
  final sheet = _mix(const Color(0xFFC4D8E8), accent, 0.14);
  final card = _mix(const Color(0xFFD8E8F3), accent, 0.12);
  final cardRaised = _mix(const Color(0xFFE0EEF6), accent, 0.10);
  final well = _mix(const Color(0xFFA9C4D8), accent, 0.16);
  const onSurface = Color(0xFF142033);

  final scheme = seeded.copyWith(
    surface: sheet,
    surfaceDim: well,
    surfaceBright: cardRaised,
    surfaceContainerLowest: cardRaised,
    surfaceContainerLow: card,
    surfaceContainer: sheet,
    surfaceContainerHigh: well,
    surfaceContainerHighest: _mix(well, accent, 0.10),
    onSurface: onSurface,
    onSurfaceVariant: const Color(0xFF4B5C70),
    outline: _mix(const Color(0xFF8EA6BA), accent, 0.18),
    outlineVariant: _mix(const Color(0xFFB9CDDC), accent, 0.14),
    surfaceTint: accent,
  );

  final radius = BorderRadius.circular(16);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: "Poppins",
    canvasColor: canvas,
    scaffoldBackgroundColor: canvas,

    appBarTheme: AppBarTheme(
      backgroundColor: canvas,
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

    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shadowColor: accent.withOpacity(0.18),
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),

    dividerTheme: DividerThemeData(
      thickness: 1,
      space: 20,
      color: scheme.outlineVariant.withOpacity(0.70),
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
      fillColor: cardRaised,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: scheme.primaryContainer.withOpacity(0.55),
      selectedColor: scheme.primary,
      side: BorderSide(color: scheme.primary.withOpacity(0.18)),
      labelStyle: TextStyle(
        color: scheme.primary,
        fontWeight: FontWeight.w800,
        fontFamily: "Poppins",
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cardRaised,
      indicatorColor: scheme.primary.withOpacity(0.18),
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: "Poppins",
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        );
      }),
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
      elevation: 2,
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

    dialogTheme: DialogThemeData(
      backgroundColor: cardRaised,
      surfaceTintColor: accent.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: cardRaised,
      modalBackgroundColor: cardRaised,
      surfaceTintColor: accent.withOpacity(0.10),
      showDragHandle: true,
      dragHandleColor: accent.withOpacity(0.38),
      clipBehavior: Clip.antiAlias,
      elevation: 8,
    ),
  );
}

ThemeData buildDarkTheme(Color accent) {
  final seeded = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: Brightness.dark,
  );

  // Grafit koyu tema: siyah değil, lacivert de değil.
  final canvas = _mix(const Color(0xFF1C1F26), accent, 0.04);
  final sheet = _mix(const Color(0xFF1E2228), accent, 0.04);
  final card = _mix(const Color(0xFF22252C), accent, 0.05);
  final cardRaised = _mix(const Color(0xFF2A2E36), accent, 0.05);
  const onSurface = Color(0xFFE8EAEE);

  final scheme = seeded.copyWith(
    surface: sheet,
    surfaceDim: canvas,
    surfaceBright: cardRaised,
    surfaceContainerLowest: card,
    surfaceContainerLow: card,
    surfaceContainer: sheet,
    surfaceContainerHigh: cardRaised,
    surfaceContainerHighest: _mix(cardRaised, accent, 0.10),
    onSurface: onSurface,
    onSurfaceVariant: const Color(0xFFB0B6C0),
    outline: _mix(const Color(0xFF6B7280), accent, 0.08),
    outlineVariant: _mix(const Color(0xFF3F4550), accent, 0.08),
    surfaceTint: accent,
  );

  final radius = BorderRadius.circular(16);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: "Poppins",
    canvasColor: canvas,
    scaffoldBackgroundColor: canvas,
    appBarTheme: AppBarTheme(
      backgroundColor: canvas,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        color: onSurface,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        fontFamily: "Poppins",
      ),
      iconTheme: const IconThemeData(color: onSurface),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shadowColor: Colors.black.withOpacity(0.28),
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
      fillColor: cardRaised,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: cardRaised,
      selectedColor: scheme.primary,
      side: BorderSide(color: scheme.primary.withOpacity(0.28)),
      labelStyle: TextStyle(
        color: scheme.onSurface,
        fontWeight: FontWeight.w800,
        fontFamily: "Poppins",
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: card,
      indicatorColor: scheme.primary.withOpacity(0.28),
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: "Poppins",
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        );
      }),
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
      elevation: 2,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: cardRaised,
      contentTextStyle: const TextStyle(
        color: onSurface,
        fontFamily: "Poppins",
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cardRaised,
      surfaceTintColor: accent.withOpacity(0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: cardRaised,
      modalBackgroundColor: cardRaised,
      surfaceTintColor: accent.withOpacity(0.12),
      showDragHandle: true,
      dragHandleColor: accent.withOpacity(0.45),
      clipBehavior: Clip.antiAlias,
      elevation: 8,
    ),
  );
}