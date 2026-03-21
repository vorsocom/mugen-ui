import 'package:flutter/material.dart';

import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/definition/app_definition.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/acp_console/presentation/widgets/acp_console_panel.dart';
import 'package:mugen_ui/features/audit_admin/presentation/widgets/audit_management_panel.dart';
import 'package:mugen_ui/features/auth/presentation/pages/login_page.dart';
import 'package:mugen_ui/features/auth/presentation/widgets/auth_guard.dart';
import 'package:mugen_ui/features/auth/presentation/widgets/edit_profile_panel.dart';
import 'package:mugen_ui/features/auth/presentation/widgets/reset_password_panel.dart';
import 'package:mugen_ui/features/chat/presentation/pages/chat_page.dart';
import 'package:mugen_ui/features/context_admin/presentation/widgets/context_engine_panel.dart';
import 'package:mugen_ui/features/orchestration_admin/presentation/widgets/channel_orchestration_panel.dart';
import 'package:mugen_ui/features/rbac_admin/presentation/widgets/rbac_management_panel.dart';
import 'package:mugen_ui/features/runtime_admin/presentation/widgets/runtime_control_panel.dart';
import 'package:mugen_ui/features/shell/presentation/pages/shell_page.dart';
import 'package:mugen_ui/features/tenant_admin/presentation/widgets/tenant_management_panel.dart';
import 'package:mugen_ui/features/tenant_invite/presentation/pages/invite_redeem_page.dart';
import 'package:mugen_ui/features/user_admin/presentation/widgets/local_user_panel.dart';

MugenUiAppDefinition buildDefaultAppDefinition() {
  return MugenUiAppDefinition(
    config: AppConfig.defaults(),
    defaultShellRouteId: CoreShellRouteIds.chat,
    modules: <MugenUiModule>[
      _coreAuthModule,
      _coreShellModule,
      _coreLocalUsersModule,
      _coreTenantModule,
      _coreRbacModule,
      _coreAuditModule,
      _coreRuntimeModule,
      _coreChannelOrchestrationModule,
      _coreContextEngineModule,
      _coreAcpConsoleModule,
      _coreTenantInviteModule,
    ],
  );
}

final MugenUiModule _coreAuthModule = MugenUiModule(
  id: 'core.auth',
  topLevelRoutes: <TopLevelRouteDefinition>[
    TopLevelRouteDefinition.exact(
      id: 'core.auth.login',
      path: AppRoutePaths.login,
      builder: (_) => const AuthGuard(child: LoginPage()),
    ),
  ],
  settingsPanels: const <SettingsPanelDefinition>[
    SettingsPanelDefinition(
      id: 'core.auth.account',
      title: 'Edit Profile',
      icon: Icons.person_outline,
      requiredRoles: <String>['$acpNamespace:authenticated'],
      builder: _buildEditProfilePanel,
      maxWidth: 760,
      maxHeight: 640,
      showHeader: false,
      expandBody: false,
    ),
    SettingsPanelDefinition(
      id: 'core.auth.reset_password',
      title: 'Reset Password',
      icon: Icons.security,
      requiredRoles: <String>['$acpNamespace:authenticated'],
      builder: _buildResetPasswordPanel,
      maxWidth: 760,
      maxHeight: 620,
      showHeader: false,
      expandBody: false,
    ),
  ],
);

final MugenUiModule _coreShellModule = MugenUiModule(
  id: 'core.shell',
  topLevelRoutes: <TopLevelRouteDefinition>[
    TopLevelRouteDefinition.exact(
      id: 'core.shell.app',
      path: AppRoutePaths.app,
      builder: (_) => const AuthGuard(child: ShellPage()),
    ),
  ],
  shellRoutes: const <ShellRouteDefinition>[
    ShellRouteDefinition(
      id: CoreShellRouteIds.dashboard,
      title: 'Dashboard',
      icon: Icons.home_outlined,
      builder: _buildChatPage,
      showInDrawer: false,
    ),
    ShellRouteDefinition(
      id: CoreShellRouteIds.chat,
      title: 'AI Assist',
      icon: Icons.chat_bubble_outline,
      builder: _buildChatPage,
    ),
  ],
);

final MugenUiModule _coreLocalUsersModule = MugenUiModule(
  id: 'core.local_users',
  shellRoutes: const <ShellRouteDefinition>[
    ShellRouteDefinition(
      id: CoreShellRouteIds.localUsers,
      title: 'LocalUsers',
      icon: Icons.groups_outlined,
      section: 'Platform Configuration',
      requiredRoles: <String>['$acpNamespace:administrator'],
      builder: _buildLocalUsersRoute,
    ),
  ],
);

final MugenUiModule _coreTenantModule = MugenUiModule(
  id: 'core.tenants',
  shellRoutes: const <ShellRouteDefinition>[
    ShellRouteDefinition(
      id: CoreShellRouteIds.tenantManagement,
      title: 'Tenants',
      icon: Icons.apartment_outlined,
      section: 'Platform Configuration',
      requiredRoles: <String>['$acpNamespace:administrator'],
      builder: _buildTenantManagementRoute,
    ),
  ],
);

