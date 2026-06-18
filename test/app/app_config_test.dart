import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/definition/app_definition.dart';
import 'package:mugen_ui/app/definition/core_modules.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/auth/presentation/widgets/auth_guard.dart';

void main() {
  test('AppConfig.merge overrides only provided fields', () {
    final runtimeOverride = AppConfigurationOverride();
    final apiOverride = ApiConfigOverride();
    final defaults = AppConfig.defaults();

    final merged = defaults.merge(
      const AppConfigurationOverride(
        appName: 'Custom Name',
        activeRoles: <AppRoleConfig>[
          AppRoleConfig(name: 'custom:role', displayName: 'Custom'),
        ],
        api: ApiConfigOverride(
          endpoints: ApiEndpointsOverride(
            acpBase: 'custom/acp/v2',
            webMessages: 'custom/messages',
            authDeleteUser: 'custom/users/{user_id}/delete',
            tenantMembershipActionSuspend:
                'custom/tenants/{tenant_id}/memberships/{membership_id}/suspend',
            rbacTenantRoleMembership:
                'custom/tenants/{tenant_id}/role-memberships',
            auditEvent: 'custom/audit-events',
          ),
        ),
      ),
    );
    final mergedWithoutSuspendOverride = defaults.merge(
      const AppConfigurationOverride(
        api: ApiConfigOverride(
          endpoints: ApiEndpointsOverride(webEvents: 'custom/events'),
        ),
      ),
    );

    expect(merged.appName, 'Custom Name');
    expect(merged.appVersion, defaults.appVersion);
    expect(merged.activeRoles.single.name, 'custom:role');
    expect(merged.api.baseUrl, defaults.api.baseUrl);
    expect(defaults.api.endpoints.acpBase, 'core/acp/v1');
    expect(merged.api.endpoints.acpBase, 'custom/acp/v2');
    expect(merged.api.endpoints.webMessages, 'custom/messages');
    expect(defaults.api.endpoints.webMessages, 'core/web/v1/messages');
    expect(defaults.api.endpoints.webEvents, 'core/web/v1/events');
    expect(defaults.api.endpoints.webMediaBase, 'core/web/v1/media');
    expect(
      defaults.api.endpoints.authTenantInvitationRedeem,
      'core/acp/v1/auth/tenants/{tenant_id}/invitations/{invitation_id}/redeem',
    );
    expect(
      defaults.api.endpoints.authDeleteUser,
      'core/acp/v1/Users/{user_id}/\$action/delete',
    );
    expect(defaults.api.endpoints.tenant, 'core/acp/v1/Tenants');
    expect(
      defaults.api.endpoints.tenantMembershipActionSuspend,
      'core/acp/v1/tenants/{tenant_id}/TenantMemberships/{membership_id}/\$action/suspend',
    );
    expect(defaults.api.endpoints.rbacGlobalRole, 'core/acp/v1/GlobalRoles');
    expect(
      defaults.api.endpoints.refreshTokenActionRevoke,
      'core/acp/v1/RefreshTokens/{refresh_token_id}/\$action/revoke',
    );
    expect(
      defaults.api.endpoints.rbacTenantRole,
      'core/acp/v1/tenants/{tenant_id}/Roles',
    );
    expect(
      defaults.api.endpoints.rbacTenantRoleActionDeprecate,
      'core/acp/v1/tenants/{tenant_id}/Roles/{role_id}/\$action/deprecate',
    );
    expect(
      defaults.api.endpoints.rbacTenantRoleActionReactivate,
      'core/acp/v1/tenants/{tenant_id}/Roles/{role_id}/\$action/reactivate',
    );
    expect(
      defaults.api.endpoints.rbacPermissionObject,
      'core/acp/v1/PermissionObjects',
    );
    expect(
      defaults.api.endpoints.rbacPermissionObjectActionDeprecate,
      'core/acp/v1/PermissionObjects/{permission_object_id}/\$action/deprecate',
    );
    expect(
      defaults.api.endpoints.rbacPermissionObjectActionReactivate,
      'core/acp/v1/PermissionObjects/{permission_object_id}/\$action/reactivate',
    );
    expect(
      defaults.api.endpoints.rbacPermissionType,
      'core/acp/v1/PermissionTypes',
    );
    expect(
      defaults.api.endpoints.rbacPermissionTypeActionDeprecate,
      'core/acp/v1/PermissionTypes/{permission_type_id}/\$action/deprecate',
    );
    expect(
      defaults.api.endpoints.rbacPermissionTypeActionReactivate,
      'core/acp/v1/PermissionTypes/{permission_type_id}/\$action/reactivate',
    );
    expect(
      defaults.api.endpoints.rbacGlobalPermissionEntry,
      'core/acp/v1/GlobalPermissionEntries',
    );
    expect(
      defaults.api.endpoints.rbacTenantPermissionEntry,
      'core/acp/v1/tenants/{tenant_id}/PermissionEntries',
    );
    expect(
      defaults.api.endpoints.rbacTenantRoleMembership,
      'core/acp/v1/tenants/{tenant_id}/RoleMemberships',
    );
    expect(defaults.api.endpoints.auditEvent, 'core/acp/v1/AuditEvents');
    expect(
      defaults.api.endpoints.auditEventTenant,
      'core/acp/v1/tenants/{tenant_id}/AuditEvents',
    );
    expect(
      merged.api.endpoints.tenantMembershipActionSuspend,
      'custom/tenants/{tenant_id}/memberships/{membership_id}/suspend',
    );
    expect(merged.api.endpoints.auditEvent, 'custom/audit-events');
    expect(
      merged.api.endpoints.rbacTenantRoleMembership,
      'custom/tenants/{tenant_id}/role-memberships',
    );
    expect(
      merged.api.endpoints.auditEventTenant,
      defaults.api.endpoints.auditEventTenant,
    );
    expect(
      merged.api.endpoints.authDeleteUser,
      'custom/users/{user_id}/delete',
    );
    expect(
      mergedWithoutSuspendOverride.api.endpoints.tenantMembershipActionSuspend,
      defaults.api.endpoints.tenantMembershipActionSuspend,
    );
    expect(
      mergedWithoutSuspendOverride.api.endpoints.authDeleteUser,
      defaults.api.endpoints.authDeleteUser,
    );
    expect(
      mergedWithoutSuspendOverride.api.endpoints.rbacTenantRoleMembership,
      defaults.api.endpoints.rbacTenantRoleMembership,
    );
    expect(runtimeOverride.appName, isNull);
    expect(apiOverride.baseUrl, isNull);
  });

  test('default app definition owns built-in routes, settings, and roles', () {
    final definition = buildDefaultAppDefinition();
    final shellRouteIds = definition.shellRoutes
        .map((route) => route.id)
        .toSet();
    final settingsPanelIds = definition.settingsPanels
        .map((panel) => panel.id)
        .toSet();
    final topLevelRouteIds = definition.topLevelRoutes
        .map((route) => route.id)
        .toSet();

    expect(definition.defaultShellRouteId, RouteIds.chat);
    expect(shellRouteIds, contains(RouteIds.dashboard));
    expect(shellRouteIds, contains(RouteIds.chat));
    expect(shellRouteIds, contains(RouteIds.humanHandoff));
    expect(shellRouteIds, contains(RouteIds.localUsers));
    expect(shellRouteIds, contains(RouteIds.tenantManagement));
    expect(shellRouteIds, contains(RouteIds.rolePermissionManagement));
    expect(shellRouteIds, contains(RouteIds.auditManagement));
    expect(shellRouteIds, contains(RouteIds.runtimeControl));
    expect(shellRouteIds, contains(RouteIds.channelOrchestration));
    expect(shellRouteIds, contains(RouteIds.contextEngine));
    expect(shellRouteIds, contains(RouteIds.knowledgePacks));
    expect(shellRouteIds, contains(RouteIds.acpConsole));
    expect(
      definition.shellRoutes
          .firstWhere((route) => route.id == RouteIds.localUsers)
          .requiredRoles,
      <String>['com.vorsocomputing.mugen.acp:administrator'],
    );
    expect(
      definition.shellRoutes
          .firstWhere((route) => route.id == RouteIds.chat)
          .requiredRoles,
      <String>[webPlatformAccessRole],
    );
    expect(
      definition.shellRoutes
          .firstWhere((route) => route.id == RouteIds.dashboard)
          .requiredRoles,
      <String>[webPlatformAccessRole],
    );
    final shellRouteOrder = definition.shellRoutes
        .map((route) => route.id)
        .toList(growable: false);
    expect(
      shellRouteOrder.indexOf(RouteIds.humanHandoff),
      shellRouteOrder.indexOf(RouteIds.chat) + 1,
    );
    expect(
      shellRouteOrder.indexOf(RouteIds.knowledgePacks),
      shellRouteOrder.indexOf(RouteIds.contextEngine) + 1,
    );
    expect(
      shellRouteOrder.indexOf(RouteIds.acpConsole),
      shellRouteOrder.indexOf(RouteIds.knowledgePacks) + 1,
    );
    expect(
      definition.shellRoutes
          .firstWhere((route) => route.id == RouteIds.humanHandoff)
          .requiredRoles,
      <String>['com.vorsocomputing.mugen.human_handoff:operator'],
    );
    expect(
      definition.shellRoutes
          .firstWhere((route) => route.id == RouteIds.knowledgePacks)
          .requiredRoles,
      <String>[knowledgePackConfiguratorRole],
    );
    expect(settingsPanelIds, contains('core.auth.account'));
    expect(settingsPanelIds, contains('core.auth.reset_password'));
    expect(topLevelRouteIds, contains('core.shell.app'));
    expect(topLevelRouteIds, contains('core.auth.login'));
    expect(topLevelRouteIds, contains('core.tenant_invite.invite'));
  });

  test('app definition rejects duplicate module ids', () {
    expect(
      () => MugenUiAppDefinition(
        config: AppConfig.defaults(),
        defaultShellRouteId: RouteIds.chat,
        modules: <MugenUiModule>[
          _shellModule('duplicate', RouteIds.chat),
          _shellModule('duplicate', RouteIds.localUsers),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('app definition rejects duplicate shell route ids', () {
    expect(
      () => MugenUiAppDefinition(
        config: AppConfig.defaults(),
        defaultShellRouteId: RouteIds.chat,
        modules: <MugenUiModule>[
          _shellModule('one', RouteIds.chat),
          _shellModule('two', RouteIds.chat),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('app definition rejects duplicate settings panel ids', () {
    expect(
      () => MugenUiAppDefinition(
        config: AppConfig.defaults(),
        defaultShellRouteId: RouteIds.chat,
        modules: <MugenUiModule>[
          _shellModule('shell', RouteIds.chat),
          const MugenUiModule(
            id: 'settings.one',
            settingsPanels: <SettingsPanelDefinition>[
              SettingsPanelDefinition(
                id: 'duplicate',
                title: 'One',
                icon: Icons.settings,
                builder: _buildPlaceholderPage,
              ),
            ],
          ),
          const MugenUiModule(
            id: 'settings.two',
            settingsPanels: <SettingsPanelDefinition>[
              SettingsPanelDefinition(
                id: 'duplicate',
                title: 'Two',
                icon: Icons.settings_applications,
                builder: _buildPlaceholderPage,
              ),
            ],
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('app definition rejects duplicate exact top-level paths', () {
    expect(
      () => MugenUiAppDefinition(
        config: AppConfig.defaults(),
        defaultShellRouteId: RouteIds.chat,
        modules: <MugenUiModule>[
          _shellModule('shell', RouteIds.chat),
          MugenUiModule(
            id: 'routes.one',
            topLevelRoutes: <TopLevelRouteDefinition>[
              TopLevelRouteDefinition.exact(
                id: 'route.one',
                path: '/reports',
                builder: _buildPlaceholderPage,
              ),
            ],
          ),
          MugenUiModule(
            id: 'routes.two',
            topLevelRoutes: <TopLevelRouteDefinition>[
              TopLevelRouteDefinition.exact(
                id: 'route.two',
                path: '/reports',
                builder: _buildPlaceholderPage,
              ),
            ],
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('app definition rejects duplicate top-level route ids', () {
    expect(
      () => MugenUiAppDefinition(
        config: AppConfig.defaults(),
        defaultShellRouteId: RouteIds.chat,
        modules: <MugenUiModule>[
          _shellModule('shell', RouteIds.chat),
          MugenUiModule(
            id: 'routes.one',
            topLevelRoutes: <TopLevelRouteDefinition>[
              TopLevelRouteDefinition.exact(
                id: 'duplicate.route',
                path: '/one',
                builder: _buildPlaceholderPage,
              ),
            ],
          ),
          MugenUiModule(
            id: 'routes.two',
            topLevelRoutes: <TopLevelRouteDefinition>[
              TopLevelRouteDefinition.exact(
                id: 'duplicate.route',
                path: '/two',
                builder: _buildPlaceholderPage,
              ),
            ],
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('app definition rejects a missing default shell route', () {
    expect(
      () => MugenUiAppDefinition(
        config: AppConfig.defaults(),
        defaultShellRouteId: 'missing',
        modules: <MugenUiModule>[_shellModule('shell', RouteIds.chat)],
      ),
      throwsArgumentError,
    );
  });

  test('app definition provider overrides preserve module order', () {
    final labelProvider = Provider<String>((ref) => 'base');
    final definition = MugenUiAppDefinition(
      config: AppConfig.defaults(),
      defaultShellRouteId: RouteIds.chat,
      modules: <MugenUiModule>[
        MugenUiModule(
          id: 'shell',
          shellRoutes: <ShellRouteDefinition>[
            const ShellRouteDefinition(
              id: RouteIds.chat,
              title: 'AI Assist',
              icon: Icons.chat_bubble_outline,
              builder: _buildPlaceholderPage,
            ),
          ],
          providerOverrides: <Override>[
            labelProvider.overrideWithValue('first'),
          ],
        ),
        MugenUiModule(
          id: 'override',
          providerOverrides: <Override>[
            labelProvider.overrideWithValue('second'),
          ],
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: definition.providerOverrides,
    );
    addTearDown(container.dispose);

    expect(definition.providerOverrides, hasLength(2));
    expect(container.read(labelProvider), 'second');
  });

  testWidgets('default app definition route builders remain wired', (
    WidgetTester tester,
  ) async {
    final definition = buildDefaultAppDefinition();
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            context = ctx;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      definition.shellRoutes
          .firstWhere((route) => route.id == RouteIds.humanHandoff)
          .builder(context),
      isA<Padding>(),
    );
    expect(
      definition.shellRoutes
          .firstWhere((route) => route.id == RouteIds.tenantManagement)
          .builder(context),
      isA<Padding>(),
    );
    expect(
      definition.shellRoutes
          .firstWhere((route) => route.id == RouteIds.rolePermissionManagement)
          .builder(context),
      isA<Padding>(),
    );
    expect(
      definition.shellRoutes
          .firstWhere((route) => route.id == RouteIds.auditManagement)
          .builder(context),
      isA<Padding>(),
    );
    expect(
      definition.shellRoutes
          .firstWhere((route) => route.id == RouteIds.runtimeControl)
          .builder(context),
      isA<Padding>(),
    );
    expect(
      definition.shellRoutes
          .firstWhere((route) => route.id == RouteIds.channelOrchestration)
          .builder(context),
      isA<Padding>(),
    );
    expect(
      definition.shellRoutes
          .firstWhere((route) => route.id == RouteIds.contextEngine)
          .builder(context),
      isA<Padding>(),
    );
    expect(
      definition.shellRoutes
          .firstWhere((route) => route.id == RouteIds.knowledgePacks)
          .builder(context),
      isA<Padding>(),
    );
    expect(
      definition.shellRoutes
          .firstWhere((route) => route.id == RouteIds.acpConsole)
          .builder(context),
      isA<Padding>(),
    );

    final inviteRoute = definition.topLevelRoutes.firstWhere(
      (route) => route.id == 'core.tenant_invite.invite',
    );
    final inviteMatch = inviteRoute.match('/invite/t1/i1?token=abc');

    expect(inviteMatch, isNotNull);
    expect(inviteMatch?.location, '/invite/t1/i1');
    expect(inviteRoute.builder(context, inviteMatch!), isA<AuthGuard>());
  });
}

MugenUiModule _shellModule(String id, String routeId) {
  return MugenUiModule(
    id: id,
    shellRoutes: <ShellRouteDefinition>[
      ShellRouteDefinition(
        id: routeId,
        title: routeId,
        icon: Icons.dashboard_outlined,
        builder: _buildPlaceholderPage,
      ),
    ],
  );
}

Widget _buildPlaceholderPage(BuildContext context) {
  return const SizedBox.shrink();
}
