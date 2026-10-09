// lib/presentation/shared/widgets/bottom_nav.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_surfaces.dart';
import '../../transactions/view/home_screen.dart';
import '../../transactions/view/add_tx_screen.dart';
import '../../reports/view/reports_screen.dart';
import '../../portfolio/view/portfolio_screen.dart';
import '../../budgets/view/budgets_screen.dart';
import '../../settings/view/settings_screen.dart';
import '../../portfolio/view/add_asset_screen.dart';

// ✅ Global Key tanımlıyoruz ki diğer sayfalardan burayı tek hamlede kontrol edebilelim
final GlobalKey<BottomNavShellState> bottomNavKey = GlobalKey<BottomNavShellState>();

class BottomNavShell extends ConsumerStatefulWidget {
  // Sadece key'i alıp super'a veriyoruz, {super.key} kullanmıyoruz
  BottomNavShell({Key? key}) : super(key: key ?? bottomNavKey);

  @override
  ConsumerState<BottomNavShell> createState() => BottomNavShellState();
}

class BottomNavShellState extends ConsumerState<BottomNavShell> {
  int _currentIndex = 0;
  bool _isExpanded = false;
  bool _isPinned = false;

  late final List<Widget> _pages = [
    const HomeScreen(),      // 0
    const ReportsScreen(),   // 1
    const PortfolioScreen(), // 2
    const BudgetsScreen(),   // 3
    const SettingsScreen(),  // 4
  ];

  @override
  void initState() {
    super.initState();
    _loadPinState();
  }

  static const _kNavPinned = 'nav_pinned';

  Future<void> _loadPinState() async {
    final prefs = await SharedPreferences.getInstance();
    final pinned = prefs.getBool(_kNavPinned) ?? false;
    if (!mounted) return;
    setState(() {
      _isPinned = pinned;
      _isExpanded = pinned;
    });
  }

  /// Pin'i aç/kapat. Pinliyken sekme hep açık kalır (kalıcı kaydedilir).
  Future<void> _togglePin() async {
    final next = !_isPinned;
    setState(() {
      _isPinned = next;
      _isExpanded = next;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNavPinned, next);
  }

  // ✅ TEK TIKLA ANA EKRANA GÖTÜREN VE MENÜ DURUMUNA DOKUNMAYAN FONKSİYON
  void returnToHome() {
    setState(() {
      _currentIndex = 0;
      // _isExpanded ve _isPinned'e dokunmuyoruz, mevcut durumları korunuyor
    });
  }

  void _onNavTap(int index) {
    if (_currentIndex == index && index != 0) {
      // Zaten o sayfadaysan tekrar basınca Ana Ekrana (0) döner ve menü açık kalır
      setState(() {
        _currentIndex = 0;
        _isExpanded = true;
      });
    } else {
      // Farklı bir sayfaya geçer
      setState(() {
        _currentIndex = index;
        _isExpanded = true; // Sayfa değişse bile menü açık kalmaya devam eder!
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    bool showAddButton = (_currentIndex == 0 || _currentIndex == 2);

    void handleAddPressed() {
      if (_currentIndex == 0) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTxScreen()));
      } else if (_currentIndex == 2) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAssetScreen()));
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          // Sayfalar, boş alana tıklamayı yakalayan bir GestureDetector ile
          // sarıldı. Butonlar kendi tıklamalarını kazandığı için sadece
          // gerçekten boş bir alana basılınca menü kapanır; pinliyken hiç kapanmaz.
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: (_isExpanded && !_isPinned)
                ? () => setState(() => _isExpanded = false)
                : null,
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),

          if (_isPinned || _isExpanded)
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 72,
                    decoration: AppSurfaces.cardDecoration(cs).copyWith(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavItem(Icons.pie_chart_outline, 1, cs),
                        _buildNavItem(Icons.account_balance_wallet_outlined, 2, cs),
                        _buildNavItem(Icons.track_changes, 3, cs),
                        _buildNavItem(Icons.settings_outlined, 4, cs),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: -14,
                    child: _buildPinButton(cs),
                  ),
                ],
              ),
            ),

          Positioned(
            right: 16,
            bottom: (_isPinned || _isExpanded) ? 112 : 32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showAddButton) ...[
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: FloatingActionButton(
                      heroTag: 'dynamicAddFab',
                      onPressed: handleAddPressed,
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      elevation: 6,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.add, size: 34),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (!_isExpanded && !_isPinned)
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: FloatingActionButton(
                      heroTag: 'menuFab',
                      onPressed: () => setState(() => _isExpanded = true),
                      backgroundColor: cs.primaryContainer,
                      foregroundColor: cs.primary,
                      elevation: 6,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.grid_view_rounded, size: 30),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, ColorScheme cs) {
    final isSelected = (_currentIndex != 0 && _currentIndex == index);
    return IconButton(
      onPressed: () => _onNavTap(index),
      icon: Icon(
        icon,
        color: isSelected ? cs.primary : cs.onSurface.withOpacity(0.6),
        size: isSelected ? 34 : 28,
      ),
    );
  }

  Widget _buildPinButton(ColorScheme cs) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _togglePin,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _isPinned ? cs.primary : cs.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: _isPinned ? cs.primary : cs.outlineVariant,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            size: 16,
            color: _isPinned ? cs.onPrimary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}