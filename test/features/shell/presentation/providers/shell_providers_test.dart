import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/definition/app_definition.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/shell/presentation/providers/shell_providers.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';

void main() {
  test('ShellState.copyWith keeps and overrides fields', () {
    const original = ShellState(
      isDrawerCollapsed: false,
      showSettings: false,
      activeRoute: 'chat',
    );

    final unchanged = original.copyWith();
    expect(unchanged.isDrawerCollapsed, isFalse);
    expect(unchanged.showSettings, isFalse);
    expect(unchanged.activeRoute, 'chat');

    final updated = original.copyWith(
      isDrawerCollapsed: true,
      showSettings: true,
      activeRoute: 'reports',
    );
    expect(updated.isDrawerCollapsed, isTrue);
    expect(updated.showSettings, isTrue);
    expect(updated.activeRoute, 'reports');
  });

  test('ShellController initializes from registered default route', () {
    final container = ProviderContainer(
      overrides: <Override>[
        appDefinitionProvider.overrideWith(
          (ref) => _buildDefinition(
            defaultShellRouteId: 'reports',
            shellRoutes: const <ShellRouteDefinition>[
              ShellRouteDefinition(
                id: 'reports',
                title: 'Reports',
                icon: Icons.dashboard_outlined,
                builder: _buildPlaceholderPage,
              ),
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(shellControllerProvider.notifier);
    var state = container.read(shellControllerProvider);
    expect(state.activeRoute, 'reports');
    expect(state.isDrawerCollapsed, isFalse);
    expect(state.showSettings, isFalse);

    notifier.toggleCollapsed();
    state = container.read(shellControllerProvider);
    expect(state.isDrawerCollapsed, isTrue);

    notifier.toggleShowSettings();
    state = container.read(shellControllerProvider);
    expect(state.showSettings, isTrue);

    notifier.openSettings();
    state = container.read(shellControllerProvider);
    expect(state.showSettings, isTrue);

    notifier.setRoute('users');
    state = container.read(shellControllerProvider);
    expect(state.activeRoute, 'users');
    expect(state.showSettings, isFalse);
  });

  test(
    'ShellController initializes with fallback when default route is unauthorized',
    () {
      final authController = _MutableAuthController(
        initialSession: const AuthSession(
          accessToken: 'token',
          refreshToken: 'refresh',
          userId: 'user-1',
          roles: <String>[
            'com.vorsocomputing.mugen.acp:authenticated',
            webPlatformAccessRole,
          ],
        ),
      );
      final container = ProviderContainer(
        overrides: <Override>[
          appDefinitionProvider.overrideWith(
            (ref) => _buildDefinition(
              defaultShellRouteId: RouteIds.localUsers,
              shellRoutes: const <ShellRouteDefinition>[
                ShellRouteDefinition(
                  id: RouteIds.chat,
                  title: 'AI Assist',
                  icon: Icons.chat_bubble_outline,
                  requiredRoles: <String>[webPlatformAccessRole],
                  builder: _buildPlaceholderPage,
                ),
                ShellRouteDefinition(
                  id: RouteIds.localUsers,
                  title: 'LocalUsers',
                  icon: Icons.groups_outlined,
                  requiredRoles: <String>[
                    'com.vorsocomputing.mugen.acp:administrator',
                  ],
                  builder: _buildPlaceholderPage,
                ),
              ],
            ),
          ),
          authControllerProvider.overrideWith(() => authController),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(shellControllerProvider).activeRoute,
        RouteIds.chat,
      );
    },
  );

  test('ShellController falls back when a requested route is unauthorized', () {
    final authController = _MutableAuthController(
      initialSession: const AuthSession(
        accessToken: 'token',
        refreshToken: 'refresh',
        userId: 'user-1',
        roles: <String>[
          'com.vorsocomputing.mugen.acp:authenticated',
          webPlatformAccessRole,
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: <Override>[
        authControllerProvider.overrideWith(() => authController),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(shellControllerProvider.notifier);
    notifier.setRoute(RouteIds.localUsers);

    final state = container.read(shellControllerProvider);
    expect(state.activeRoute, RouteIds.chat);
    expect(state.showSettings, isFalse);
  });

  test(
    'ShellController revalidates route after role changes without closing settings',
    () {
      final authController = _MutableAuthController(
        initialSession: const AuthSession(
          accessToken: 'token',
          refreshToken: 'refresh',
          userId: 'admin-1',
          roles: <String>[
            'com.vorsocomputing.mugen.acp:administrator',
            webPlatformAccessRole,
          ],
        ),
      );
      final container = ProviderContainer(
        overrides: <Override>[
          authControllerProvider.overrideWith(() => authController),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(shellControllerProvider.notifier);
      notifier.setRoute(RouteIds.localUsers);
      notifier.openSettings();

      authController.setSession(
        const AuthSession(
          accessToken: 'token',
          refreshToken: 'refresh',
          userId: 'user-1',
          roles: <String>[
            'com.vorsocomputing.mugen.acp:authenticated',
            webPlatformAccessRole,
          ],
        ),
      );

      expect(notifier.revalidateRoute(), isTrue);
      final state = container.read(shellControllerProvider);
      expect(state.activeRoute, RouteIds.chat);
      expect(state.showSettings, isTrue);
    },
  );

  test('ShellController revalidates route after app definition changes', () {
    var definition = _buildDefinition(
      shellRoutes: const <ShellRouteDefinition>[
        ShellRouteDefinition(
          id: RouteIds.chat,
          title: 'AI Assist',
          icon: Icons.chat_bubble_outline,
          builder: _buildPlaceholderPage,
        ),
        ShellRouteDefinition(
          id: RouteIds.runtimeControl,
          title: 'Runtime Control',
          icon: Icons.settings_input_component_outlined,
          builder: _buildPlaceholderPage,
        ),
      ],
    );
    final authController = _MutableAuthController(
      initialSession: const AuthSession(
        accessToken: 'token',
        refreshToken: 'refresh',
        userId: 'user-1',
        roles: <String>[
          'com.vorsocomputing.mugen.acp:authenticated',
          webPlatformAccessRole,
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: <Override>[
        appDefinitionProvider.overrideWith((ref) => definition),
        authControllerProvider.overrideWith(() => authController),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(shellControllerProvider.notifier);
    notifier.setRoute(RouteIds.runtimeControl);
    expect(
      container.read(shellControllerProvider).activeRoute,
      RouteIds.runtimeControl,
    );

    definition = _buildDefinition(
      shellRoutes: const <ShellRouteDefinition>[
        ShellRouteDefinition(
          id: RouteIds.chat,
          title: 'AI Assist',
          icon: Icons.chat_bubble_outline,
          builder: _buildPlaceholderPage,
        ),
        ShellRouteDefinition(
          id: RouteIds.runtimeControl,
          title: 'Runtime Control',
          icon: Icons.settings_input_component_outlined,
          requiredRoles: <String>['com.vorsocomputing.mugen.acp:administrator'],
          builder: _buildPlaceholderPage,
        ),
      ],
    );
    container.invalidate(appDefinitionProvider);

    expect(notifier.revalidateRoute(), isTrue);
    expect(container.read(shellControllerProvider).activeRoute, RouteIds.chat);
  });
}

class _MutableAuthController extends AuthController {
  _MutableAuthController({required this.initialSession});

  final AuthSession? initialSession;

  @override
  AuthControllerState build() {
    return AuthControllerState(isLoading: false, session: initialSession);
  }

  void setSession(AuthSession? session) {
    state = AuthControllerState(isLoading: false, session: session);
  }

  @override
  bool hasRoles(List<String> roles, {String operator = 'and'}) {
    final sessionRoles = state.session?.roles ?? const <String>[];
    if (roles.isEmpty) {
      return true;
    }

    if (operator.toLowerCase() == 'or') {
      return roles.any(sessionRoles.contains);
    }

    return roles.every(sessionRoles.contains);
  }
}

MugenUiAppDefinition _buildDefinition({
  String defaultShellRouteId = RouteIds.chat,
  required List<ShellRouteDefinition> shellRoutes,
}) {
  return MugenUiAppDefinition(
    config: AppConfig.defaults(),
    defaultShellRouteId: defaultShellRouteId,
    modules: <MugenUiModule>[
      MugenUiModule(id: 'test.shell', shellRoutes: shellRoutes),
    ],
  );
}

Widget _buildPlaceholderPage(BuildContext context) {
  return const SizedBox.shrink();
}
