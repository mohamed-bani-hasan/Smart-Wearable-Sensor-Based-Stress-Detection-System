import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Stress level & status colors (aligned with clinical dashboards).
class AppSemanticColors {
  static const stressNormal = Color(0xFF059669);
  static const stressMedium = Color(0xFFD97706);
  static const stressHigh = Color(0xFFDC2626);
  static const deviceOnline = Color(0xFF0284C7);
  static const success = Color(0xFF10B981);
  static const info = Color(0xFF2563EB);
}

/// Reusable screen chrome (gradients, shadows).
class AppChrome {
  AppChrome._();

  static BoxDecoration subtleScreenBackground(BuildContext context) {
    final theme = Theme.of(context);
    final topAlpha = theme.brightness == Brightness.dark ? 0.2 : 0.14;
    final midAlpha = theme.brightness == Brightness.dark ? 0.1 : 0.06;
    final topTint = Color.alphaBlend(
      theme.colorScheme.primary.withValues(alpha: topAlpha),
      theme.scaffoldBackgroundColor,
    );
    final midTint = Color.alphaBlend(
      theme.colorScheme.primary.withValues(alpha: midAlpha),
      theme.scaffoldBackgroundColor,
    );
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          topTint,
          midTint,
          theme.scaffoldBackgroundColor,
        ],
        stops: const [0.0, 0.45, 1.0],
      ),
    );
  }

  static List<BoxShadow> cardShadow(BuildContext context, {double opacity = 0.06}) {
    final theme = Theme.of(context);
    final baseColor = theme.brightness == Brightness.dark
        ? Colors.black
        : theme.colorScheme.primary;
    return [
      BoxShadow(
        color: baseColor.withValues(alpha: opacity),
        blurRadius: 24,
        offset: const Offset(0, 10),
        spreadRadius: -8,
      ),
    ];
  }

  static BoxDecoration premiumCard(BuildContext context, {Color? borderColor}) {
    final theme = Theme.of(context);
    return BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: borderColor ?? theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
      ),
      boxShadow: cardShadow(context),
    );
  }
}

/// Unified Design System for Stress Detection App
class AppSpacing {
  // Base spacing increments (8px system)
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class AppRadius {
  // Border radius values for consistency
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

class AppPadding {
  static final cardPadding = const EdgeInsets.all(AppSpacing.lg);
}

class AppTextStyles {
  static TextStyle headingLarge(Color color) =>
      TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color);
  
  static TextStyle headingMedium(Color color) =>
      TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color);
  
  static TextStyle headingSmall(Color color) =>
      TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color);
  
  static TextStyle bodyLarge(Color color) =>
      TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: color);
  
  static TextStyle bodyMedium(Color color) =>
      TextStyle(fontSize: 13, fontWeight: FontWeight.normal, color: color);
  
  static TextStyle bodySmall(Color color) =>
      TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color);
  
  static TextStyle caption(Color color) =>
      TextStyle(fontSize: 10, fontWeight: FontWeight.normal, color: color);
}

class AppCardStyles {
  static BoxDecoration standardCard(BuildContext context) {
    final theme = Theme.of(context);
    return BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        )
      ],
    );
  }

  static BoxDecoration statusCard(BuildContext context, Color borderColor) {
    final theme = Theme.of(context);
    return BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border(
        left: BorderSide(color: borderColor, width: 4),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 10,
        )
      ],
    );
  }

  static BoxDecoration alertCard(BuildContext context) {
    final theme = Theme.of(context);
    return BoxDecoration(
      color: theme.colorScheme.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(
        color: theme.colorScheme.primary.withValues(alpha: 0.2),
      ),
    );
  }

  static String avatarInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) {
      return parts.first.length >= 2
          ? parts.first.substring(0, 2).toUpperCase()
          : parts.first[0].toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  static Color avatarBackgroundColor(String name) {
    final baseColors = [
      Color(0xFF0D9488),
      Color(0xFF0891B2),
      Color(0xFF0284C7),
      Color(0xFF6366F1),
      Color(0xFF7C3AED),
      Color(0xFFDB2777),
      Color(0xFFEA580C),
      Color(0xFFCA8A04),
    ];
    final trimmed = name.trim().toLowerCase();
    if (trimmed.isEmpty) return baseColors.first;
    int hash = trimmed.codeUnits.fold(0, (acc, c) => acc + c);
    return baseColors[hash % baseColors.length];
  }
}

