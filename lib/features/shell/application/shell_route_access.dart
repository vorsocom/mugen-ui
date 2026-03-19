import 'package:mugen_ui/app/config/app_config.dart';

class ShellRouteAccess {
  const ShellRouteAccess({
    required this.requestedRoute,
    required this.requestedRouteConfig,
    required this.allowedRoutes,
    required this.fallbackRoute,
  });

  final String requestedRoute;
  final SpaRouteConfig? requestedRouteConfig;
  final List<SpaRouteConfig> allowedRoutes;
  final SpaRouteConfig? fallbackRoute;

  bool get isKnownRoute => requestedRouteConfig != null;

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
  required AppConfig config,
  required List<String> sessionRoles,
  required String requestedRoute,
}) {
  final requestedRouteConfig = _findSpaRoute(config.spaRoutes, requestedRoute);
  final allowedRoutes = config.spaRoutes
      .where((route) => _hasRequiredRoles(sessionRoles, route.roles))
      .toList(growable: false);
  final fallbackRoute = _resolveFallbackRoute(
    config: config,
    allowedRoutes: allowedRoutes,
  );

  return ShellRouteAccess(
    requestedRoute: requestedRoute,
    requestedRouteConfig: requestedRouteConfig,
    allowedRoutes: allowedRoutes,
    fallbackRoute: fallbackRoute,
  );
}

SpaRouteConfig? _findSpaRoute(List<SpaRouteConfig> spaRoutes, String routeId) {
  for (final route in spaRoutes) {
    if (route.id == routeId) {
      return route;
    }
  }

  return null;
}

SpaRouteConfig? _resolveFallbackRoute({
  required AppConfig config,
  required List<SpaRouteConfig> allowedRoutes,
}) {
  if (allowedRoutes.isEmpty) {
    return null;
  }

  for (final route in allowedRoutes) {
    if (route.id == config.spaDefaultRoute) {
      return route;
    }
  }

  return allowedRoutes.first;
}

bool _hasRequiredRoles(List<String> sessionRoles, List<String> requiredRoles) {
  if (requiredRoles.isEmpty) {
    return true;
  }

  return requiredRoles.every(sessionRoles.contains);
}
