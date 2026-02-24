import 'package:flutter/material.dart';

import 'package:mugen_ui/app/routing/route_ids.dart';

const String acpNamespace = 'com.vorsocomputing.mugen.acp';

class ApiEndpointsConfig {
  const ApiEndpointsConfig({
    required this.authTenantInvitationRedeem,
    required this.authDisableUser,
    required this.authEnableUser,
    required this.authJwks,
    required this.authLogin,
    required this.authLogout,
    required this.authProvisionUser,
    required this.authRefresh,
    required this.authResetPassword,
    required this.authResetPasswordAdmin,
    required this.authUpdateProfile,
    required this.authUpdateRolesAdmin,
    required this.tenant,
    required this.tenantActionDeactivate,
    required this.tenantActionReactivate,
    required this.tenantDomain,
    required this.tenantInvitation,
    required this.tenantInvitationActionResend,
    required this.tenantInvitationActionRevoke,
    required this.tenantMembership,
    required this.tenantMembershipActionRemove,
    required this.tenantMembershipActionSuspend,
    required this.tenantMembershipActionUnsuspend,
    required this.user,
    required this.userRole,
    required this.rbacGlobalRole,
    required this.rbacTenantRole,
    required this.rbacTenantRoleActionDeprecate,
    required this.rbacTenantRoleActionReactivate,
    required this.rbacPermissionObject,
    required this.rbacPermissionObjectActionDeprecate,
    required this.rbacPermissionObjectActionReactivate,
    required this.rbacPermissionType,
    required this.rbacPermissionTypeActionDeprecate,
    required this.rbacPermissionTypeActionReactivate,
    required this.rbacGlobalPermissionEntry,
    required this.rbacTenantPermissionEntry,
    required this.webMessages,
    required this.webEvents,
    required this.webMediaBase,
  });

  final String authTenantInvitationRedeem;
  final String authDisableUser;
  final String authEnableUser;
  final String authJwks;
  final String authLogin;
  final String authLogout;
  final String authProvisionUser;
  final String authRefresh;
  final String authResetPassword;
  final String authResetPasswordAdmin;
  final String authUpdateProfile;
  final String authUpdateRolesAdmin;
  final String tenant;
  final String tenantActionDeactivate;
  final String tenantActionReactivate;
  final String tenantDomain;
  final String tenantInvitation;
  final String tenantInvitationActionResend;
  final String tenantInvitationActionRevoke;
  final String tenantMembership;
  final String tenantMembershipActionRemove;
  final String tenantMembershipActionSuspend;
  final String tenantMembershipActionUnsuspend;
  final String user;
  final String userRole;
  final String rbacGlobalRole;
  final String rbacTenantRole;
  final String rbacTenantRoleActionDeprecate;
  final String rbacTenantRoleActionReactivate;
  final String rbacPermissionObject;
  final String rbacPermissionObjectActionDeprecate;
  final String rbacPermissionObjectActionReactivate;
  final String rbacPermissionType;
  final String rbacPermissionTypeActionDeprecate;
  final String rbacPermissionTypeActionReactivate;
  final String rbacGlobalPermissionEntry;
  final String rbacTenantPermissionEntry;
  final String webMessages;
  final String webEvents;
  final String webMediaBase;

