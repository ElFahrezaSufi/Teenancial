import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Hapus',
  String cancelLabel = 'Batal',
  Color confirmColor = Colors.red,
}) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: scaffoldBg,
      title: Text(
        title,
        style: const TextStyle(
          color: primaryGreen,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(color: primaryGreen, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel, style: const TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: confirmColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
  return confirmed == true;
}
