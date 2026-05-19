import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_controller.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_admin_panel.dart';
import 'package:mugen_ui/shared/presentation/theme/app_form_style.dart';

import '../../../test_support/fake_acp_admin_repository.dart';

void main() {
  testWidgets('New Row dialog shrink-wraps short ACP forms', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await _pumpPanel(
      tester,
      descriptors: const <AcpResourceDescriptor>[
        AcpResourceDescriptor(
          key: 'short-resource',
          title: 'Short Resource',
          entitySet: 'ShortResources',
          scopeMode: AcpScopeMode.none,
          columns: <AcpColumnDescriptor>[
            AcpColumnDescriptor(key: 'Name', label: 'Name'),
          ],
          createFields: <AcpFieldDescriptor>[
            AcpFieldDescriptor(key: 'Name', label: 'Name'),
          ],
          allowCreate: true,
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('acp-admin-create-button')));
    await tester.pumpAndSettle();

    expect(find.text('Create Short Resource'), findsOneWidget);
    final dialogPanel = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(AppFormPanel),
    );
    expect(tester.getSize(dialogPanel).height, lessThan(360));
  });
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required List<AcpResourceDescriptor> descriptors,
}) async {
  final repository = FakeAcpAdminRepository();
  final controllerProvider =
      StateNotifierProvider<AcpAdminController, AcpAdminState>((ref) {
        return AcpAdminController(
          repository: repository,
          descriptors: descriptors,
          onSessionExpired: () {},
        );
      });

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: AcpAdminPanel<AcpAdminController>(
            controllerProvider: controllerProvider,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
