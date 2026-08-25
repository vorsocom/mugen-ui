import 'package:flutter/material.dart';

import 'package:mugen_ui/shared/application/api_error_message.dart';
import 'package:mugen_ui/shared/presentation/navigation/app_navigator.dart';

const int _snackBarDurationSeconds = 5;

class SnackBarDispatcher {
  const SnackBarDispatcher();

  void show(AppNavigator navigator, String content) {
    final context = navigator.currentContext();
    if (context == null) {
      return;
    }
    showInContext(context, content);
  }

  void showInContext(BuildContext context, String content) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }

    final resolvedContent = normalizeApiErrorMessage(
      content,
      fallback: 'Request failed.',
    );
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: _snackBarDurationSeconds),
        content: Text(resolvedContent),
        showCloseIcon: true,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
    );
  }
}
