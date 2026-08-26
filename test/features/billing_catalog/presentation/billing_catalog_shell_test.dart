import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/definition/app_definition.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/shell/presentation/pages/shell_page.dart';
import 'package:mugen_ui/features/shell/presentation/providers/shell_providers.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';

final _billingAvailabilityProvider =
    StateNotifierProvider<_AvailabilityController, ShellRouteAvailability>(
      (ref) => _AvailabilityController(const ShellRouteAvailability.pending()),
    );

void main() {
  testWidgets('Billing Catalog navigation follows runtime availability', (
    tester,
  ) async {
    final fixture = await _pumpShell(
      tester,
      initialAvailability: const ShellRouteAvailability.pending(),
    );

    expect(find.text('Chat route'), findsOneWidget);
    expect(find.text('Billing Catalog'), findsNothing);
    expect(find.text('Platform Capabilities'), findsNothing);

    fixture.availability.set(
      const ShellRouteAvailability.unavailable(
        'Billing extension is disabled.',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Billing Catalog'), findsNothing);

    fixture.availability.set(const ShellRouteAvailability.available());
    await tester.pumpAndSettle();
    expect(find.text('Billing Catalog'), findsOneWidget);
    expect(find.text('Platform Capabilities'), findsOneWidget);
  });

  testWidgets('direct pending route redirects when Billing is unavailable', (
    tester,
  ) async {
    final fixture = await _pumpShell(
      tester,
      defaultRouteId: RouteIds.billingCatalog,
      initialAvailability: const ShellRouteAvailability.pending(),
    );

    expect(find.text('Billing route'), findsOneWidget);
    expect(
      fixture.container.read(shellControllerProvider).activeRoute,
      RouteIds.billingCatalog,
    );

    fixture.availability.set(
      const ShellRouteAvailability.unavailable(
        'Billing extension bootstrap failed.',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chat route'), findsOneWidget);
    expect(find.text('Billing route'), findsNothing);
    expect(
      fixture.container.read(shellControllerProvider).activeRoute,
      RouteIds.chat,
    );
    expect(find.text('Billing extension bootstrap failed.'), findsOneWidget);
  });

  testWidgets('unavailable direct route shows a clear state without fallback', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      defaultRouteId: RouteIds.billingCatalog,
      includeChat: false,
      initialAvailability: const ShellRouteAvailability.unavailable(
        'Billing extension is unavailable on this platform.',
      ),
    );

    expect(
      find.text('Billing extension is unavailable on this platform.'),
      findsOneWidget,
    );
    expect(find.text('Billing route'), findsNothing);
  });
}

Future<_ShellFixture> _pumpShell(
  WidgetTester tester, {
  String defaultRouteId = RouteIds.chat,
  bool includeChat = true,
  required ShellRouteAvailability initialAvailability,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final routes = <ShellRouteDefinition>[
    if (includeChat)
      const ShellRouteDefinition(
        id: RouteIds.chat,
        title: 'AI Assist',
        icon: Icons.chat_bubble_outline,
        section: 'Workspace',
        requiredRoles: <String>[webPlatformAccessRole],
        builder: _buildChatRoute,
      ),
    ShellRouteDefinition(
      id: RouteIds.billingCatalog,
      title: 'Billing Catalog',
      icon: Icons.payments_outlined,
      section: 'Platform Configuration',
      group: 'Platform Capabilities',
      availabilityProvider: _billingAvailabilityProvider,
      builder: _buildBillingRoute,
    ),
  ];
  final definition = MugenUiAppDefinition(
    config: AppConfig.defaults(),
    defaultShellRouteId: defaultRouteId,
    modules: <MugenUiModule>[
      MugenUiModule(id: 'test.billing-shell', shellRoutes: routes),
    ],
  );
  final container = ProviderContainer(
    overrides: <Override>[
      appDefinitionProvider.overrideWithValue(definition),
      authControllerProvider.overrideWith(() => _ShellAuthController()),
      _billingAvailabilityProvider.overrideWith(
        (ref) => _AvailabilityController(initialAvailability),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ShellPage()),
    ),
  );
  await tester.pumpAndSettle();
  return _ShellFixture(
    container: container,
    availability: container.read(_billingAvailabilityProvider.notifier),
  );
}

class _ShellFixture {
  const _ShellFixture({required this.container, required this.availability});

  final ProviderContainer container;
  final _AvailabilityController availability;
}

class _AvailabilityController extends StateNotifier<ShellRouteAvailability> {
  _AvailabilityController(super.state);

  void set(ShellRouteAvailability value) {
    state = value;
  }
}

class _ShellAuthController extends AuthController {
  @override
  AuthControllerState build() {
    return const AuthControllerState(
      isLoading: false,
      session: AuthSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        userId: 'user',
        roles: <String>[webPlatformAccessRole],
      ),
    );
  }

  @override
  Future<bool> logout() async => true;
}

Widget _buildChatRoute(BuildContext context) {
  return const Center(child: Text('Chat route'));
}

Widget _buildBillingRoute(BuildContext context) {
  return const Center(child: Text('Billing route'));
}
