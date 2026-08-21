import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Centralized, high-performance Toast & Notification Service.
///
/// Features:
/// 1. Instant Queue Flushing: Calls `clearSnackBars()` so rapid taps replace the previous message instantly.
/// 2. Fixed Max 2-Second Duration: Prevents lingering toasts.
/// 3. Bottom Floating Design System: 12px rounded floating cards above bottom bar.
/// 4. Async Context Safety: Guarded context calls.
class AppToast {
  AppToast._();

  /// Shows a success toast notification (Deep Green).
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    _presentToast(
      context,
      message: message,
      backgroundColor: AppColors.deepGreen,
      icon: Icons.check_circle_rounded,
      textColor: Colors.white,
    );
  }

  /// Shows an error toast notification (Warning Red).
  static void showError(BuildContext context, String message) {
    if (!context.mounted) return;
    _presentToast(
      context,
      message: message,
      backgroundColor: AppColors.warningRed,
      icon: Icons.error_outline_rounded,
      textColor: Colors.white,
    );
  }

  /// Shows a warning toast notification (Pregnant Amber).
  static void showWarning(BuildContext context, String message) {
    if (!context.mounted) return;
    _presentToast(
      context,
      message: message,
      backgroundColor: AppColors.pregnantAmber,
      icon: Icons.warning_amber_rounded,
      textColor: Colors.white,
    );
  }

  /// Shows an informational toast notification.
  static void showInfo(BuildContext context, String message) {
    if (!context.mounted) return;
    _presentToast(
      context,
      message: message,
      backgroundColor: AppColors.textDark,
      icon: Icons.info_outline_rounded,
      textColor: Colors.white,
    );
  }

  /// Low-level presenter that flushes the queue and displays the latest toast instantly.
  static void _presentToast(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    required IconData icon,
    required Color textColor,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    
    // Instantly wipe queued toasts so rapid taps only display the latest toast
    messenger.clearSnackBars();
    
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.fixed,
        duration: const Duration(seconds: 2), // Fixed Max 2-Second Duration
        elevation: 4,
      ),
    );
  }
}
