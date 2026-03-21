import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mugen_ui/app/definition/app_definition.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/shell/presentation/widgets/route_views.dart';

void main() {
  const routes = <ShellRouteDefinition>[
    ShellRouteDefinition(
      id: RouteIds.chat,
      title: 'AI Assist',
      icon: Icons.chat_bubble_outline,
      builder: _buildChatMarker,
    ),
    ShellRouteDefinition(
      id: 'reports',
      title: 'Reports',
      icon: Icons.dashboard_outlined,
      builder: _buildReportsMarker,
    ),
  ];

  test('findShellRouteDefinition returns the registered route', () {
    final route = findShellRouteDefinition(routes: routes, routeId: 'reports');
    expect(route, isNotNull);
    expect(route?.title, 'Reports');
  });

  testWidgets('Unknown route renders unknown view', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: buildRegisteredShellRouteWidget(
              context: context,
              routes: routes,
              routeId: 'missing-route',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Unknown route'), findsOneWidget);
    expect(find.text('The selected route is not configured.'), findsOneWidget);
  });

  testWidgets('Registered route builder is used for known routes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: buildRegisteredShellRouteWidget(
              context: context,
              routes: routes,
              routeId: 'reports',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Reports marker'), findsOneWidget);
    expect(find.text('Chat marker'), findsNothing);
  });
}

Widget _buildChatMarker(BuildContext context) {
  return const Text('Chat marker');
}

Widget _buildReportsMarker(BuildContext context) {
  return const Text('Reports marker');
}
