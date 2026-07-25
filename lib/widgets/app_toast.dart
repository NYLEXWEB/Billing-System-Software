import 'package:flutter/material.dart';

class AppToast {
  static OverlayEntry? _currentEntry;

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
    _currentEntry?.remove();
    _currentEntry = null;

    final overlayState = Overlay.maybeOf(context);
    if (overlayState == null) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: backgroundColor,
          content: Text(message, style: TextStyle(color: textColor)),
        ),
      );
      return;
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
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
      ),
    );

    _currentEntry = entry;
    overlayState.insert(entry);

    Future.delayed(const Duration(seconds: 3), () {
      if (_currentEntry == entry) {
        entry.remove();
        _currentEntry = null;
      }
    });
  }
}
