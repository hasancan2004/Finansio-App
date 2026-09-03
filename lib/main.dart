// lib/main.dart
import 'package:finansio/presentation/reports/view/category_spike_screen.dart';
import 'package:finansio/presentation/reports/view/weekly_summary_screen.dart';
import 'package:finansio/presentation/settings/viewmodel/theme_provider.dart';
import 'package:finansio/presentation/budgets/view/budgets_screen.dart';
import 'package:finansio/presentation/onboarding/view/onboarding_screen.dart';
import 'package:finansio/presentation/shared/widgets/bottom_nav.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:finansio/data/database/app_database.dart';
import 'package:finansio/presentation/transactions/viewmodel/tx_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drift/drift.dart' show Value;

import 'data/services/notification_service.dart';

// ✅ YENİ: Uygulamanın her yerinden sayfa değiştirebilmek için global anahtar
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();

  debugPrint('[Main] NotificationService.init()');
  await NotificationService.init();

  debugPrint('[Main] Bildirim zamanlayıcıları kuruluyor...');
  try {
    await NotificationService.ensureDailyScheduled();
    await NotificationService.ensureWeeklyTrendScheduled(); // ✅ HAFTALIK BİLDİRİM TETİKLEYİCİ
    debugPrint('[Main] Bildirim kurulumları tamamlandı');
  } catch (e, st) {
    debugPrint('[Main] Bildirim ERROR: $e');
    debugPrint('$st');
  }

  runApp(
    ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
      ],
      child: const FinansioApp(),
    ),
  );
}

class FinansioApp extends ConsumerWidget {
  const FinansioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final accentKey = ref.watch(accentColorProvider);
    final seedColor = accentColorFromKey(accentKey);

    return MaterialApp(
      navigatorKey: globalNavigatorKey,
      title: "Finansio",
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(seedColor),
      darkTheme: buildDarkTheme(seedColor),
      themeMode: themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('tr', 'TR'),
      home: const _Bootstrapper(),
      routes: {
        '/home': (_) => const BottomNavShell(),
        '/budgets': (_) => const BudgetsScreen(),
        '/reports': (_) => const BottomNavShell(), // ✅ Tıklanınca uygulamayı açıp navigasyona yönlendirir
        '/weekly_summary': (_) => const WeeklySummaryScreen(),
        '/category_spike': (_) => const CategorySpikeScreen(),
      },
    );
  }
}

/// ✅ Uygulama ilk açılış kontrolü + demo seed burada
class _Bootstrapper extends ConsumerStatefulWidget {
  const _Bootstrapper({super.key});

  @override
  ConsumerState<_Bootstrapper> createState() => _BootstrapperState();
}

class _BootstrapperState extends ConsumerState<_Bootstrapper> {
  bool? _seen;

  static const _kSeenOnboarding = 'seen_onboarding';
  static const _kDemoSeeded = 'demo_seeded_v1';

  @override
  void initState() {
    super.initState();
    _loadAndPrepare();
  }

  Future<void> _loadAndPrepare() async {
    final prefs = await SharedPreferences.getInstance();

    final seen = prefs.getBool(_kSeenOnboarding) ?? false;
    final demoSeeded = prefs.getBool(_kDemoSeeded) ?? false;

    if (!demoSeeded) {
      final db = ref.read(dbProvider);

      final catCount = await (db.select(db.categories)).get().then((l) => l.length);
      final txCount = await (db.select(db.transactions)).get().then((l) => l.length);

      if (catCount == 0 && txCount == 0) {
        await db.seed();
      }

      await prefs.setBool(_kDemoSeeded, true);
    }

    if (!mounted) return;
    setState(() {
      _seen = seen;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_seen == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _seen! ? const BottomNavShell() : const OnboardingScreen();
  }
}