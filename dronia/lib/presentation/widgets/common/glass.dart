import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Frosted glass card — backdrop-blurred, semi-transparent surface with a
/// soft inner gradient and subtle border. Reads cleanly on top of the
/// brand green gradient background. Adapts to light/dark theme.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double borderRadius;
  final double blur;
  final double opacity;
  final Color? tint;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 24,
    this.blur = 20,
    this.opacity = 0.18,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = tint ?? Colors.white;
    final radius = BorderRadius.circular(borderRadius);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        base.withValues(alpha: opacity * 0.9),
                        base.withValues(alpha: opacity * 0.5),
                      ]
                    : [
                        base.withValues(alpha: 0.55),
                        base.withValues(alpha: 0.35),
                      ],
              ),
              borderRadius: radius,
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.18 : 0.6),
                width: 1,
              ),
            ),
            padding: padding ?? const EdgeInsets.all(18),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Brand-green textured gradient background — replicates the reference
/// design's grainy mesh-gradient feel. Use as the [Scaffold.body] root.
class BrandGradientBackground extends StatelessWidget {
  final Widget child;

  const BrandGradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF0E2818),
                  Color(0xFF1B4D2E),
                  Color(0xFF0E2818),
                ]
              : const [
                  Color(0xFFA8D5B0),
                  Color(0xFF6FA970),
                  Color(0xFF3F7A52),
                ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Top-right green glow accent
          Positioned(
            top: -120,
            right: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryGreen
                        .withValues(alpha: isDark ? 0.30 : 0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Bottom-left subtle accent
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: isDark ? 0.05 : 0.20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
