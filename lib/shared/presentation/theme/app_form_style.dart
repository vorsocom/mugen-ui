import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class AppErrorAlert extends StatelessWidget {
  const AppErrorAlert({
    required this.message,
    super.key,
    this.copyButtonKey,
    this.copyTooltip = 'Copy error details',
  });

  final Key? copyButtonKey;
  final String copyTooltip;
  final String message;

  @override
  Widget build(BuildContext context) {
    final resolvedMessage = message.trim();
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: AppUiPalette.textPrimary,
      height: 1.3,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppUiPalette.dangerSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppUiPalette.danger.withValues(alpha: 0.38)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline,
              size: 20,
              color: AppUiPalette.danger,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: SelectableText(resolvedMessage, style: textStyle)),
          const SizedBox(width: 4),
          Tooltip(
            message: copyTooltip,
            child: IconButton(
              key: copyButtonKey,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              icon: const Icon(
                Icons.content_copy,
                size: 18,
                color: AppUiPalette.danger,
              ),
              onPressed: resolvedMessage.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(
                        ClipboardData(text: resolvedMessage),
                      );
                    },
            ),
          ),
        ],
      ),
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
  String? helpText,
  Key? helpKey,
  int? errorMaxLines,
}) {
  final baseBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppUiPalette.border),
  );

  final resolvedSuffixIcon = _fieldSuffixIcon(
    suffixIcon: suffixIcon,
    helpText: helpText,
    helpKey: helpKey,
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
    suffixIcon: resolvedSuffixIcon,
    suffixIconConstraints: resolvedSuffixIcon == null
        ? null
        : const BoxConstraints(minHeight: 48, minWidth: 48),
  );
}

Widget appFieldLabelWithHelp({
  required String labelText,
  required String? helpText,
  Key? helpKey,
  TextStyle? style,
}) {
  final message = helpText?.trim();
  if (message == null || message.isEmpty) {
    return Text(labelText, style: style);
  }

  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: Text(labelText, overflow: TextOverflow.ellipsis, style: style),
      ),
      const SizedBox(width: 6),
      AppFieldHelpIcon(message: message, helpKey: helpKey),
    ],
  );
}

class AppFieldHelpIcon extends StatelessWidget {
  const AppFieldHelpIcon({required this.message, super.key, this.helpKey});

  final String message;
  final Key? helpKey;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      key: helpKey,
      message: message,
      waitDuration: const Duration(milliseconds: 350),
      showDuration: const Duration(seconds: 12),
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      textStyle: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: Colors.white, height: 1.3),
      child: const SizedBox.square(
        dimension: 22,
        child: Center(
          child: Icon(
            Icons.info_outline,
            size: 16,
            color: AppUiPalette.textSecondary,
          ),
        ),
      ),
    );
  }
}

Widget? _fieldSuffixIcon({
  required Widget? suffixIcon,
  required String? helpText,
  required Key? helpKey,
}) {
  final message = helpText?.trim();
  if (message == null || message.isEmpty) {
    return suffixIcon;
  }

  final helpIcon = Padding(
    padding: EdgeInsets.only(right: suffixIcon == null ? 6 : 2),
    child: AppFieldHelpIcon(message: message, helpKey: helpKey),
  );

  if (suffixIcon == null) {
    return helpIcon;
  }

  return Row(mainAxisSize: MainAxisSize.min, children: [suffixIcon, helpIcon]);
}
