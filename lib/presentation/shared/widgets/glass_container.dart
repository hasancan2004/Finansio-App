import 'dart:ui';
import 'package:flutter/material.dart';

/// Glass efekti artık "opsiyonel ve hafif".
/// Home’da summary gibi tek bir yerde kullanılınca premium durur,
/// her yerde olunca yoruyor.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 8.0,
    this.opacity = 0.10,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    final cs = Theme.of(context).colorScheme;

    // Dark/Light uyumlu cam rengi
    final baseColor = cs.surface;

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: baseColor.withOpacity(opacity),
            borderRadius: radius,
            border: Border.all(
              color: cs.outlineVariant.withOpacity(0.35),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
