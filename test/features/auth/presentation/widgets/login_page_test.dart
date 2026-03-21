import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/auth/presentation/pages/login_page.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/tenant_invite/presentation/providers/pending_invite_providers.dart';
import 'package:mugen_ui/shared/presentation/feedback/snackbar_dispatcher.dart';
import 'package:mugen_ui/shared/presentation/navigation/app_navigator.dart';

void main() {
  testWidgets('LoginPage renders username/password fields', (
    WidgetTester tester,
  ) async {
    final authController = _TestAuthController(
      initialState: const AuthControllerState(isLoading: false, session: null),
    );
    final navigator = _FakeAppNavigator();
    final snackBars = _RecordingSnackBarDispatcher();

    await _pumpLoginPage(
      tester,
      authController: authController,
      navigator: navigator,
      snackBars: snackBars,
    );

    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('LoginPage validates required fields and toggles visibility', (
    WidgetTester tester,
  ) async {
    final authController = _TestAuthController(
      initialState: const AuthControllerState(isLoading: false, session: null),
    );
    final navigator = _FakeAppNavigator();
    final snackBars = _RecordingSnackBarDispatcher();

    await _pumpLoginPage(
      tester,
      authController: authController,
      navigator: navigator,
      snackBars: snackBars,
    );

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

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
    final snackBars = _RecordingSnackBarDispatcher();

    await _pumpLoginPage(
      tester,
      authController: authController,
      navigator: navigator,
      snackBars: snackBars,
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'alice');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(authController.loginCallCount, 1);
    expect(authController.lastUsername, 'alice');
    expect(authController.lastPassword, 'secret');
    expect(navigator.lastRoute, RouteIds.app);
    expect(snackBars.messages, isEmpty);
  });

  testWidgets('LoginPage navigates to pending invite route when available', (
    WidgetTester tester,
  ) async {
    final authController = _TestAuthController(
      initialState: const AuthControllerState(isLoading: false, session: null),
    )..loginResult = true;
    final navigator = _FakeAppNavigator();
    final snackBars = _RecordingSnackBarDispatcher();
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
      snackBars: snackBars,
      pendingInviteController: pendingInviteController,
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'alice');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(navigator.lastRoute, '/invite/tenant-1/invite-2');
  });

  testWidgets('LoginPage shows snackbar on submit failure via Enter key', (
    WidgetTester tester,
  ) async {
    final authController = _TestAuthController(
      initialState: const AuthControllerState(isLoading: false, session: null),
    )..loginResult = false;
    final navigator = _FakeAppNavigator();
    final snackBars = _RecordingSnackBarDispatcher();

    await _pumpLoginPage(
      tester,
      authController: authController,
      navigator: navigator,
      snackBars: snackBars,
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'alice');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
    await tester.tap(find.byType(TextFormField).at(1));
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(authController.loginCallCount, 1);
    expect(navigator.lastRoute, isNull);
    expect(snackBars.messages, <String>['Login failed. Please try again.']);
  });

  testWidgets('LoginPage shows progress indicator when loading', (
    WidgetTester tester,
  ) async {
    final authController = _TestAuthController(
      initialState: const AuthControllerState(isLoading: true, session: null),
    );
    final navigator = _FakeAppNavigator();
    final snackBars = _RecordingSnackBarDispatcher();

    await _pumpLoginPage(
      tester,
      authController: authController,
      navigator: navigator,
      snackBars: snackBars,
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Login'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _pumpLoginPage(
  WidgetTester tester, {
  required _TestAuthController authController,
  required _FakeAppNavigator navigator,
  required _RecordingSnackBarDispatcher snackBars,
  PendingInviteController? pendingInviteController,
}) async {
  final overrides = <Override>[
    authControllerProvider.overrideWith(() => authController),
    appNavigatorProvider.overrideWith((Ref ref) => navigator),
    snackBarDispatcherProvider.overrideWith((Ref ref) => snackBars),
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
      child: const MaterialApp(home: Scaffold(body: LoginPage())),
    ),
  );
  await tester.pump();
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

class _RecordingSnackBarDispatcher extends SnackBarDispatcher {
  final List<String> messages = <String>[];

  @override
  void show(AppNavigator navigator, String content) {
    messages.add(content);
  }
}