  ApiEndpointsConfig merge(ApiEndpointsOverride? override) {
    if (override == null) {
      return this;
    }

    return ApiEndpointsConfig(
      authTenantInvitationRedeem:
          override.authTenantInvitationRedeem ?? authTenantInvitationRedeem,
      authDisableUser: override.authDisableUser ?? authDisableUser,
      authEnableUser: override.authEnableUser ?? authEnableUser,
      authJwks: override.authJwks ?? authJwks,
      authLogin: override.authLogin ?? authLogin,
      authLogout: override.authLogout ?? authLogout,
      authProvisionUser: override.authProvisionUser ?? authProvisionUser,
      authRefresh: override.authRefresh ?? authRefresh,
      authResetPassword: override.authResetPassword ?? authResetPassword,
      authResetPasswordAdmin:
          override.authResetPasswordAdmin ?? authResetPasswordAdmin,
      authUpdateProfile: override.authUpdateProfile ?? authUpdateProfile,
      authUpdateRolesAdmin:
          override.authUpdateRolesAdmin ?? authUpdateRolesAdmin,
      tenant: override.tenant ?? tenant,
      tenantActionDeactivate:
          override.tenantActionDeactivate ?? tenantActionDeactivate,
      tenantActionReactivate:
          override.tenantActionReactivate ?? tenantActionReactivate,
      tenantDomain: override.tenantDomain ?? tenantDomain,
      tenantInvitation: override.tenantInvitation ?? tenantInvitation,
      tenantInvitationActionResend:
          override.tenantInvitationActionResend ?? tenantInvitationActionResend,
      tenantInvitationActionRevoke:
          override.tenantInvitationActionRevoke ?? tenantInvitationActionRevoke,
      tenantMembership: override.tenantMembership ?? tenantMembership,
      tenantMembershipActionRemove:
          override.tenantMembershipActionRemove ?? tenantMembershipActionRemove,
      tenantMembershipActionSuspend:
          override.tenantMembershipActionSuspend ??
          tenantMembershipActionSuspend,
      tenantMembershipActionUnsuspend:
          override.tenantMembershipActionUnsuspend ??
          tenantMembershipActionUnsuspend,
      user: override.user ?? user,
      userRole: override.userRole ?? userRole,
      rbacGlobalRole: override.rbacGlobalRole ?? rbacGlobalRole,
      rbacTenantRole: override.rbacTenantRole ?? rbacTenantRole,
      rbacTenantRoleActionDeprecate:
          override.rbacTenantRoleActionDeprecate ??
          rbacTenantRoleActionDeprecate,
      rbacTenantRoleActionReactivate:
          override.rbacTenantRoleActionReactivate ??
          rbacTenantRoleActionReactivate,
      rbacPermissionObject:
          override.rbacPermissionObject ?? rbacPermissionObject,
      rbacPermissionObjectActionDeprecate:
          override.rbacPermissionObjectActionDeprecate ??
          rbacPermissionObjectActionDeprecate,
      rbacPermissionObjectActionReactivate:
          override.rbacPermissionObjectActionReactivate ??
          rbacPermissionObjectActionReactivate,
      rbacPermissionType: override.rbacPermissionType ?? rbacPermissionType,
      rbacPermissionTypeActionDeprecate:
          override.rbacPermissionTypeActionDeprecate ??
          rbacPermissionTypeActionDeprecate,
      rbacPermissionTypeActionReactivate:
          override.rbacPermissionTypeActionReactivate ??
          rbacPermissionTypeActionReactivate,
      rbacGlobalPermissionEntry:
          override.rbacGlobalPermissionEntry ?? rbacGlobalPermissionEntry,
      rbacTenantPermissionEntry:
          override.rbacTenantPermissionEntry ?? rbacTenantPermissionEntry,
      webMessages: override.webMessages ?? webMessages,
      webEvents: override.webEvents ?? webEvents,
      webMediaBase: override.webMediaBase ?? webMediaBase,
    );
  }
}

class ApiEndpointsOverride {
  const ApiEndpointsOverride({
    this.authTenantInvitationRedeem,
    this.authDisableUser,
    this.authEnableUser,
    this.authJwks,
    this.authLogin,
    this.authLogout,
    this.authProvisionUser,
    this.authRefresh,
    this.authResetPassword,
    this.authResetPasswordAdmin,
    this.authUpdateProfile,
    this.authUpdateRolesAdmin,
    this.tenant,
    this.tenantActionDeactivate,
    this.tenantActionReactivate,
    this.tenantDomain,
    this.tenantInvitation,
    this.tenantInvitationActionResend,
    this.tenantInvitationActionRevoke,
    this.tenantMembership,
    this.tenantMembershipActionRemove,
    this.tenantMembershipActionSuspend,
    this.tenantMembershipActionUnsuspend,
    this.user,
    this.userRole,
    this.rbacGlobalRole,
    this.rbacTenantRole,
    this.rbacTenantRoleActionDeprecate,
    this.rbacTenantRoleActionReactivate,
    this.rbacPermissionObject,
    this.rbacPermissionObjectActionDeprecate,
    this.rbacPermissionObjectActionReactivate,
    this.rbacPermissionType,
    this.rbacPermissionTypeActionDeprecate,
    this.rbacPermissionTypeActionReactivate,
    this.rbacGlobalPermissionEntry,
    this.rbacTenantPermissionEntry,
    this.webMessages,
    this.webEvents,
    this.webMediaBase,
  });

