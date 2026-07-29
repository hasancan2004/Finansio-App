import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget body;
  final Widget? bottomNavigationBar;
  final EdgeInsetsGeometry bodyPadding;
  final double surfaceRadius;
  final double headerHeight;
  final double surfaceTopSpacing;

  // ✅ FAB desteği
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  const AppScaffold({
    super.key,
    required this.title,
    this.actions,
    this.bottomNavigationBar,
    required this.body,
    this.bodyPadding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
    this.surfaceRadius = 26,
    this.headerHeight = 240,
    this.surfaceTopSpacing = 130,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  /// ✅ ÖNEMLİ:
  /// Projede bir yerde AppScaffold().appBar diye erişen kod var.
  /// Bu getter o NoSuchMethodError'u bitirir.
  PreferredSizeWidget get appBar => AppBar(
    titleSpacing: 16,
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    iconTheme: const IconThemeData(color: Colors.white),
    title: Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
    ),
    actions: actions,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isDark = theme.brightness == Brightness.dark;

    // ✅ İç yüzey rengi (çok beyaz olmasın diye hafif tint)
    final surfaceBase = cs.surface;
    final surfaceTint = isDark
        ? cs.surface
        : Color.alphaBlend(
      cs.primary.withOpacity(0.06),
      surfaceBase,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      appBar: appBar,
      body: Stack(
        children: [
          // 1) Gradient arka plan
          Positioned.fill(
            child: Container(
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
            ),
          ),

          // 2) Üstte hafif vignette (okunurluk için)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: headerHeight,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(isDark ? 0.22 : 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 3) İçerik yüzeyi
          Positioned.fill(
            top: surfaceTopSpacing,
            child: Container(
              decoration: BoxDecoration(
                color: surfaceTint,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(surfaceRadius),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.14),
                    blurRadius: 26,
                    spreadRadius: -12,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Container(
                  // ✅ içerikte de çok hafif gradient tint
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(surfaceRadius),
                    ),
                    gradient: isDark
                        ? null
                        : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        cs.primaryContainer.withOpacity(0.10),
                        surfaceTint,
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: bodyPadding,
                    child: body,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