final MugenUiModule _coreRbacModule = MugenUiModule(
  id: 'core.rbac',
  shellRoutes: const <ShellRouteDefinition>[
    ShellRouteDefinition(
      id: CoreShellRouteIds.rolePermissionManagement,
      title: 'Roles & Permissions',
      icon: Icons.admin_panel_settings_outlined,
      section: 'Platform Configuration',
      requiredRoles: <String>['$acpNamespace:administrator'],
      builder: _buildRbacManagementRoute,
    ),
  ],
);

final MugenUiModule _coreAuditModule = MugenUiModule(
  id: 'core.audit',
  shellRoutes: const <ShellRouteDefinition>[
    ShellRouteDefinition(
      id: CoreShellRouteIds.auditManagement,
      title: 'Audit Events',
      icon: Icons.fact_check_outlined,
      section: 'Platform Configuration',
      requiredRoles: <String>['$acpNamespace:administrator'],
      builder: _buildAuditManagementRoute,
    ),
  ],
);

final MugenUiModule _coreRuntimeModule = MugenUiModule(
  id: 'core.runtime',
  shellRoutes: const <ShellRouteDefinition>[
    ShellRouteDefinition(
      id: CoreShellRouteIds.runtimeControl,
      title: 'Runtime Control',
      icon: Icons.settings_input_component_outlined,
      section: 'Platform Configuration',
      requiredRoles: <String>['$acpNamespace:administrator'],
      builder: _buildRuntimeControlRoute,
    ),
  ],
);

final MugenUiModule _coreChannelOrchestrationModule = MugenUiModule(
  id: 'core.channel_orchestration',
  shellRoutes: const <ShellRouteDefinition>[
    ShellRouteDefinition(
      id: CoreShellRouteIds.channelOrchestration,
      title: 'Channel Orchestration',
      icon: Icons.alt_route_outlined,
      section: 'Platform Configuration',
      requiredRoles: <String>['$acpNamespace:administrator'],
      builder: _buildChannelOrchestrationRoute,
    ),
  ],
);

final MugenUiModule _coreContextEngineModule = MugenUiModule(
  id: 'core.context_engine',
  shellRoutes: const <ShellRouteDefinition>[
    ShellRouteDefinition(
      id: CoreShellRouteIds.contextEngine,
      title: 'Context Engine',
      icon: Icons.hub_outlined,
      section: 'Platform Configuration',
      requiredRoles: <String>['$acpNamespace:administrator'],
      builder: _buildContextEngineRoute,
    ),
  ],
);

final MugenUiModule _coreAcpConsoleModule = MugenUiModule(
  id: 'core.acp_console',
  shellRoutes: const <ShellRouteDefinition>[
    ShellRouteDefinition(
      id: CoreShellRouteIds.acpConsole,
      title: 'ACP Console',
      icon: Icons.data_object_outlined,
      section: 'Platform Configuration',
      requiredRoles: <String>['$acpNamespace:administrator'],
      builder: _buildAcpConsoleRoute,
    ),
  ],
);

final MugenUiModule _coreTenantInviteModule = MugenUiModule(
  id: 'core.tenant_invite',
  topLevelRoutes: <TopLevelRouteDefinition>[
    TopLevelRouteDefinition.parsed<InviteRouteMatch>(
      id: 'core.tenant_invite.invite',
      parse: AppRoutePaths.parseInviteRoute,
      canonicalLocation: (inviteRoute) => AppRoutePaths.buildInviteRoute(
        tenantId: inviteRoute.tenantId,
        invitationId: inviteRoute.invitationId,
      ),
      builder: (_, inviteRoute) =>
          AuthGuard(child: InviteRedeemPage(inviteRoute: inviteRoute)),
    ),
  ],
);

Widget _buildEditProfilePanel(BuildContext context) => const EditProfilePanel();

Widget _buildResetPasswordPanel(BuildContext context) =>
    const ResetPasswordPanel();

Widget _buildChatPage(BuildContext context) => const ChatPage();

Widget _buildLocalUsersRoute(BuildContext context) =>
    const Padding(padding: EdgeInsets.all(16), child: LocalUserPanel());

Widget _buildTenantManagementRoute(BuildContext context) =>
    const Padding(padding: EdgeInsets.all(16), child: TenantManagementPanel());

Widget _buildRbacManagementRoute(BuildContext context) =>
    const Padding(padding: EdgeInsets.all(16), child: RbacManagementPanel());

Widget _buildAuditManagementRoute(BuildContext context) =>
    const Padding(padding: EdgeInsets.all(16), child: AuditManagementPanel());

Widget _buildRuntimeControlRoute(BuildContext context) =>
    const Padding(padding: EdgeInsets.all(16), child: RuntimeControlPanel());

Widget _buildChannelOrchestrationRoute(BuildContext context) => const Padding(
  padding: EdgeInsets.all(16),
  child: ChannelOrchestrationPanel(),
);

Widget _buildContextEngineRoute(BuildContext context) =>
    const Padding(padding: EdgeInsets.all(16), child: ContextEnginePanel());

Widget _buildAcpConsoleRoute(BuildContext context) =>
    const Padding(padding: EdgeInsets.all(16), child: AcpConsolePanel());
