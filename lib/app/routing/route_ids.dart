class InviteRouteMatch {
  const InviteRouteMatch({
    required this.tenantId,
    required this.invitationId,
    this.token,
  });

  final String tenantId;
  final String invitationId;
  final String? token;

  bool get hasToken => token != null && token!.isNotEmpty;
}

abstract class AppRoutePaths {
  static const String app = '/app';
  static const String login = '/login';
  static const String invitePrefix = '/invite';

  static String buildInviteRoute({
    required String tenantId,
    required String invitationId,
    String? token,
  }) {
    final basePath = '$invitePrefix/$tenantId/$invitationId';
    final trimmedToken = token?.trim();
    if (trimmedToken == null || trimmedToken.isEmpty) {
      return basePath;
    }

    final encoded = Uri.encodeQueryComponent(trimmedToken);
    return '$basePath?token=$encoded';
  }

  static InviteRouteMatch? parseInviteRoute(String? routeName) {
    final rawRoute = routeName?.trim();
    if (rawRoute == null || rawRoute.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(rawRoute);
    if (uri == null) {
      return null;
    }

    final segments = uri.pathSegments;
    if (segments.length != 3 || segments.first != 'invite') {
      return null;
    }

    final tenantId = segments[1].trim();
    final invitationId = segments[2].trim();
    if (tenantId.isEmpty || invitationId.isEmpty) {
      return null;
    }

    final token = uri.queryParameters['token']?.trim();
    return InviteRouteMatch(
      tenantId: tenantId,
      invitationId: invitationId,
      token: token == null || token.isEmpty ? null : token,
    );
  }
}

abstract class CoreShellRouteIds {
  static const String dashboard = 'dashboard';
  static const String chat = 'chat';
  static const String humanHandoff = 'human-handoff';
  static const String localUsers = 'local-users';
  static const String tenantManagement = 'tenant-management';
  static const String rolePermissionManagement = 'role-permission-management';
  static const String auditManagement = 'audit-management';
  static const String runtimeControl = 'runtime-control';
  static const String channelOrchestration = 'channel-orchestration';
  static const String contextEngine = 'context-engine';
  static const String knowledgePacks = 'knowledge-packs';
  static const String acpConsole = 'acp-console';
}

abstract class RouteIds {
  static const String app = AppRoutePaths.app;
  static const String login = AppRoutePaths.login;
  static const String invitePrefix = AppRoutePaths.invitePrefix;

  static const String dashboard = CoreShellRouteIds.dashboard;
  static const String chat = CoreShellRouteIds.chat;
  static const String humanHandoff = CoreShellRouteIds.humanHandoff;
  static const String localUsers = CoreShellRouteIds.localUsers;
  static const String tenantManagement = CoreShellRouteIds.tenantManagement;
  static const String rolePermissionManagement =
      CoreShellRouteIds.rolePermissionManagement;
  static const String auditManagement = CoreShellRouteIds.auditManagement;
  static const String runtimeControl = CoreShellRouteIds.runtimeControl;
  static const String channelOrchestration =
      CoreShellRouteIds.channelOrchestration;
  static const String contextEngine = CoreShellRouteIds.contextEngine;
  static const String knowledgePacks = CoreShellRouteIds.knowledgePacks;
  static const String acpConsole = CoreShellRouteIds.acpConsole;

  static String buildInviteRoute({
    required String tenantId,
    required String invitationId,
    String? token,
  }) {
    return AppRoutePaths.buildInviteRoute(
      tenantId: tenantId,
      invitationId: invitationId,
      token: token,
    );
  }

  static InviteRouteMatch? parseInviteRoute(String? routeName) {
    return AppRoutePaths.parseInviteRoute(routeName);
  }
}
