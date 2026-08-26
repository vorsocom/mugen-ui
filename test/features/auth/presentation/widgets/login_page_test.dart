import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/auth/presentation/pages/login_page.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/tenant_invite/presentation/providers/pending_invite_providers.dart';
import 'package:mugen_ui/shared/presentation/navigation/app_navigator.dart';
import 'package:mugen_ui/shared/presentation/theme/app_form_style.dart';

void main() {
  testWidgets('LoginPage renders branded production login controls', (
    WidgetTester tester,
  ) async {
    final authController = _TestAuthController(
      initialState: const AuthControllerState(isLoading: false, session: null),
    );
    await _pumpLoginPage(tester, authController: authController);

    expect(find.text('WELCOME BACK.'), findsOneWidget);
    expect(find.text('ONE ACCESS POINT. EVERY CONVERSATION.'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Remember me'), findsNothing);
    expect(find.textContaining('Forgot'), findsNothing);
    expect(find.byKey(const Key('portal-back-link')), findsOneWidget);

    final guidance = tester
        .widgetList<AppFieldHelpIcon>(find.byType(AppFieldHelpIcon))
        .map((icon) => icon.message)
        .toList(growable: false);
    expect(guidance, hasLength(2));
    expect(guidance, anyElement(contains('local account you want to sign in')));
    expect(guidance, anyElement(contains('authenticate this sign-in attempt')));

    final submit = tester.widget<FilledButton>(
      find.byKey(const Key('login-submit-button')),
    );
    expect(submit.style?.minimumSize?.resolve(<WidgetState>{})?.height, 52);
  });

  testWidgets('LoginPage validates required fields and toggles visibility', (
    WidgetTester tester,
  ) async {
    final authController = _TestAuthController(
      initialState: const AuthControllerState(isLoading: false, session: null),
    );
    await _pumpLoginPage(tester, authController: authController);

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    await tester.tap(find.byKey(const Key('login-password-visibility')));
    await tester.pump();
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pump();
    expect(find.text('Field cannot be empty.'), findsNWidgets(2));
    expect(authController.loginCallCount, 0);
  });

  testWidgets('LoginPage navigates to app route on successful submit', (
    WidgetTester tester,
  ) async {
    final authController = _TestAuthController(
      initialState: const AuthControllerState(isLoading: false, session: null),
    )..loginResult = true;
    final navigator = _FakeAppNavigator();
    await _pumpLoginPage(
      tester,
      authController: authController,
      navigator: navigator,
    );

    await _enterCredentials(tester);
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(authController.loginCallCount, 1);
    expect(authController.lastUsername, 'alice');
    expect(authController.lastPassword, 'secret');
    expect(navigator.lastRoute, AppRoutePaths.app);
  });

  testWidgets('LoginPage navigates to pending invitation after login', (
    WidgetTester tester,
  ) async {
    final authController = _TestAuthController(
      initialState: const AuthControllerState(isLoading: false, session: null),
    )..loginResult = true;
    final navigator = _FakeAppNavigator();
    final pendingInviteController = PendingInviteController()
      ..setPending(
        const InviteRouteMatch(
          tenantId: 'tenant-1',
          invitationId: 'invite-2',
          token: 'abc',
        ),
      );
    await _pumpLoginPage(
      tester,
      authController: authController,
      navigator: navigator,
      pendingInviteController: pendingInviteController,
    );

    await _enterCredentials(tester);
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(navigator.lastRoute, '/invite/tenant-1/invite-2?token=abc');
    expect(pendingInviteController.state, isNull);
  });

  testWidgets('LoginPage submits with Enter and renders failure as an alert', (
    WidgetTester tester,
  ) async {
    final authController = _TestAuthController(
      initialState: const AuthControllerState(isLoading: false, session: null),
    )..loginResult = false;
    final navigator = _FakeAppNavigator();
    await _pumpLoginPage(
      tester,
      authController: authController,
      navigator: navigator,
    );

    await _enterCredentials(tester);
    await tester.tap(find.byKey(const Key('login-password-field')));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(authController.loginCallCount, 1);
    expect(navigator.lastRoute, isNull);
    expect(find.byType(AppErrorAlert), findsOneWidget);
    expect(find.text('Login failed. Please try again.'), findsOneWidget);
  });

  testWidgets(
    'LoginPage disables submission and shows progress while loading',
    (WidgetTester tester) async {
      final authController = _TestAuthController(
        initialState: const AuthControllerState(isLoading: true, session: null),
      );
      await _pumpLoginPage(tester, authController: authController);

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('login-submit-button')),
      );
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
    },
  );

  testWidgets('LoginPage stacks panels below the 900px breakpoint', (
    WidgetTester tester,
  ) async {
    final authController = _TestAuthController(
      initialState: const AuthControllerState(isLoading: false, session: null),
    );
    await _pumpLoginPage(
      tester,
      authController: authController,
      size: const Size(768, 1024),
    );

    final story = tester.getTopLeft(
      find.byKey(const Key('portal-login-story-title')),
    );
    final account = tester.getTopLeft(
      find.byKey(const Key('portal-login-title')),
    );
    expect(account.dy, greaterThan(story.dy));
    await tester.ensureVisible(
      find.byKey(const Key('login-password-visibility')),
    );
    await tester.tap(find.byKey(const Key('login-password-visibility')));
    await tester.pump();
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('LoginPage keeps panels side by side on desktop', (
    WidgetTester tester,
  ) async {
    final authController = _TestAuthController(
      initialState: const AuthControllerState(isLoading: false, session: null),
    );
    await _pumpLoginPage(
      tester,
      authController: authController,
      size: const Size(1440, 900),
    );

    final story = tester.getCenter(
      find.byKey(const Key('portal-login-story-title')),
    );
    final account = tester.getCenter(
      find.byKey(const Key('portal-login-title')),
    );
    expect(account.dx, greaterThan(story.dx));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _enterCredentials(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('login-username-field')),
    'alice',
  );
  await tester.enterText(
    find.byKey(const Key('login-password-field')),
    'secret',
  );
}

Future<void> _pumpLoginPage(
  WidgetTester tester, {
  required _TestAuthController authController,
  _FakeAppNavigator? navigator,
  PendingInviteController? pendingInviteController,
  Size size = const Size(1200, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final overrides = <Override>[
    authControllerProvider.overrideWith(() => authController),
    appNavigatorProvider.overrideWith(
      (Ref ref) => navigator ?? _FakeAppNavigator(),
    ),
  ];
  if (pendingInviteController != null) {
    overrides.add(
      pendingInviteControllerProvider.overrideWith(
        (ref) => pendingInviteController,
      ),
    );
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: LoginPage()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

class _TestAuthController extends AuthController {
  _TestAuthController({required this.initialState});

  final AuthControllerState initialState;
  bool loginResult = true;
  int loginCallCount = 0;
  String? lastUsername;
  String? lastPassword;

  @override
  AuthControllerState build() => initialState;

  @override
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    loginCallCount += 1;
    lastUsername = username;
    lastPassword = password;
    if (!loginResult) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Login failed. Please try again.',
      );
    }
    return loginResult;
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
