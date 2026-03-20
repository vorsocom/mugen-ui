import 'package:mugen_ui/app/definition/app_definition.dart';

class ShellRouteAccess {
  const ShellRouteAccess({
    required this.requestedRoute,
    required this.requestedRouteDefinition,
    required this.allowedRoutes,
    required this.fallbackRoute,
  });

  final String requestedRoute;
  final ShellRouteDefinition? requestedRouteDefinition;
  final List<ShellRouteDefinition> allowedRoutes;
  final ShellRouteDefinition? fallbackRoute;

  bool get isKnownRoute => requestedRouteDefinition != null;

  bool get isAllowedRoute =>
      isKnownRoute && allowedRoutes.any((route) => route.id == requestedRoute);

  bool get isUnauthorizedKnownRoute => isKnownRoute && !isAllowedRoute;

  bool get shouldRedirect =>
      isUnauthorizedKnownRoute &&
      fallbackRoute != null &&
      fallbackRoute!.id != requestedRoute;

  bool get showLockedOutState =>
      isUnauthorizedKnownRoute && fallbackRoute == null;

  String get canonicalRouteId => isUnauthorizedKnownRoute
      ? (fallbackRoute?.id ?? requestedRoute)
      : requestedRoute;

  String? get displayedRouteId {
    if (showLockedOutState) {
      return null;
    }

    if (shouldRedirect) {
      return fallbackRoute!.id;
    }

    return requestedRoute;
  }

  Set<String> get allowedRouteIds {
    return allowedRoutes.map((route) => route.id).toSet();
  }
}

ShellRouteAccess resolveShellRouteAccess({
  required List<ShellRouteDefinition> shellRoutes,
  required String defaultShellRouteId,
  required List<String> sessionRoles,
  required String requestedRoute,
}) {
  final requestedRouteDefinition = _findShellRoute(shellRoutes, requestedRoute);
  final allowedRoutes = shellRoutes
      .where((route) => _hasRequiredRoles(sessionRoles, route.requiredRoles))
      .toList(growable: false);
  final fallbackRoute = _resolveFallbackRoute(
    shellRoutes: shellRoutes,
    allowedRoutes: allowedRoutes,
    defaultShellRouteId: defaultShellRouteId,
  );

  return ShellRouteAccess(
    requestedRoute: requestedRoute,
    requestedRouteDefinition: requestedRouteDefinition,
    allowedRoutes: allowedRoutes,
    fallbackRoute: fallbackRoute,
  );
}

ShellRouteDefinition? _findShellRoute(
  List<ShellRouteDefinition> shellRoutes,
  String routeId,
) {
  for (final route in shellRoutes) {
    if (route.id == routeId) {
      return route;
    }
  }

  return null;
}

ShellRouteDefinition? _resolveFallbackRoute({
  required List<ShellRouteDefinition> shellRoutes,
  required List<ShellRouteDefinition> allowedRoutes,
  required String defaultShellRouteId,
}) {
  if (allowedRoutes.isEmpty) {
    return null;
  }

  final defaultRoute = _findShellRoute(shellRoutes, defaultShellRouteId);
  if (defaultRoute != null &&
      allowedRoutes.any((route) => route.id == defaultRoute.id)) {
    return defaultRoute;
  }

  return allowedRoutes.first;
}

bool _hasRequiredRoles(List<String> sessionRoles, List<String> requiredRoles) {
  if (requiredRoles.isEmpty) {
    return true;
  }

  return requiredRoles.every(sessionRoles.contains);
}
