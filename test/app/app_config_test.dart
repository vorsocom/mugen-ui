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
            webMessages: 'custom/messages',
            tenantMembershipActionSuspend:
                'custom/tenants/{tenant_id}/memberships/{membership_id}/suspend',
          ),
        ),
        drawerItems: <DrawerItemConfig>[
          DrawerItemConfig(
            title: 'Only Item',
            icon: Icons.home,
            route: 'dashboard',
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
    expect(merged.api.endpoints.webMessages, 'custom/messages');
    expect(defaults.api.endpoints.webMessages, 'core/web/v1/messages');
    expect(defaults.api.endpoints.webEvents, 'core/web/v1/events');
    expect(defaults.api.endpoints.webMediaBase, 'core/web/v1/media');
    expect(
      defaults.api.endpoints.authTenantInvitationRedeem,
      'core/acp/v1/auth/tenants/{tenant_id}/invitations/{invitation_id}/redeem',
    );
    expect(defaults.api.endpoints.tenant, 'core/acp/v1/Tenants');
    expect(
      defaults.api.endpoints.tenantMembershipActionSuspend,
      'core/acp/v1/Tenants/{tenant_id}/TenantMemberships/{membership_id}/\$action/suspend',
    );
    expect(
      merged.api.endpoints.tenantMembershipActionSuspend,
      'custom/tenants/{tenant_id}/memberships/{membership_id}/suspend',
    );
    expect(
      mergedWithoutSuspendOverride.api.endpoints.tenantMembershipActionSuspend,
      defaults.api.endpoints.tenantMembershipActionSuspend,
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
    expect(runtimeOverride.appName, isNull);
  });
}
