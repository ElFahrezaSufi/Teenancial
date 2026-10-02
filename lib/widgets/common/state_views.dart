import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

enum LoadState { loading, success, error }

class LoadingView extends StatelessWidget {
  final String message;
  const LoadingView({super.key, this.message = 'Memuat data...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: primaryGreen),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(
                  color: primaryGreen,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageView({
    required this.icon,
    required this.title,
    required this.hint,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: primaryGreen),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: primaryGreen,
                      fontSize: 16,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(hint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: primaryGreen,
                      fontSize: 13,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500)),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  final String title;
  final String hint;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyView({
    super.key,
    required this.title,
    required this.hint,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => _MessageView(
        icon: Icons.inbox_outlined,
        title: title,
        hint: hint,
        actionLabel: actionLabel,
        onAction: onAction,
      );
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => _MessageView(
        icon: Icons.cloud_off_outlined,
        title: 'Gagal memuat data',
        hint: message,
        actionLabel: 'Coba lagi',
        onAction: onRetry,
      );
}

void showAppSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red.shade700 : primaryGreen,
    ));
}

Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Hapus',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: appBarBg,
      title: Text(title,
          style: const TextStyle(
              color: primaryGreen, fontWeight: FontWeight.w700)),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal', style: TextStyle(color: primaryGreen)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel, style: const TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  return result ?? false;
}
