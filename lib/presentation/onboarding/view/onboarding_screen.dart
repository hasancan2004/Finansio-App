import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _finish(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    if (context.mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Widget _buildIconCard(BuildContext context, IconData icon) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 170,
      height: 170,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withOpacity(0.95),
            cs.secondary.withOpacity(0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 26,
            spreadRadius: -10,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Icon(icon, size: 78, color: Colors.white),
      ),
    );
  }

  PageDecoration _decoration(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return PageDecoration(
      pageColor: cs.surface,
      titleTextStyle: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w900,
      ) ??
          const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
      bodyTextStyle: theme.textTheme.bodyMedium?.copyWith(
        color: cs.onSurface.withOpacity(0.75),
        fontWeight: FontWeight.w700,
        height: 1.4,
      ) ??
          TextStyle(
            fontSize: 15,
            height: 1.4,
            fontWeight: FontWeight.w700,
            color: cs.onSurface.withOpacity(0.75),
          ),
      imagePadding: const EdgeInsets.only(top: 18, bottom: 8),
      bodyPadding: const EdgeInsets.symmetric(horizontal: 20),
      titlePadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      contentMargin: const EdgeInsets.symmetric(horizontal: 0),
      footerPadding: const EdgeInsets.only(top: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        // ✅ AppScaffold ile aynı vibe (soft gradient)
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2F5BFF),
              Color(0xFF6A5CFF),
              Color(0xFF21C8FF),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 30,
                    spreadRadius: -12,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: IntroductionScreen(
                pages: [
                  PageViewModel(
                    title: "Gelirlerini Yönet",
                    body: "Gelir ve giderlerini tek ekranda takip et.\nHızlı filtrelerle ay ay analiz yap.",
                    image: _buildIconCard(
                      context,
                      Icons.account_balance_wallet_outlined,
                    ),
                    decoration: _decoration(context),
                  ),
                  PageViewModel(
                    title: "Bütçe ile Kontrol",
                    body: "Aylık bütçe hedefleri belirle.\nLimit aşımı ve yaklaşma uyarılarıyla kontrol sende olsun.",
                    image: _buildIconCard(
                      context,
                      Icons.flag_outlined,
                    ),
                    decoration: _decoration(context),
                  ),
                  PageViewModel(
                    title: "Raporlarla Analiz Et",
                    body: "Kategori dağılımı ve trend raporlarıyla\npara akışını net gör.",
                    image: _buildIconCard(
                      context,
                      Icons.pie_chart_outline,
                    ),
                    decoration: _decoration(context),
                  ),
                ],

                // ✅ Controls
                showSkipButton: true,
                skip: Text(
                  "Geç",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface.withOpacity(0.70),
                  ),
                ),
                showNextButton: true,
                next: Text(
                  "İleri",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: cs.primary,
                  ),
                ),
                done: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    "Başla",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                onDone: () => _finish(context),
                onSkip: () => _finish(context),

                // ✅ Dots indicator
                dotsDecorator: DotsDecorator(
                  size: const Size(8, 8),
                  activeSize: const Size(18, 8),
                  activeShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: cs.onSurface.withOpacity(0.18),
                  activeColor: cs.primary,
                ),

                // ✅ Layout polish
                controlsMargin: const EdgeInsets.only(left: 16, right: 16, bottom: 18),
                controlsPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                globalBackgroundColor: Colors.transparent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
