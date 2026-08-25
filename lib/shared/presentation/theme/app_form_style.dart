import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mugen_ui/shared/application/api_error_message.dart';
import 'package:mugen_ui/shared/presentation/admin/admin_components.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

class AppFormPanel extends StatelessWidget {
  const AppFormPanel({
    required this.child,
    super.key,
    this.margin = EdgeInsets.zero,
    this.padding = const EdgeInsets.all(20),
    this.showBorder = true,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppUiPalette.surface,
        border: showBorder ? Border.all(color: AppUiPalette.border) : null,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class AppResponsiveDialog extends StatelessWidget {
  const AppResponsiveDialog({
    required this.child,
    super.key,
    this.maxWidth = 520,
    this.maxHeight = 760,
    this.insetPadding = const EdgeInsets.all(24),
    this.scrollable = false,
  });

  final Widget child;
  final double maxWidth;
  final double maxHeight;
  final EdgeInsets insetPadding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final availableWidth = math.max(
      1.0,
      mediaSize.width - insetPadding.horizontal,
    );
    final availableHeight = math.max(
      1.0,
      mediaSize.height - insetPadding.vertical,
    );

    return Dialog(
      insetPadding: insetPadding,
      backgroundColor: AppUiPalette.surface,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppUiPalette.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(maxWidth, availableWidth),
          maxHeight: math.min(maxHeight, availableHeight),
        ),
        child: scrollable
            ? SingleChildScrollView(primary: false, child: child)
            : child,
      ),
    );
  }
}

class AppFormDialog extends StatelessWidget {
  const AppFormDialog({
    required this.title,
    required this.body,
    required this.actions,
    super.key,
    this.maxWidth = 520,
    this.maxHeight = 760,
    this.insetPadding = const EdgeInsets.all(24),
    this.bodyPadding = const EdgeInsets.all(20),
    this.scrollable = true,
    this.leading,
    this.headerActions = const <Widget>[],
    this.showCloseButton = true,
    this.closeEnabled = true,
    this.onClose,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final double maxWidth;
  final double maxHeight;
  final EdgeInsets insetPadding;
  final EdgeInsetsGeometry bodyPadding;
  final bool scrollable;
  final Widget? leading;
  final List<Widget> headerActions;
  final bool showCloseButton;
  final bool closeEnabled;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return AppResponsiveDialog(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      insetPadding: insetPadding,
      child: AppFormPanel(
        padding: EdgeInsets.zero,
        showBorder: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 10)],
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ...headerActions,
                  if (showCloseButton)
                    IconButton(
                      tooltip: 'Close',
                      onPressed: closeEnabled
                          ? onClose ?? () => Navigator.of(context).pop()
                          : null,
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ),
            const Divider(
              key: Key('app-form-dialog-header-divider'),
              height: 1,
            ),
            Flexible(
              fit: FlexFit.loose,
              child: scrollable
                  ? SingleChildScrollView(
                      key: const Key('app-form-dialog-body-scroll'),
                      primary: false,
                      padding: bodyPadding,
                      child: body,
                    )
                  : Padding(padding: bodyPadding, child: body),
            ),
            const Divider(
              key: Key('app-form-dialog-footer-divider'),
              height: 1,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: actions,
                ),
              ),
            ),
          ],
        ),
      ),
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
    final resolvedMessage = normalizeApiErrorMessage(message);
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
      return AppFormDialog(
        maxWidth: 520,
        title: title,
        leading: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppUiPalette.surfaceStrong,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: AppUiPalette.textPrimary),
        ),
        body: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppUiPalette.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            key: cancelButtonKey,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            key: confirmButtonKey,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
}

InputDecoration appFormInputDecoration({
  required String labelText,
  required String helpText,
  Widget? suffixIcon,
  String? hintText,
  Key? helpKey,
  int? errorMaxLines,
}) {
  assert(helpText.trim().isNotEmpty, 'helpText must not be blank.');
  final baseBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(adminRadius),
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
    fillColor: AppUiPalette.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: baseBorder,
    focusedBorder: baseBorder.copyWith(
      borderSide: const BorderSide(color: AppUiPalette.accent, width: 1.5),
    ),
    errorBorder: baseBorder.copyWith(
      borderSide: const BorderSide(color: AppUiPalette.danger),
    ),
    focusedErrorBorder: baseBorder.copyWith(
      borderSide: const BorderSide(color: AppUiPalette.danger, width: 1.5),
    ),
    suffixIcon: resolvedSuffixIcon,
    suffixIconConstraints: resolvedSuffixIcon == null
        ? null
        : const BoxConstraints(minHeight: 48, minWidth: 48),
  );
}

Widget appFieldLabelWithHelp({
  required String labelText,
  required String helpText,
  Key? helpKey,
  TextStyle? style,
}) {
  final message = helpText.trim();
  assert(message.isNotEmpty, 'helpText must not be blank.');

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
  const AppFieldHelpIcon({required this.message, super.key, this.helpKey})
    : assert(message != '', 'message must not be blank.');

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
      textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppUiPalette.drawerText,
        height: 1.3,
      ),
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
  required String helpText,
  required Key? helpKey,
}) {
  final message = helpText.trim();

  final helpIcon = Padding(
    padding: EdgeInsets.only(right: suffixIcon == null ? 6 : 2),
    child: AppFieldHelpIcon(message: message, helpKey: helpKey),
  );

  if (suffixIcon == null) {
    return helpIcon;
  }

  return Row(mainAxisSize: MainAxisSize.min, children: [suffixIcon, helpIcon]);
}
