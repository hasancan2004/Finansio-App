import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OnboardingPageData {
  final String title;
  final String body;
  final IconData icon;
  final List<IconData> floating;
  final List<String> chips;
  final List<Color> gradient;

  const _OnboardingPageData({
    required this.title,
    required this.body,
    required this.icon,
    required this.floating,
    required this.chips,
    required this.gradient,
  });
}

const _pages = <_OnboardingPageData>[
  _OnboardingPageData(
    title: "Gelirlerini Yönet",
    body: "Gelir ve giderlerini tek ekranda takip et. Hızlı filtrelerle ay ay analiz yap.",
    icon: Icons.account_balance_wallet_rounded,
    floating: [Icons.trending_up_rounded, Icons.savings_rounded, Icons.payments_rounded],
    chips: ["Gelir & Gider", "Hızlı filtre", "Hesaplar"],
    gradient: [Color(0xFF1D4ED8), Color(0xFF4F46E5), Color(0xFF06B6D4)],
  ),
  _OnboardingPageData(
    title: "Bütçe ile Kontrol",
    body: "Aylık bütçe hedefleri belirle. Limit aşımı ve yaklaşma uyarılarıyla kontrol sende olsun.",
    icon: Icons.flag_rounded,
    floating: [Icons.notifications_active_rounded, Icons.category_rounded, Icons.speed_rounded],
    chips: ["Kategori bütçesi", "Uyarılar", "Kalan limit"],
    gradient: [Color(0xFF7C3AED), Color(0xFF4F46E5), Color(0xFF2563EB)],
  ),
  _OnboardingPageData(
    title: "Raporlarla Analiz Et",
    body: "Kategori dağılımı ve trend raporlarıyla para akışını net gör.",
    icon: Icons.pie_chart_rounded,
    floating: [Icons.bar_chart_rounded, Icons.show_chart_rounded, Icons.insights_rounded],
    chips: ["Kategori dağılımı", "Aylık trend", "Risk durumu"],
    gradient: [Color(0xFF0D9488), Color(0xFF0891B2), Color(0xFF2563EB)],
  ),
  _OnboardingPageData(
    title: "Otomatik İşlem Yakala",
    body: "Banka bildirimlerinden işlem oluştur, abonelik ve sabit giderlerini unutma.",
    icon: Icons.bolt_rounded,
    floating: [Icons.notifications_rounded, Icons.subscriptions_rounded, Icons.credit_card_rounded],
    chips: ["Bildirimden yakala", "Abonelikler", "Hatırlatma"],
    gradient: [Color(0xFFEA580C), Color(0xFFDB2777), Color(0xFF7C3AED)],
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _controller = PageController();
  late final AnimationController _float;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _controller.addListener(() {
      if (!mounted) return;
      setState(() => _page = _controller.page ?? 0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _float.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  void _next() {
    final current = _page.round();
    if (current >= _pages.length - 1) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  List<Color> _blendedGradient() {
    final i = _page.floor().clamp(0, _pages.length - 1);
    final j = (i + 1).clamp(0, _pages.length - 1);
    final t = (_page - i).clamp(0.0, 1.0);
    return List.generate(3, (k) {
      return Color.lerp(_pages[i].gradient[k], _pages[j].gradient[k], t)!;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final colors = _blendedGradient();
    final current = _page.round().clamp(0, _pages.length - 1);
    final isLast = current == _pages.length - 1;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: Stack(
          children: [
            // Dekoratif bulanık daireler
            Positioned(
              top: -size.width * 0.25,
              right: -size.width * 0.2,
              child: _GlowCircle(size: size.width * 0.8, opacity: 0.14),
            ),
            Positioned(
              top: size.height * 0.28,
              left: -size.width * 0.3,
              child: _GlowCircle(size: size.width * 0.6, opacity: 0.10),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Üst bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 10, 12, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "Finansio",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: isLast ? 0 : 1,
                          child: TextButton(
                            onPressed: isLast ? null : _finish,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.white.withOpacity(0.16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                            ),
                            child: const Text("Geç",
                                style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // İllüstrasyon alanı
                  Expanded(
                    flex: 5,
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _pages.length,
                      itemBuilder: (context, index) {
                        final delta = (_page - index);
                        return Transform.translate(
                          offset: Offset(-delta * 80, 0),
                          child: Opacity(
                            opacity: (1 - delta.abs() * 0.8).clamp(0.0, 1.0),
                            child: _Illustration(
                              data: _pages[index],
                              animation: _float,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Alt panel
                  Expanded(
                    flex: 4,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(26, 26, 26, 0),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(34)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.22),
                            blurRadius: 30,
                            spreadRadius: -8,
                            offset: const Offset(0, -8),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 350),
                                transitionBuilder: (child, anim) {
                                  return FadeTransition(
                                    opacity: anim,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.08),
                                        end: Offset.zero,
                                      ).animate(anim),
                                      child: child,
                                    ),
                                  );
                                },
                                child: _TextBlock(
                                  key: ValueKey(current),
                                  data: _pages[current],
                                  accent: colors.first,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Row(
                                  children: List.generate(_pages.length, (i) {
                                    final active = i == current;
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOut,
                                      margin: const EdgeInsets.only(right: 6),
                                      width: active ? 26 : 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: active
                                            ? colors.first
                                            : cs.onSurface.withOpacity(0.18),
                                      ),
                                    );
                                  }),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: _next,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    height: 56,
                                    padding: EdgeInsets.symmetric(
                                        horizontal: isLast ? 28 : 18),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      gradient: LinearGradient(colors: [
                                        colors.first,
                                        colors[1],
                                      ]),
                                      boxShadow: [
                                        BoxShadow(
                                          color: colors.first.withOpacity(0.45),
                                          blurRadius: 18,
                                          spreadRadius: -4,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AnimatedSwitcher(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          child: isLast
                                              ? const Text(
                                                  "Hadi Başlayalım",
                                                  key: ValueKey('start'),
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 16,
                                                  ),
                                                )
                                              : const SizedBox(
                                                  key: ValueKey('next')),
                                        ),
                                        if (isLast) const SizedBox(width: 8),
                                        const Icon(Icons.arrow_forward_rounded,
                                            color: Colors.white),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  final _OnboardingPageData data;
  final Color accent;

  const _TextBlock({super.key, required this.data, required this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data.body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withOpacity(0.72),
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: data.chips.map((c) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: accent),
                    const SizedBox(width: 6),
                    Text(
                      c,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  final _OnboardingPageData data;
  final Animation<double> animation;

  const _Illustration({required this.data, required this.animation});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final side = math.min(box.maxWidth, box.maxHeight);
      final main = side * 0.52;
      final radius = side * 0.40;

      return AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value * 2 * math.pi;
          return Center(
            child: SizedBox(
              width: side,
              height: side,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Halkalar
                  _Ring(size: side * 0.92, opacity: 0.10),
                  _Ring(size: side * 0.72, opacity: 0.16),
                  // Ana kart
                  Transform.translate(
                    offset: Offset(0, math.sin(t) * 6),
                    child: Container(
                      width: main,
                      height: main,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(main * 0.3),
                        color: Colors.white.withOpacity(0.22),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.5), width: 1.4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.22),
                            blurRadius: 30,
                            spreadRadius: -6,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: main * 0.68,
                          height: main * 0.68,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(main * 0.22),
                            color: Colors.white,
                          ),
                          child: Icon(
                            data.icon,
                            size: main * 0.38,
                            color: data.gradient[1],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Yüzen mini ikonlar
                  for (int i = 0; i < data.floating.length; i++)
                    _orbit(
                      icon: data.floating[i],
                      angle: (-math.pi / 2) +
                          i * (2 * math.pi / data.floating.length) +
                          0.5,
                      radius: radius,
                      t: t + i * 1.7,
                      color: data.gradient[(i + 1) % 3],
                      size: side * 0.15,
                    ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Widget _orbit({
    required IconData icon,
    required double angle,
    required double radius,
    required double t,
    required Color color,
    required double size,
  }) {
    final dx = math.cos(angle) * radius;
    final dy = math.sin(angle) * radius + math.sin(t) * 7;
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 14,
              spreadRadius: -3,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, size: size * 0.52, color: color),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  final double size;
  final double opacity;

  const _Ring({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(opacity + 0.1)),
        color: Colors.white.withOpacity(opacity * 0.5),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final double opacity;

  const _GlowCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }
}
