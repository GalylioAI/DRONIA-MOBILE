import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';

/// Date and time formatting helpers
class DateTimeHelper {
  DateTimeHelper._();

  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _fullDateFormat = DateFormat('EEEE, d MMMM yyyy');
  static final DateFormat _shortDateFormat = DateFormat('d MMM');

  /// Format date to dd/MM/yyyy
  static String formatDate(DateTime date) => _dateFormat.format(date);

  /// Format time to HH:mm
  static String formatTime(DateTime time) => _timeFormat.format(time);

  /// Format date and time to dd/MM/yyyy HH:mm
  static String formatDateTime(DateTime dateTime) =>
      _dateTimeFormat.format(dateTime);

  /// Format to full date (e.g., "Monday, 15 January 2026")
  static String formatFullDate(DateTime date) => _fullDateFormat.format(date);

  /// Format to short date (e.g., "15 Jan")
  static String formatShortDate(DateTime date) => _shortDateFormat.format(date);

  /// Get relative time string (e.g., "2 hours ago", "Yesterday")
  static String getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return formatDate(dateTime);
    }
  }
}

/// Number formatting helpers
class NumberHelper {
  NumberHelper._();

  static final NumberFormat _numberFormat = NumberFormat('#,##0.##');
  static final NumberFormat _percentFormat = NumberFormat('0.0%');
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: 'TND ',
  );

  /// Format number with thousand separators
  static String formatNumber(num number) => _numberFormat.format(number);

  /// Format as percentage
  static String formatPercent(double value) => _percentFormat.format(value);

  /// Format as currency
  static String formatCurrency(double amount) => _currencyFormat.format(amount);

  /// Format large numbers (e.g., 1.5K, 2.3M)
  static String formatCompact(num number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

/// UI Helper functions
class UIHelper {
  UIHelper._();

  /// Show a snackbar message
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    bool isSuccess = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (isError)
              const Icon(Icons.error_outline, color: AppColors.white)
            else if (isSuccess)
              const Icon(Icons.check_circle_outline, color: AppColors.white)
            else
              const Icon(Icons.info_outline, color: AppColors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError
            ? AppColors.error
            : isSuccess
            ? AppColors.success
            : AppColors.textPrimary,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Show loading dialog
  static void showLoadingDialog(BuildContext context, [String? message]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(message ?? 'Loading...')),
            ],
          ),
        ),
      ),
    );
  }

  /// Hide loading dialog
  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  /// Show confirmation dialog
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDangerous = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: isDangerous
                ? ElevatedButton.styleFrom(backgroundColor: AppColors.error)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Get status color based on value
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'online':
      case 'active':
      case 'healthy':
      case 'excellent':
      case 'success':
        return AppColors.success;
      case 'warning':
      case 'moderate':
      case 'charging':
        return AppColors.warning;
      case 'offline':
      case 'error':
      case 'critical':
      case 'poor':
        return AppColors.error;
      case 'idle':
      case 'info':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }

  /// Get health color
  static Color getHealthColor(double healthPercent) {
    if (healthPercent >= 80) return AppColors.healthExcellent;
    if (healthPercent >= 60) return AppColors.healthGood;
    if (healthPercent >= 40) return AppColors.healthModerate;
    if (healthPercent >= 20) return AppColors.healthPoor;
    return AppColors.healthCritical;
  }

  /// Get battery color
  static Color getBatteryColor(int batteryPercent) {
    if (batteryPercent >= 60) return AppColors.success;
    if (batteryPercent >= 30) return AppColors.warning;
    return AppColors.error;
  }
}
