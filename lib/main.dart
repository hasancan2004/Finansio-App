import 'package:finansio/providers/theme_provider.dart';
import 'package:finansio/screens/budgets_screen.dart';
import 'package:finansio/screens/onboarding_screen.dart';
import 'package:finansio/screens/bottom_nav.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:finansio/data/app_database.dart';
import 'package:finansio/providers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finansio/services/notification_service.dart';
import 'package:drift/drift.dart' show Value;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();

  debugPrint('[Main] NotificationService.init()');
  await NotificationService.init();

  debugPrint('[Main] ensureDailyScheduled()');
  try {
    await NotificationService.ensureDailyScheduled();
    debugPrint('[Main] ensureDailyScheduled() done');
  } catch (e, st) {
    debugPrint('[Main] ensureDailyScheduled ERROR: $e');
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
      final txCount =
      await (db.select(db.transactions)).get().then((l) => l.length);

      if (catCount == 0 && txCount == 0) {
        await _seedDemoData(db);
      }

      await prefs.setBool(_kDemoSeeded, true);
    }

    if (!mounted) return;
    setState(() {
      _seen = seen;
    });
  }

  Future<void> _seedDemoData(AppDatabase db) async {
    final now = DateTime.now();
    final y = now.year;
    final m = now.month;

    DateTime d(int day, {int hour = 12, int min = 0}) =>
        DateTime(y, m, day, hour, min);

    await db.transaction(() async {
      final catSalaryId = await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          name: 'Maaş',
          colorHex: const Value('#2E7D32'),
        ),
      );

      final catMarketId = await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          name: 'Market',
          colorHex: const Value('#FF7043'),
        ),
      );

      final catRentId = await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          name: 'Kira',
          colorHex: const Value('#D32F2F'),
        ),
      );

      final catTransportId = await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          name: 'Ulaşım',
          colorHex: const Value('#1976D2'),
        ),
      );

      final catFunId = await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          name: 'Eğlence',
          colorHex: const Value('#7B1FA2'),
        ),
      );

      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          amount: 25000,
          categoryId: catSalaryId,
          note: const Value('Aylık maaş'),
          date: Value(d(1, hour: 10)),
        ),
      );

      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          amount: -8500,
          categoryId: catRentId,
          note: const Value('Ev kirası'),
          date: Value(d(1, hour: 11)),
        ),
      );

      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          amount: -420,
          categoryId: catMarketId,
          note: const Value('Haftalık alışveriş'),
          date: Value(d(3, hour: 18)),
        ),
      );

      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          amount: -165,
          categoryId: catTransportId,
          note: const Value('Otobüs / metro'),
          date: Value(d(4, hour: 9)),
        ),
      );

      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          amount: -260,
          categoryId: catMarketId,
          note: const Value('Kahvaltılık'),
          date: Value(d(7, hour: 20)),
        ),
      );

      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          amount: -340,
          categoryId: catFunId,
          note: const Value('Sinema'),
          date: Value(d(10, hour: 21)),
        ),
      );

      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          amount: -95,
          categoryId: catTransportId,
          note: const Value('Taksi'),
          date: Value(d(12, hour: 23)),
        ),
      );

      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          amount: -510,
          categoryId: catMarketId,
          note: const Value('Market'),
          date: Value(d(15, hour: 19)),
        ),
      );

      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          amount: -180,
          categoryId: catFunId,
          note: const Value('Kafe'),
          date: Value(d(17, hour: 17)),
        ),
      );
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