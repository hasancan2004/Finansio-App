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

    final headerBg = onSurface
        ? cs.primaryContainer.withOpacity(0.20)
        : Colors.white.withOpacity(0.14);

    final headerBorder = onSurface
        ? Border.all(color: cs.primary.withOpacity(0.12))
        : Border.all(color: Colors.white.withOpacity(0.12));

    return SizedBox(
      width: double.infinity, // ✅ kesin full width
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // ✅ daha dolu
          decoration: BoxDecoration(
            color: headerBg,
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
