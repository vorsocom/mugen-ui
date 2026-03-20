import 'package:flutter/material.dart';

import 'package:mugen_ui/app/definition/app_definition.dart';

Widget buildRegisteredShellRouteWidget({
  required BuildContext context,
  required List<ShellRouteDefinition> routes,
  required String routeId,
}) {
  final route = findShellRouteDefinition(routes: routes, routeId: routeId);
  if (route == null) {
    return const RoutePlaceholder(
      title: 'Unknown route',
      description: 'The selected route is not configured.',
    );
  }

  return route.builder(context);
}

ShellRouteDefinition? findShellRouteDefinition({
  required List<ShellRouteDefinition> routes,
  required String routeId,
}) {
  for (final route in routes) {
    if (route.id == routeId) {
      return route;
    }
  }

  return null;
}

class RoutePlaceholder extends StatelessWidget {
  const RoutePlaceholder({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(description),
          ],
        ),
      ),
    );
  }
}
