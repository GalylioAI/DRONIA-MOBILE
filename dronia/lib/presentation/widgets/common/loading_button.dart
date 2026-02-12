import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Loading button with spinner state
class LoadingButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  final String text;
  final Color? backgroundColor;
  final Color? textColor;
  final double height;
  final double? width;
  final IconData? icon;
  final bool outlined;

  const LoadingButton({
    super.key,
    required this.onPressed,
    required this.isLoading,
    required this.text,
    this.backgroundColor,
    this.textColor,
    this.height = 56,
    this.width,
    this.icon,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return SizedBox(
        height: height,
        width: width,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          child: _buildChild(),
        ),
      );
    }

    return SizedBox(
      height: height,
      width: width,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.primaryGreen,
          foregroundColor: textColor ?? AppColors.white,
          disabledBackgroundColor: (backgroundColor ?? AppColors.primaryGreen)
              .withValues(alpha: 0.6),
        ),
        child: _buildChild(),
      ),
    );
  }

  Widget _buildChild() {
    if (isLoading) {
      return SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(
            textColor ?? AppColors.white,
          ),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(icon, size: 20), const SizedBox(width: 8), Text(text)],
      );
    }

    return Text(text);
  }
}

/// Secondary/outlined loading button
class SecondaryButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final IconData? icon;
  final double height;
  final bool isLoading;

  const SecondaryButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.height = 56,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return LoadingButton(
      onPressed: onPressed,
      isLoading: isLoading,
      text: text,
      icon: icon,
      height: height,
      outlined: true,
    );
  }
}
