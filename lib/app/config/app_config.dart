import 'package:flutter/material.dart';

import 'package:mugen_ui/app/routing/route_ids.dart';

const String acpNamespace = 'com.vorsocomputing.mugen.acp';

class ApiEndpointsConfig {
  const ApiEndpointsConfig({
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
    required this.user,
    required this.userRole,
    required this.webMessages,
    required this.webEvents,
    required this.webMediaBase,
  });

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
  final String user;
  final String userRole;
  final String webMessages;
  final String webEvents;
  final String webMediaBase;

  ApiEndpointsConfig merge(ApiEndpointsOverride? override) {
    if (override == null) {
      return this;
    }

    return ApiEndpointsConfig(
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
      user: override.user ?? user,
      userRole: override.userRole ?? userRole,
      webMessages: override.webMessages ?? webMessages,
      webEvents: override.webEvents ?? webEvents,
      webMediaBase: override.webMediaBase ?? webMediaBase,
    );
  }
}

class ApiEndpointsOverride {
  const ApiEndpointsOverride({
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
    this.user,
    this.userRole,
    this.webMessages,
    this.webEvents,
    this.webMediaBase,
  });

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
  final String? user;
  final String? userRole;
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
  const ApiConfigOverride({this.baseUrl, this.endpoints}); // coverage:ignore-line

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
          user: 'core/acp/v1/Users',
          userRole: 'core/acp/v1/GlobalRoles',
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
