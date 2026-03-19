import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';

void main() {
  test('AppConfig.merge overrides only provided fields', () {
    final runtimeOverride = AppConfigurationOverride();
    final defaults = AppConfig.defaults();

    final merged = defaults.merge(
      const AppConfigurationOverride(
        appName: 'Custom Name',
        api: ApiConfigOverride(
          endpoints: ApiEndpointsOverride(
            acpBase: 'custom/acp/v2',
            webMessages: 'custom/messages',
            authDeleteUser: 'custom/users/{user_id}/delete',
            tenantMembershipActionSuspend:
                'custom/tenants/{tenant_id}/memberships/{membership_id}/suspend',
            auditEvent: 'custom/audit-events',
          ),
        ),
        drawerItems: <DrawerItemConfig>[
          DrawerItemConfig(
            title: 'Only Item',
            icon: Icons.home,
            route: RouteIds.chat,
          ),
        ],
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
    expect(merged.drawerItems.length, 1);
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
    expect(defaults.spaDefaultRoute, RouteIds.chat);
    expect(
      defaults.drawerItems.any((item) => item.route == RouteIds.dashboard),
      isFalse,
    );
    expect(
      defaults.drawerItems.any((item) => item.route == RouteIds.chat),
      isTrue,
    );
    expect(
      defaults.drawerItems.any((item) => item.route == RouteIds.localUsers),
      isTrue,
    );
    expect(
      defaults.drawerItems.any(
        (item) => item.route == RouteIds.tenantManagement,
      ),
      isTrue,
    );
    expect(
      defaults.drawerItems.any(
        (item) => item.route == RouteIds.rolePermissionManagement,
      ),
      isTrue,
    );
    expect(
      defaults.drawerItems.any(
        (item) => item.route == RouteIds.auditManagement,
      ),
      isTrue,
    );
    expect(
      defaults.drawerItems.any((item) => item.route == RouteIds.runtimeControl),
      isTrue,
    );
    expect(
      defaults.drawerItems.any(
        (item) => item.route == RouteIds.channelOrchestration,
      ),
      isTrue,
    );
    expect(
      defaults.drawerItems.any((item) => item.route == RouteIds.contextEngine),
      isTrue,
    );
    expect(
      defaults.drawerItems.any((item) => item.route == RouteIds.acpConsole),
      isTrue,
    );
    expect(
      defaults.settingsPanels.any(
        (panel) => panel.type == SettingsPanelType.account,
      ),
      isTrue,
    );
    expect(
      defaults.settingsPanels.any(
        (panel) => panel.type == SettingsPanelType.resetPassword,
      ),
      isTrue,
    );
    expect(
      defaults.settingsPanels.any(
        (panel) => panel.type == SettingsPanelType.users,
      ),
      isFalse,
    );
    expect(
      defaults.spaRoutes.any((route) => route.id == RouteIds.dashboard),
      isFalse,
    );
    expect(
      defaults.spaRoutes.any((route) => route.id == RouteIds.chat),
      isTrue,
    );
    expect(
      defaults.spaRoutes.any((route) => route.id == RouteIds.localUsers),
      isTrue,
    );
    expect(
      defaults.spaRoutes.any((route) => route.id == RouteIds.tenantManagement),
      isTrue,
    );
    expect(
      defaults.spaRoutes.any(
        (route) => route.id == RouteIds.rolePermissionManagement,
      ),
      isTrue,
    );
    expect(
      defaults.spaRoutes.any((route) => route.id == RouteIds.auditManagement),
      isTrue,
    );
    expect(
      defaults.spaRoutes.any((route) => route.id == RouteIds.runtimeControl),
      isTrue,
    );
    expect(
      defaults.spaRoutes.any(
        (route) => route.id == RouteIds.channelOrchestration,
      ),
      isTrue,
    );
    expect(
      defaults.spaRoutes.any((route) => route.id == RouteIds.contextEngine),
      isTrue,
    );
    expect(
      defaults.spaRoutes.any((route) => route.id == RouteIds.acpConsole),
      isTrue,
    );
    expect(
      defaults.spaRoutes
          .firstWhere((route) => route.id == RouteIds.localUsers)
          .roles,
      <String>['com.vorsocomputing.mugen.acp:administrator'],
    );
    expect(
      defaults.spaRoutes.firstWhere((route) => route.id == RouteIds.chat).roles,
      isEmpty,
    );
    expect(runtimeOverride.appName, isNull);
  });

  test('ApiConfigOverride can be instantiated at runtime', () {
    final override = ApiConfigOverride(
      baseUrl: 'https://example.com/api',
      endpoints: const ApiEndpointsOverride(webMessages: 'runtime/messages'),
    );

    expect(override.baseUrl, 'https://example.com/api');
    expect(override.endpoints, isNotNull);
    expect(override.endpoints!.webMessages, 'runtime/messages');
  });
}
