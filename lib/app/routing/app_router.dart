import 'package:flutter/material.dart';

import 'package:mugen_ui/app/definition/app_definition.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/extension/app_definition.dart';

class AppRouter {
  const AppRouter._(); // coverage:ignore-line

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    return onGenerateRouteWithDefinitions(
      settings: settings,
      topLevelRoutes: appDefinition.topLevelRoutes,
      fallbackRoutePath: AppRoutePaths.app,
    );
  }

  static Route<dynamic>? onGenerateRouteWithDefinitions({
    required RouteSettings settings,
    required List<TopLevelRouteDefinition> topLevelRoutes,
    required String fallbackRoutePath,
  }) {
    if (settings.name == '/') {
      return null;
    }

    final matchedRoute = _matchTopLevelRoute(
      routeName: settings.name,
      topLevelRoutes: topLevelRoutes,
    );
    if (matchedRoute != null) {
      return _buildPageRoute(
        definition: matchedRoute.$1,
        match: matchedRoute.$2,
        settings: settings,
      );
    }

    final fallbackRoute = _findExactPathRoute(
      topLevelRoutes: topLevelRoutes,
      exactPath: fallbackRoutePath,
    );
    if (fallbackRoute == null) {
      return null;
    }

    final fallbackMatch = fallbackRoute.match(fallbackRoutePath);
    if (fallbackMatch == null) {
      throw StateError(
        'Fallback route "$fallbackRoutePath" did not match its own definition.',
      );
    }

    return _buildPageRoute(
      definition: fallbackRoute,
      match: fallbackMatch,
      settings: settings,
    );
  }

  static (TopLevelRouteDefinition, TopLevelRouteMatch)? _matchTopLevelRoute({
    required String? routeName,
    required List<TopLevelRouteDefinition> topLevelRoutes,
  }) {
    for (final route in topLevelRoutes) {
      final match = route.match(routeName);
      if (match != null) {
        return (route, match);
      }
    }

    return null;
  }

  static TopLevelRouteDefinition? _findExactPathRoute({
    required List<TopLevelRouteDefinition> topLevelRoutes,
    required String exactPath,
  }) {
    for (final route in topLevelRoutes) {
      if (route.exactPath == exactPath) {
        return route;
      }
    }

    return null;
  }

  static MaterialPageRoute<dynamic> _buildPageRoute({
    required TopLevelRouteDefinition definition,
    required TopLevelRouteMatch match,
    required RouteSettings settings,
  }) {
    return MaterialPageRoute<dynamic>(
      builder: (context) => definition.builder(context, match),
      settings: RouteSettings(
        name: match.location,
        arguments: settings.arguments,
      ),
    );
  }
}
