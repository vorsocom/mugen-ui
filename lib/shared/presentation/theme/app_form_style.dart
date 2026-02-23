import 'package:flutter/material.dart';

import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

class AppFormPanel extends StatelessWidget {
  const AppFormPanel({
    required this.child,
    super.key,
    this.margin = const EdgeInsets.all(10),
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppUiPalette.surface,
        border: Border.all(color: AppUiPalette.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

Future<bool?> showAppConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String cancelLabel = 'Cancel',
  String confirmLabel = 'Continue',
  Key? cancelButtonKey,
  Key? confirmButtonKey,
  IconData icon = Icons.help_outline,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: AppUiPalette.surfaceMuted,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppUiPalette.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AppFormPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppUiPalette.surfaceStrong,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 18,
                        color: AppUiPalette.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppUiPalette.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      key: cancelButtonKey,
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(cancelLabel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: confirmButtonKey,
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(confirmLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

InputDecoration appFormInputDecoration({
  required String labelText,
  Widget? suffixIcon,
  String? hintText,
  int? errorMaxLines,
}) {
  final baseBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppUiPalette.border),
  );

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    errorMaxLines: errorMaxLines,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    enabledBorder: baseBorder,
    focusedBorder: baseBorder.copyWith(
      borderSide: const BorderSide(color: AppUiPalette.textMuted),
    ),
    errorBorder: baseBorder.copyWith(
      borderSide: BorderSide(color: Colors.red.shade400),
    ),
    focusedErrorBorder: baseBorder.copyWith(
      borderSide: BorderSide(color: Colors.red.shade500),
    ),
    suffixIcon: suffixIcon,
  );
}
