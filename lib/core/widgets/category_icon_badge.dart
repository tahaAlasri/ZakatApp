import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CategoryIconBadge extends StatelessWidget {
  final String imagePath;
  final double? size;
  final double? iconSize;
  final double padding;
  final double borderRadius;
  final IconData fallbackIcon;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool useContainer;

  const CategoryIconBadge({
    super.key,
    required this.imagePath,
    this.size = 56,
    this.iconSize,
    this.padding = 8,
    this.borderRadius = 14,
    this.fallbackIcon = Icons.calculate_outlined,
    this.backgroundColor,
    this.borderColor,
    this.useContainer = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final darkPath = imagePath.replaceFirst('assets/images/', 'assets/images/dark/');
    final currentPath = isDark ? darkPath : imagePath;
    final effectiveIconSize = iconSize ?? (size != null ? size! * 0.58 : 32.0);

    Widget imageWidget = Image.asset(
      currentPath,
      width: effectiveIconSize,
      height: effectiveIconSize,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          imagePath,
          width: effectiveIconSize,
          height: effectiveIconSize,
          fit: BoxFit.contain,
          color: isDark ? AppColors.goldLight : null,
          errorBuilder: (context, error, stackTrace) => Icon(
            fallbackIcon,
            size: effectiveIconSize,
            color: isDark ? AppColors.goldLight : AppColors.emeraldPrimary,
          ),
        );
      },
    );

    if (!useContainer) {
      return SizedBox(
        width: size ?? effectiveIconSize,
        height: size ?? effectiveIconSize,
        child: Center(child: imageWidget),
      );
    }

    final bg = backgroundColor ??
        (isDark
            ? AppColors.emeraldPrimary.withValues(alpha: 0.22)
            : AppColors.emeraldSubtle);
    final border = borderColor ??
        (isDark
            ? AppColors.emeraldPrimary.withValues(alpha: 0.40)
            : AppColors.emeraldPrimary.withValues(alpha: 0.14));

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : AppColors.emeraldPrimary.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(child: imageWidget),
    );
  }
}