  final String? authTenantInvitationRedeem;
  final String? authDisableUser;
  final String? authEnableUser;
  final String? authJwks;
  final String? authLogin;
  final String? authLogout;
  final String? authProvisionUser;
  final String? authRefresh;
  final String? authResetPassword;
  final String? authResetPasswordAdmin;
  final String? authUpdateProfile;
  final String? authUpdateRolesAdmin;
  final String? tenant;
  final String? tenantActionDeactivate;
  final String? tenantActionReactivate;
  final String? tenantDomain;
  final String? tenantInvitation;
  final String? tenantInvitationActionResend;
  final String? tenantInvitationActionRevoke;
  final String? tenantMembership;
  final String? tenantMembershipActionRemove;
  final String? tenantMembershipActionSuspend;
  final String? tenantMembershipActionUnsuspend;
  final String? user;
  final String? userRole;
  final String? rbacGlobalRole;
  final String? rbacTenantRole;
  final String? rbacTenantRoleActionDeprecate;
  final String? rbacTenantRoleActionReactivate;
  final String? rbacPermissionObject;
  final String? rbacPermissionObjectActionDeprecate;
  final String? rbacPermissionObjectActionReactivate;
  final String? rbacPermissionType;
  final String? rbacPermissionTypeActionDeprecate;
  final String? rbacPermissionTypeActionReactivate;
  final String? rbacGlobalPermissionEntry;
  final String? rbacTenantPermissionEntry;
  final String? webMessages;
  final String? webEvents;
  final String? webMediaBase;
}

class ApiConfig {
  const ApiConfig({required this.baseUrl, required this.endpoints});

  final String baseUrl;
  final ApiEndpointsConfig endpoints;

  ApiConfig merge(ApiConfigOverride? override) {
    if (override == null) {
      return this;
    }

    return ApiConfig(
      baseUrl: override.baseUrl ?? baseUrl,
      endpoints: endpoints.merge(override.endpoints),
    );
  }
}

class ApiConfigOverride {
  const ApiConfigOverride({
    // coverage:ignore-line
    this.baseUrl,
    this.endpoints,
  }); // coverage:ignore-line

  final String? baseUrl;
  final ApiEndpointsOverride? endpoints;
}

class AppRoleConfig {
  const AppRoleConfig({required this.name, required this.displayName});

  final String name;
  final String displayName;
}

class DrawerItemConfig {
  const DrawerItemConfig({
    required this.title,
    required this.icon,
    required this.route,
    this.section,
    this.roles = const <String>[],
  });

  final String title;
  final IconData icon;
  final String route;
  final String? section;
  final List<String> roles;
}

enum SettingsPanelType { account, users }

class SettingsPanelConfig {
  const SettingsPanelConfig({
    required this.title,
    required this.icon,
    required this.roles,
    required this.type,
  });

  final String title;
  final IconData icon;
  final List<String> roles;
  final SettingsPanelType type;
}

class SpaRouteConfig {
  const SpaRouteConfig({required this.id, required this.title});

  final String id;
  final String title;
}

class AppConfig {
  const AppConfig({
    required this.appName,
    required this.appVersion,
    required this.api,
    required this.activeRoles,
    required this.drawerItems,
    required this.settingsPanels,
    required this.spaDefaultRoute,
    required this.spaRoutes,
  });

