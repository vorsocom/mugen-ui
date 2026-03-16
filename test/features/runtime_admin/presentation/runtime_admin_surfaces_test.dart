import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/runtime_admin/presentation/providers/runtime_admin_providers.dart';
import 'package:mugen_ui/features/runtime_admin/presentation/widgets/runtime_control_panel.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_admin_repository_impl.dart';

import '../../../test_support/fake_acp_admin_repository.dart';
import '../../../test_support/recording_auth_controller.dart';

void main() {
  test('runtime admin providers expose descriptor-backed controller', () {
    final repositoryContainer = ProviderContainer();
    addTearDown(repositoryContainer.dispose);
    expect(
      repositoryContainer.read(runtimeAdminRepositoryProvider),
      isA<AcpAdminRepositoryImpl>(),
    );

    final container = ProviderContainer(
      overrides: <Override>[
        runtimeAdminRepositoryProvider.overrideWithValue(
          FakeAcpAdminRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(runtimeAdminControllerProvider.notifier);
    expect(controller.descriptors, hasLength(4));
    expect(controller.descriptors.first.title, 'Messaging Client Profiles');
    expect(controller.descriptors[2].entityActions, hasLength(2));
  });

  testWidgets('RuntimeControlPanel renders description and resource tabs', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          runtimeAdminRepositoryProvider.overrideWithValue(
            FakeAcpAdminRepository(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: RuntimeControlPanel())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Messaging Client Profiles'), findsOneWidget);
    expect(find.text('Runtime Config Profiles'), findsOneWidget);
    expect(find.text('Key References'), findsOneWidget);
    expect(find.text('System Flags'), findsOneWidget);
    expect(
      find.textContaining('Manage runtime client profiles'),
      findsOneWidget,
    );
  });

  test('runtime admin refreshes auth on session expiry', () async {
    final repository = FakeAcpAdminRepository()
      ..collectionActionResult = const Result<Object?>.failure(
        SessionExpiredFailure(),
      );
    final authController = RecordingAuthController();
    final container = ProviderContainer(
      overrides: <Override>[
        authControllerProvider.overrideWith(() => authController),
        runtimeAdminRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(runtimeAdminControllerProvider.notifier);
    await controller.loadInitialData();
    await controller.selectResource('system-flags');
    final result = await controller.runCollectionAction(
      action: controller.activeDescriptor.collectionActions.single,
      values: const <String, dynamic>{},
    );

    expect(result.isFailure, isTrue);
    expect(authController.refreshCount, 1);
  });
}
