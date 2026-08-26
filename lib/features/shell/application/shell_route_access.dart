import 'package:mugen_ui/app/definition/app_definition.dart';

class ShellRouteAccess {
  const ShellRouteAccess({
    required this.requestedRoute,
    required this.requestedRouteDefinition,
    required this.allowedRoutes,
    required this.fallbackRoute,
    required this.routeAvailabilities,
    required this.sessionRoles,
  });

  final String requestedRoute;
  final ShellRouteDefinition? requestedRouteDefinition;
  final List<ShellRouteDefinition> allowedRoutes;
  final ShellRouteDefinition? fallbackRoute;
  final Map<String, ShellRouteAvailability> routeAvailabilities;

  bool get isKnownRoute => requestedRouteDefinition != null;

  bool get isAllowedRoute => isKnownRoute && _isRouteAllowed(requestedRoute);

  bool get isPendingKnownRoute {
    if (!isKnownRoute || !_hasRequiredRolesForRequestedRoute) {
      return false;
    }
    return routeAvailabilities[requestedRoute]?.status ==
        ShellRouteAvailabilityStatus.pending;
  }

  bool get isUnauthorizedKnownRoute =>
      isKnownRoute && !isAllowedRoute && !isPendingKnownRoute;

  bool get shouldRedirect =>
      isUnauthorizedKnownRoute &&
      fallbackRoute != null &&
      fallbackRoute!.id != requestedRoute;

  bool get showLockedOutState =>
      isUnauthorizedKnownRoute && fallbackRoute == null;

  String? get denialMessage {
    if (!isUnauthorizedKnownRoute) {
      return null;
    }
    return routeAvailabilities[requestedRoute]?.message;
  }

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

  bool get _hasRequiredRolesForRequestedRoute {
    final route = requestedRouteDefinition;
    if (route == null) {
      return false;
    }
    return route.requiredRoles.every(sessionRoles.contains);
  }

  bool _isRouteAllowed(String routeId) {
    return allowedRoutes.any((route) => route.id == routeId);
  }

  final List<String> sessionRoles;
}

ShellRouteAccess resolveShellRouteAccess({
  required List<ShellRouteDefinition> shellRoutes,
  required String defaultShellRouteId,
  required List<String> sessionRoles,
  required String requestedRoute,
  Map<String, ShellRouteAvailability> routeAvailabilities =
      const <String, ShellRouteAvailability>{},
}) {
  final requestedRouteDefinition = _findShellRoute(shellRoutes, requestedRoute);
  final allowedRoutes = shellRoutes
      .where((route) => _hasRequiredRoles(sessionRoles, route.requiredRoles))
      .where(
        (route) =>
            routeAvailabilities[route.id]?.status !=
            ShellRouteAvailabilityStatus.unavailable,
      )
      .where(
        (route) =>
            routeAvailabilities[route.id]?.status !=
            ShellRouteAvailabilityStatus.pending,
      )
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
    routeAvailabilities: routeAvailabilities,
    sessionRoles: sessionRoles,
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
