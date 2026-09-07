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
    final canvas = theme.scaffoldBackgroundColor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      appBar: appBar,
      body: Stack(
        children: [
          // 1) Gradient arka plan (Üst kısımdaki mavi panel)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          Color.lerp(const Color(0xFF161A22), cs.primary, 0.14)!,
                          Color.lerp(const Color(0xFF181C24), cs.primary, 0.10)!,
                          const Color(0xFF15181E),
                        ]
                      : [
                          Color.lerp(const Color(0xFF1D4ED8), cs.primary, 0.45)!,
                          Color.lerp(const Color(0xFF4F46E5), cs.primary, 0.35)!,
                          Color.lerp(const Color(0xFF06B6D4), cs.primary, 0.28)!,
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
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          canvas,
                          canvas,
                          Color.lerp(canvas, const Color(0xFF242830), 0.45)!,
                        ]
                      : [
                          Color.lerp(canvas, cs.primary, 0.10)!,
                          canvas,
                          Color.lerp(canvas, const Color(0xFF5BB8A8), 0.16)!,
                        ],
                ),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(surfaceRadius),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.14 : 0.10),
                    blurRadius: 26,
                    spreadRadius: -12,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: bodyPadding,
                  child: body,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}