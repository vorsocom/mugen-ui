import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/acp_console/presentation/providers/acp_console_providers.dart';
import 'package:mugen_ui/features/acp_console/presentation/widgets/acp_console_panel.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_admin_repository_impl.dart';

import '../../../test_support/fake_acp_admin_repository.dart';
import '../../../test_support/recording_auth_controller.dart';

void main() {
  test('ACP console providers expose descriptor-backed controller', () {
    final repositoryContainer = ProviderContainer();
    addTearDown(repositoryContainer.dispose);
    expect(
      repositoryContainer.read(acpConsoleRepositoryProvider),
      isA<AcpAdminRepositoryImpl>(),
    );

    final container = ProviderContainer(
      overrides: <Override>[
        acpConsoleRepositoryProvider.overrideWithValue(
          FakeAcpAdminRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(acpConsoleControllerProvider.notifier);
    expect(controller.descriptors, hasLength(7));
    expect(controller.descriptors.first.title, 'Schemas');
    expect(controller.descriptors[2].entityActions.single.name, 'revoke');
    expect(controller.descriptors.last.title, 'Audit Biz Trace Events');
  });

  testWidgets('AcpConsolePanel renders description and tabs', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          acpConsoleRepositoryProvider.overrideWithValue(
            FakeAcpAdminRepository(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: AcpConsolePanel())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Schemas'), findsOneWidget);
    expect(find.text('Schema Bindings'), findsOneWidget);
    expect(find.text('Plugin Capability Grants'), findsOneWidget);
    expect(find.text('Audit Biz Trace Events'), findsOneWidget);
    expect(
      find.textContaining('Advanced descriptor-driven ACP console'),
      findsOneWidget,
    );
  });

  test('ACP console refreshes auth on session expiry', () async {
    final repository = FakeAcpAdminRepository()
      ..collectionActionResult = const Result<Object?>.failure(
        SessionExpiredFailure(),
      );
    final authController = RecordingAuthController();
    final container = ProviderContainer(
      overrides: <Override>[
        authControllerProvider.overrideWith(() => authController),
        acpConsoleRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(acpConsoleControllerProvider.notifier);
    await controller.loadInitialData();
    final result = await controller.runCollectionAction(
      action: controller.activeDescriptor.collectionActions.first,
      values: const <String, dynamic>{},
    );

    expect(result.isFailure, isTrue);
    expect(authController.refreshCount, 1);
  });
}
