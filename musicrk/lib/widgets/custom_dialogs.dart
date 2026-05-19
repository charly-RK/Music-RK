import 'package:flutter/material.dart';
import 'dart:ui';

class AppDialogs {
  static Future<T?> showCustomDialog<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    List<Widget>? actions,
    List<Widget> Function(BuildContext)? actionsBuilder,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1F3D).withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side: const BorderSide(color: Colors.white10, width: 1),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          content: SingleChildScrollView(
            child: content,
          ),
          actions: actionsBuilder != null 
              ? actionsBuilder(dialogContext) 
              : (actions ?? [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text("Cerrar", style: TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold)),
                  ),
                ]),
          actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
          buttonPadding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }

  static Future<void> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    required VoidCallback onConfirm,
    Color confirmColor = const Color(0xFFE91E63),
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1F3D).withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side: const BorderSide(color: Colors.white10, width: 1),
          ),
          title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          content: Text(message, style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Cancelar", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onConfirm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
          actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
        ),
      ),
    );
  }

  static Future<void> showTextInputDialog({
    required BuildContext context,
    required String title,
    required String hintText,
    String? initialValue,
    required Function(String) onConfirm,
  }) {
    final controller = TextEditingController(text: initialValue);
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1F3D).withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side: const BorderSide(color: Colors.white10, width: 1),
          ),
          title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  Navigator.of(dialogContext).pop();
                  onConfirm(controller.text);
                }
              },
              child: const Text("Aceptar", style: TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold)),
            ),
          ],
          actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
        ),
      ),
    );
  }

  static void showToast(BuildContext context, String message, {bool isError = false}) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.removeCurrentSnackBar();
    
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F3D),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                color: isError ? Colors.redAccent : const Color(0xFFE91E63),
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.1,
          left: 40,
          right: 40,
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
