import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/chat/presentation/pages/chat_page.dart';
import 'package:mugen_ui/features/shell/presentation/widgets/route_views.dart';
import 'package:mugen_ui/features/user_admin/presentation/widgets/local_user_panel.dart';

void main() {
  test('Dashboard route maps to ChatPage (legacy compatibility)', () {
    final widget = buildSpaRouteWidget(RouteIds.dashboard);
    expect(widget, isA<ChatPage>());
  });

  testWidgets('Unknown route renders unknown view', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: buildSpaRouteWidget('missing-route'))),
    );

    await tester.pumpAndSettle();

    expect(find.text('Unknown route'), findsOneWidget);
    expect(find.text('The selected route is not configured.'), findsOneWidget);
  });

  test('Chat route maps to ChatPage widget', () {
    final widget = buildSpaRouteWidget(RouteIds.chat);
    expect(widget, isA<ChatPage>());
  });

  test('Local users route maps to LocalUserPanel widget', () {
    final widget = buildSpaRouteWidget(RouteIds.localUsers);
    expect(widget, isA<Padding>());
    final padded = widget as Padding;
    expect(padded.child, isA<LocalUserPanel>());
  });
}
