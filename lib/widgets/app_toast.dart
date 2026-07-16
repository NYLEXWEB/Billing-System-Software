import 'package:flutter/material.dart';

class AppToast {
  static void showSuccess(BuildContext context, String message) {
    _showToast(
      context: context,
      message: message,
      icon: Icons.check_circle_rounded,
      backgroundColor: const Color(0xFF10B981),
      textColor: Colors.white,
    );
  }

  static void showError(BuildContext context, String message) {
    _showToast(
      context: context,
      message: message,
      icon: Icons.error_outline_rounded,
      backgroundColor: const Color(0xFFEF4444),
      textColor: Colors.white,
    );
  }

  static void showInfo(BuildContext context, String message) {
    _showToast(
      context: context,
      message: message,
      icon: Icons.info_outline_rounded,
      backgroundColor: const Color(0xFF3B82F6),
      textColor: Colors.white,
    );
  }

  static void _showToast({
    required BuildContext context,
    required String message,
    required IconData icon,
    required Color backgroundColor,
    required Color textColor,
  }) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: textColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