class AppDesign {
  static String avatarInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) {
      return parts.first.length >= 2
          ? parts.first.substring(0, 2).toUpperCase()
          : parts.first[0].toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  static Color avatarBackgroundColor(String name) {
    final baseColors = [
      Color(0xFF0D9488),
      Color(0xFF0891B2),
      Color(0xFF0284C7),
      Color(0xFF6366F1),
      Color(0xFF7C3AED),
      Color(0xFFDB2777),
      Color(0xFFEA580C),
      Color(0xFFCA8A04),
    ];
    final trimmed = name.trim().toLowerCase();
    if (trimmed.isEmpty) return baseColors.first;
    int hash = trimmed.codeUnits.fold(0, (acc, c) => acc + c);
    return baseColors[hash % baseColors.length];
  }
}

class AppGaps {
  // Standard gap values between elements
  static const SizedBox tinyVertical = SizedBox(height: AppSpacing.xs);
  static const SizedBox smallVertical = SizedBox(height: AppSpacing.sm);
  static const SizedBox mediumVertical = SizedBox(height: AppSpacing.md);
  static const SizedBox largeVertical = SizedBox(height: AppSpacing.lg);
  static const SizedBox xlargeVertical = SizedBox(height: AppSpacing.xl);

  static const SizedBox tinyHorizontal = SizedBox(width: AppSpacing.xs);
  static const SizedBox smallHorizontal = SizedBox(width: AppSpacing.sm);
  static const SizedBox mediumHorizontal = SizedBox(width: AppSpacing.md);
  static const SizedBox largeHorizontal = SizedBox(width: AppSpacing.lg);
  static const SizedBox xlargeHorizontal = SizedBox(width: AppSpacing.xl);
}

/// Reusable Card Widget
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? borderRadius;
  final Color? borderColor;
  final BoxShadow? shadow;
  final VoidCallback? onTap;
  final bool isAlert;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.borderColor,
    this.shadow,
    this.onTap,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectivePadding = padding ?? AppPadding.cardPadding;
    final effectiveRadius = borderRadius ?? AppRadius.lg;

    BoxDecoration decoration;
    if (isAlert) {
      decoration = AppCardStyles.alertCard(context);
    } else if (borderColor != null) {
      decoration = BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: Border(left: BorderSide(color: borderColor!, width: 4)),
        boxShadow: shadow != null ? [shadow!] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      );
    } else {
      decoration = BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(effectiveRadius),
        boxShadow: shadow != null ? [shadow!] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: decoration,
        padding: effectivePadding,
        child: child,
      ),
    );
  }
}

/// Badge widget for status indicators
class AppBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final double size;

  const AppBadge({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    this.size = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          AppGaps.tinyHorizontal,
          Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// Gradient header card — same visual language as [PatientHomeScreen] top block.
/// Use on every main tab for a consistent “hero” title area.
class AppScreenHeader extends StatelessWidget {
  const AppScreenHeader({
    super.key,
    this.leadingCaption,
    required this.title,
    required this.subtitle,
    this.showDateChip = false,
    this.trailing,
  });

  /// Smaller line above [title] (e.g. "Welcome back," on doctor dashboard).
  final String? leadingCaption;

  /// Primary headline (e.g. "Hello, Sam" or screen title).
  final String title;

  /// Secondary line under [title].
  final String subtitle;

  /// When true and [trailing] is null, shows date + time chip on the right.
  final bool showDateChip;

  /// Replaces the date chip (e.g. action buttons). Keep compact.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary.withValues(alpha: 0.18),
            scheme.secondary.withValues(alpha: 0.08),
            theme.cardColor.withValues(alpha: 0.96),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leadingCaption != null && leadingCaption!.trim().isNotEmpty) ...[
                  Text(
                    leadingCaption!,
                    style: TextStyle(
                      color: theme.textTheme.bodySmall?.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    letterSpacing: -0.35,
                    height: 1.15,
                  ),
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: theme.textTheme.bodySmall?.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: trailing,
            )
          else if (showDateChip)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.45),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('EEE, MMM d').format(now),
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    DateFormat('h:mm a').format(now),
                    style: TextStyle(
                      color: theme.textTheme.bodySmall?.color,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
