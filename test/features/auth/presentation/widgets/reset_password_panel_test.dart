import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/auth/domain/repositories/auth_repository.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/auth/presentation/widgets/reset_password_panel.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';
import 'package:mugen_ui/shared/presentation/feedback/snackbar_dispatcher.dart';
import 'package:mugen_ui/shared/presentation/navigation/app_navigator.dart';

void main() {
  testWidgets(
    'ResetPasswordPanel validates form input and toggles password visibility',
    (WidgetTester tester) async {
      final repository = _FakeAuthRepository();
      final authController = _TestAuthController();
      final navigator = _FakeAppNavigator();
      final snackBars = _RecordingSnackBarDispatcher();

      await _pumpPanel(
        tester,
        repository: repository,
        authController: authController,
        navigator: navigator,
        snackBars: snackBars,
      );

      expect(find.byIcon(Icons.visibility_outlined), findsNWidgets(3));

      await tester.tap(find.byTooltip('Close'));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.visibility_outlined).at(0));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.visibility_outlined).at(0));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.visibility_outlined).at(0));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_off_outlined), findsNWidgets(3));

      await tester.tap(find.widgetWithText(FilledButton, 'Reset Password'));
      await tester.pumpAndSettle();
      expect(find.text('Field cannot be empty.'), findsNWidgets(3));

      await _fillForm(
        tester,
        currentPassword: 'current',
        newPassword: 'new-1',
        confirmPassword: 'new-2',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Reset Password'));
      await tester.pumpAndSettle();
      expect(find.text('Passwords must match.'), findsOneWidget);
    },
  );

  testWidgets('ResetPasswordPanel shows failure snackbar on API error', (
    WidgetTester tester,
  ) async {
    final repository = _FakeAuthRepository()
      ..resetResult = const Result<void>.failure(
        UnexpectedFailure('Reset rejected'),
      );
    final authController = _TestAuthController();
    final navigator = _FakeAppNavigator();
    final snackBars = _RecordingSnackBarDispatcher();

    await _pumpPanel(
      tester,
      repository: repository,
      authController: authController,
      navigator: navigator,
      snackBars: snackBars,
    );

    await _fillForm(
      tester,
      currentPassword: 'old',
      newPassword: 'new-pass',
      confirmPassword: 'new-pass',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Reset Password'));
    await tester.pumpAndSettle();

    expect(repository.resetCalls, 1);
    expect(snackBars.messages, <String>['Reset rejected']);
    expect(authController.refreshSessionCalls, 0);
    expect(navigator.lastRoute, isNull);
  });

  testWidgets(
    'ResetPasswordPanel shows spinner while saving and navigates on success',
    (WidgetTester tester) async {
      final repository = _FakeAuthRepository();
      final pending = Completer<Result<void>>();
      repository.pendingReset = pending;
      final authController = _TestAuthController();
      final navigator = _FakeAppNavigator();
      final snackBars = _RecordingSnackBarDispatcher();

      await _pumpPanel(
        tester,
        repository: repository,
        authController: authController,
        navigator: navigator,
        snackBars: snackBars,
      );

      await _fillForm(
        tester,
        currentPassword: 'old',
        newPassword: 'new-pass',
        confirmPassword: 'new-pass',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Reset Password'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pending.complete(const Result<void>.success(null));
      await tester.pumpAndSettle();

      expect(repository.resetCalls, 1);
      expect(repository.lastCurrentPassword, 'old');
      expect(repository.lastNewPassword, 'new-pass');
      expect(repository.lastConfirmNewPassword, 'new-pass');
      expect(snackBars.messages, <String>[
        'Password reset successful. Please log in again.',
      ]);
      expect(authController.refreshSessionCalls, 1);
      expect(navigator.lastRoute, RouteIds.login);
    },
  );
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required _FakeAuthRepository repository,
  required _TestAuthController authController,
  required _FakeAppNavigator navigator,
  required _RecordingSnackBarDispatcher snackBars,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(() => authController),
        appNavigatorProvider.overrideWith((Ref ref) => navigator),
        snackBarDispatcherProvider.overrideWith((Ref ref) => snackBars),
      ],
      child: const MaterialApp(home: Scaffold(body: ResetPasswordPanel())),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _fillForm(
  WidgetTester tester, {
  required String currentPassword,
  required String newPassword,
  required String confirmPassword,
}) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), currentPassword);
  await tester.enterText(fields.at(1), newPassword);
  await tester.enterText(fields.at(2), confirmPassword);
}

class _FakeAuthRepository implements AuthRepository {
  Result<void> resetResult = const Result<void>.success(null);
  Completer<Result<void>>? pendingReset;

  int resetCalls = 0;
  String? lastCurrentPassword;
  String? lastNewPassword;
  String? lastConfirmNewPassword;

  @override
  Result<AuthSession?> currentSession() {
    return const Result<AuthSession?>.success(
      AuthSession(
        accessToken: 'a',
        refreshToken: 'r',
        userId: 'u1',
        roles: <String>[],
      ),
    );
  }

  @override
  Result<bool> hasRoles({
    required List<String> roles,
    String operator = 'and',
  }) {
    return const Result<bool>.success(true);
  }

  @override
  Future<Result<AuthSession>> login({
    required String username,
    required String password,
  }) async {
    return const Result<AuthSession>.success(
      AuthSession(
        accessToken: 'a',
        refreshToken: 'r',
        userId: 'u1',
        roles: <String>[],
      ),
    );
  }

  @override
  Future<Result<void>> logout() async => const Result<void>.success(null);

  @override
  Future<Result<void>> resetOwnPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    resetCalls += 1;
    lastCurrentPassword = currentPassword;
    lastNewPassword = newPassword;
    lastConfirmNewPassword = confirmNewPassword;
    final pending = pendingReset;
    if (pending != null) {
      return pending.future;
    }
    return resetResult;
  }
}

class _TestAuthController extends AuthController {
  int refreshSessionCalls = 0;

  @override
  AuthControllerState build() =>
      const AuthControllerState(isLoading: false, session: null);

  @override
  void refreshSession() {
    refreshSessionCalls += 1;
  }

  @override
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    return true;
  }

  @override
  Future<bool> logout() async => true;

  @override
  bool hasRoles(List<String> roles, {String operator = 'and'}) => true;
}

class _FakeAppNavigator extends AppNavigator {
  String? lastRoute;

  @override
  Future<void> navigateTo(String routeName) async {
    lastRoute = routeName;
  }
}

class _RecordingSnackBarDispatcher extends SnackBarDispatcher {
  final List<String> messages = <String>[];

  @override
  void show(AppNavigator navigator, String content) {
    messages.add(content);
  }
}
