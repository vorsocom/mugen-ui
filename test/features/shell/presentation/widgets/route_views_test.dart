import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/acp_console/presentation/widgets/acp_console_panel.dart';
import 'package:mugen_ui/features/audit_admin/presentation/widgets/audit_management_panel.dart';
import 'package:mugen_ui/features/chat/presentation/pages/chat_page.dart';
import 'package:mugen_ui/features/context_admin/presentation/widgets/context_engine_panel.dart';
import 'package:mugen_ui/features/orchestration_admin/presentation/widgets/channel_orchestration_panel.dart';
import 'package:mugen_ui/features/rbac_admin/presentation/widgets/rbac_management_panel.dart';
import 'package:mugen_ui/features/runtime_admin/presentation/widgets/runtime_control_panel.dart';
import 'package:mugen_ui/features/shell/presentation/widgets/route_views.dart';
import 'package:mugen_ui/features/tenant_admin/presentation/widgets/tenant_management_panel.dart';
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

  test('Tenant management route maps to TenantManagementPanel widget', () {
    final widget = buildSpaRouteWidget(RouteIds.tenantManagement);
    expect(widget, isA<Padding>());
    final padded = widget as Padding;
    expect(padded.child, isA<TenantManagementPanel>());
  });

  test('RBAC route maps to RbacManagementPanel widget', () {
    final widget = buildSpaRouteWidget(RouteIds.rolePermissionManagement);
    expect(widget, isA<Padding>());
    final padded = widget as Padding;
    expect(padded.child, isA<RbacManagementPanel>());
  });

  test('Audit route maps to AuditManagementPanel widget', () {
    final widget = buildSpaRouteWidget(RouteIds.auditManagement);
    expect(widget, isA<Padding>());
    final padded = widget as Padding;
    expect(padded.child, isA<AuditManagementPanel>());
  });

  test('Runtime route maps to RuntimeControlPanel widget', () {
    final widget = buildSpaRouteWidget(RouteIds.runtimeControl);
    expect(widget, isA<Padding>());
    final padded = widget as Padding;
    expect(padded.child, isA<RuntimeControlPanel>());
  });

  test('Orchestration route maps to ChannelOrchestrationPanel widget', () {
    final widget = buildSpaRouteWidget(RouteIds.channelOrchestration);
    expect(widget, isA<Padding>());
    final padded = widget as Padding;
    expect(padded.child, isA<ChannelOrchestrationPanel>());
  });

  test('Context route maps to ContextEnginePanel widget', () {
    final widget = buildSpaRouteWidget(RouteIds.contextEngine);
    expect(widget, isA<Padding>());
    final padded = widget as Padding;
    expect(padded.child, isA<ContextEnginePanel>());
  });

  test('ACP console route maps to AcpConsolePanel widget', () {
    final widget = buildSpaRouteWidget(RouteIds.acpConsole);
    expect(widget, isA<Padding>());
    final padded = widget as Padding;
    expect(padded.child, isA<AcpConsolePanel>());
  });
}
