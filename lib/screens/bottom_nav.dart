import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_screen.dart';
import 'categories_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

import '../providers/providers.dart';
import '../providers/budget_providers.dart';

class BottomNavShell extends ConsumerStatefulWidget {
  const BottomNavShell({super.key});

  @override
  ConsumerState<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends ConsumerState<BottomNavShell> {
  int _currentIndex = 0;

  // ✅ HATA BURADAYDI: `const [...]` yerine normal `[...]` yaptık
  late final List<Widget> _pages = [
    const HomeScreen(),
    const CategoriesScreen(),
    const ReportsScreen(),
    const SettingsScreen(),
  ];

  Widget _badgeDot(Widget icon) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: -1,
          top: -1,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final exceededCategory = ref.watch(anyBudgetExceededProvider);
    final hasGlobalAlert = ref.watch(anyGlobalLimitAlertProvider);
    final showHomeBadge = exceededCategory || hasGlobalAlert;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        height: 68,
        backgroundColor: cs.surface,
        indicatorColor: cs.primary.withOpacity(0.14),
        destinations: [
          NavigationDestination(
            icon: showHomeBadge
                ? _badgeDot(const Icon(Icons.home_outlined))
                : const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: 'Ana',
          ),
          const NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: 'Kategori',
          ),
          const NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Rapor',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ayarlar',
          ),
        ],
      ),
    );
  }
}