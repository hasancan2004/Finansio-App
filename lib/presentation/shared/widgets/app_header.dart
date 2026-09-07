import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// true: surface üstünde → cs.onSurface
  /// false: koyu gradient üstünde → beyaz
  final bool onSurface;

  /// NEW
  final double minHeight;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onSurface = true,
    this.minHeight = 86, // ✅ biraz daha yüksek
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final titleColor = onSurface ? cs.onSurface : Colors.white;
    final subColor = onSurface
        ? cs.onSurface.withOpacity(0.70)
        : Colors.white.withOpacity(0.82);

    final headerBorder = onSurface
        ? Border.all(color: cs.primary.withOpacity(0.16))
        : Border.all(color: Colors.white.withOpacity(0.12));

    return SizedBox(
      width: double.infinity, // ✅ kesin full width
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // ✅ daha dolu
          decoration: BoxDecoration(
            color: onSurface ? null : Colors.white.withOpacity(0.14),
            gradient: onSurface
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: theme.brightness == Brightness.dark
                        ? [
                            Color.lerp(const Color(0xFF2A2E36), cs.primary, 0.10)!,
                            const Color(0xFF22262C),
                            const Color(0xFF1C1F24),
                          ]
                        : [
                            cs.primaryContainer.withOpacity(0.72),
                            cs.secondaryContainer.withOpacity(0.48),
                            cs.tertiaryContainer.withOpacity(0.40),
                          ],
                  )
                : null,
            borderRadius: BorderRadius.circular(18),
            border: headerBorder,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: titleColor,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: subColor,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