  final String appName;
  final String appVersion;
  final ApiConfig api;
  final List<AppRoleConfig> activeRoles;
  final List<DrawerItemConfig> drawerItems;
  final List<SettingsPanelConfig> settingsPanels;
  final String spaDefaultRoute;
  final List<SpaRouteConfig> spaRoutes;

  factory AppConfig.defaults() {
    return AppConfig(
      appName: 'muGen UI',
      appVersion: '0.1',
      api: const ApiConfig(
        baseUrl: 'https://localdev.vorsocomputing.com:8081/api',
        endpoints: ApiEndpointsConfig(
          authTenantInvitationRedeem:
              'core/acp/v1/auth/tenants/{tenant_id}/invitations/{invitation_id}/redeem',
          authDisableUser: 'core/acp/v1/Users/{user_id}/\$action/lock',
          authEnableUser: 'core/acp/v1/Users/{user_id}/\$action/unlock',
          authJwks: 'core/acp/v1/auth/.well-known/jwks.json',
          authLogin: 'core/acp/v1/auth/login',
          authLogout: 'core/acp/v1/auth/logout',
          authProvisionUser: 'core/acp/v1/Users/\$action/provision',
          authRefresh: 'core/acp/v1/auth/refresh',
          authResetPassword:
              'core/acp/v1/Users/{user_id}/\$action/resetpassworduser',
          authResetPasswordAdmin:
              'core/acp/v1/Users/{user_id}/\$action/resetpasswordadmin',
          authUpdateProfile:
              'core/acp/v1/Users/{user_id}/\$action/updateprofile',
          authUpdateRolesAdmin:
              'core/acp/v1/Users/{user_id}/\$action/updateroles',
          tenant: 'core/acp/v1/Tenants',
          tenantActionDeactivate:
              'core/acp/v1/Tenants/{tenant_id}/\$action/deactivate',
          tenantActionReactivate:
              'core/acp/v1/Tenants/{tenant_id}/\$action/reactivate',
          tenantDomain: 'core/acp/v1/tenants/{tenant_id}/TenantDomains',
          tenantInvitation: 'core/acp/v1/tenants/{tenant_id}/TenantInvitations',
          tenantInvitationActionResend:
              'core/acp/v1/tenants/{tenant_id}/TenantInvitations/{invitation_id}/\$action/resend',
          tenantInvitationActionRevoke:
              'core/acp/v1/tenants/{tenant_id}/TenantInvitations/{invitation_id}/\$action/revoke',
          tenantMembership: 'core/acp/v1/tenants/{tenant_id}/TenantMemberships',
          tenantMembershipActionRemove:
              'core/acp/v1/tenants/{tenant_id}/TenantMemberships/{membership_id}/\$action/remove',
          tenantMembershipActionSuspend:
              'core/acp/v1/tenants/{tenant_id}/TenantMemberships/{membership_id}/\$action/suspend',
          tenantMembershipActionUnsuspend:
              'core/acp/v1/tenants/{tenant_id}/TenantMemberships/{membership_id}/\$action/unsuspend',
          user: 'core/acp/v1/Users',
          userRole: 'core/acp/v1/GlobalRoles',
          rbacGlobalRole: 'core/acp/v1/GlobalRoles',
          rbacTenantRole: 'core/acp/v1/tenants/{tenant_id}/Roles',
          rbacTenantRoleActionDeprecate:
              'core/acp/v1/tenants/{tenant_id}/Roles/{role_id}/\$action/deprecate',
          rbacTenantRoleActionReactivate:
              'core/acp/v1/tenants/{tenant_id}/Roles/{role_id}/\$action/reactivate',
          rbacPermissionObject: 'core/acp/v1/PermissionObjects',
          rbacPermissionObjectActionDeprecate:
              'core/acp/v1/PermissionObjects/{permission_object_id}/\$action/deprecate',
          rbacPermissionObjectActionReactivate:
              'core/acp/v1/PermissionObjects/{permission_object_id}/\$action/reactivate',
          rbacPermissionType: 'core/acp/v1/PermissionTypes',
          rbacPermissionTypeActionDeprecate:
              'core/acp/v1/PermissionTypes/{permission_type_id}/\$action/deprecate',
          rbacPermissionTypeActionReactivate:
              'core/acp/v1/PermissionTypes/{permission_type_id}/\$action/reactivate',
          rbacGlobalPermissionEntry: 'core/acp/v1/GlobalPermissionEntries',
          rbacTenantPermissionEntry:
              'core/acp/v1/tenants/{tenant_id}/PermissionEntries',
          webMessages: 'core/web/v1/messages',
          webEvents: 'core/web/v1/events',
          webMediaBase: 'core/web/v1/media',
        ),
      ),
      activeRoles: const <AppRoleConfig>[
        AppRoleConfig(
          name: '$acpNamespace:administrator',
          displayName: 'Administrator',
        ),
        AppRoleConfig(
          name: '$acpNamespace:authenticated',
          displayName: 'Authenticated',
        ),
      ],
      drawerItems: const <DrawerItemConfig>[
        DrawerItemConfig(
          title: 'AI Assist',
          icon: Icons.chat_bubble_outline,
          route: RouteIds.chat,
        ),
        DrawerItemConfig(
          title: 'Local Users',
          icon: Icons.groups_outlined,
          route: RouteIds.localUsers,
          section: 'Platform Configuration',
          roles: <String>['$acpNamespace:administrator'],
        ),
        DrawerItemConfig(
          title: 'Tenant Management',
          icon: Icons.apartment_outlined,
          route: RouteIds.tenantManagement,
          section: 'Platform Configuration',
          roles: <String>['$acpNamespace:administrator'],
        ),
        DrawerItemConfig(
          title: 'Role & Permission Management',
          icon: Icons.admin_panel_settings_outlined,
          route: RouteIds.rolePermissionManagement,
          section: 'Platform Configuration',
          roles: <String>['$acpNamespace:administrator'],
        ),
      ],
      settingsPanels: const <SettingsPanelConfig>[
        SettingsPanelConfig(
          title: 'Reset Password',
          icon: Icons.security,
          roles: <String>['$acpNamespace:authenticated'],
          type: SettingsPanelType.account,
        ),
      ],
      spaDefaultRoute: RouteIds.chat,
      spaRoutes: const <SpaRouteConfig>[
        SpaRouteConfig(id: RouteIds.chat, title: 'AI Assist'),
        SpaRouteConfig(id: RouteIds.localUsers, title: 'Local Users'),
        SpaRouteConfig(
          id: RouteIds.tenantManagement,
          title: 'Tenant Management',
        ),
        SpaRouteConfig(
          id: RouteIds.rolePermissionManagement,
          title: 'Role & Permission Management',
        ),
      ],
    );
  }

  AppConfig merge(AppConfigurationOverride override) {
    return AppConfig(
      appName: override.appName ?? appName,
      appVersion: override.appVersion ?? appVersion,
      api: api.merge(override.api),
      activeRoles: override.activeRoles ?? activeRoles,
      drawerItems: override.drawerItems ?? drawerItems,
      settingsPanels: override.settingsPanels ?? settingsPanels,
      spaDefaultRoute: override.spaDefaultRoute ?? spaDefaultRoute,
      spaRoutes: override.spaRoutes ?? spaRoutes,
    );
  }
}

class AppConfigurationOverride {
  const AppConfigurationOverride({
    this.appName,
    this.appVersion,
    this.api,
    this.activeRoles,
    this.drawerItems,
    this.settingsPanels,
    this.spaDefaultRoute,
    this.spaRoutes,
  });

  final String? appName;
  final String? appVersion;
  final ApiConfigOverride? api;
  final List<AppRoleConfig>? activeRoles;
  final List<DrawerItemConfig>? drawerItems;
  final List<SettingsPanelConfig>? settingsPanels;
  final String? spaDefaultRoute;
  final List<SpaRouteConfig>? spaRoutes;
}
