import 'package:flutter/material.dart';

/// Fleetman's status-bar toast, shared by the home screens and secondary
/// screens (for example the Fleet Manager request review page) so feedback
/// looks identical everywhere.
void showTopToast(
  BuildContext context, {
  required String message,
  bool isSuccess = true,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) {
      final topInset = MediaQuery.paddingOf(context).top + 12;
      final backgroundColor = isSuccess
          ? const Color(0xFF0E5A57)
          : const Color(0xFF8B1E3F);

      return Positioned(
        top: topInset,
        left: 12,
        right: 12,
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      isSuccess
                          ? Icons.check_circle_outline_rounded
                          : Icons.error_outline_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  overlay.insert(entry);
  Future<void>.delayed(const Duration(seconds: 3), () {
    entry.remove();
  });
}
