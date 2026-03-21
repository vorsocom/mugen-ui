import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/orchestration_admin/application/orchestration_admin_resources.dart';
import 'package:mugen_ui/features/orchestration_admin/presentation/providers/orchestration_admin_providers.dart';
import 'package:mugen_ui/features/orchestration_admin/presentation/widgets/channel_orchestration_panel.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_admin_repository_impl.dart';

import '../../../test_support/fake_acp_admin_repository.dart';
import '../../../test_support/recording_auth_controller.dart';

void main() {
  test('orchestration admin providers expose descriptor-backed controller', () {
    final repositoryContainer = ProviderContainer();
    addTearDown(repositoryContainer.dispose);
    expect(
      repositoryContainer.read(orchestrationAdminRepositoryProvider),
      isA<AcpAdminRepositoryImpl>(),
    );

    final container = ProviderContainer(
      overrides: <Override>[
        orchestrationAdminRepositoryProvider.overrideWithValue(
          FakeAcpAdminRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      orchestrationAdminControllerProvider.notifier,
    );
    expect(controller.descriptors, hasLength(10));
    expect(controller.descriptors.first.title, 'Channel Profiles');
    expect(controller.descriptors.last.title, 'Events');
    expect(controller.descriptors[6].collectionActions, hasLength(2));
  });

  testWidgets('ChannelOrchestrationPanel renders description and tabs', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          orchestrationAdminRepositoryProvider.overrideWithValue(
            FakeAcpAdminRepository(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ChannelOrchestrationPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Channel Profiles'), findsOneWidget);
    expect(find.text('Ingress Bindings'), findsOneWidget);
    expect(find.text('Conversation State'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
    expect(
      find.textContaining('Configure channel intake, routing, throttling'),
      findsOneWidget,
    );
  });

  test(
    'channel profile create requirements match backend validation surface',
    () {
      final descriptor = orchestrationAdminResources.firstWhere(
        (resource) => resource.entitySet == 'ChannelProfiles',
      );

      expect(_requiredFieldKeys(descriptor.createFields), <String>[
        'ChannelKey',
        'ProfileKey',
      ]);
    },
  );

  test('orchestration admin refreshes auth on session expiry', () async {
    final repository = FakeAcpAdminRepository()
      ..collectionActionResult = const Result<Object?>.failure(
        SessionExpiredFailure(),
      );
    final authController = RecordingAuthController();
    final container = ProviderContainer(
      overrides: <Override>[
        authControllerProvider.overrideWith(() => authController),
        orchestrationAdminRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      orchestrationAdminControllerProvider.notifier,
    );
    await controller.loadInitialData();
    await controller.selectResource('blocklist-entries');
    final result = await controller.runCollectionAction(
      action: controller.activeDescriptor.collectionActions.first,
      values: const <String, dynamic>{},
    );

    expect(result.isFailure, isTrue);
    expect(authController.refreshCount, 1);
  });
}

List<String> _requiredFieldKeys(List<AcpFieldDescriptor> fields) {
  return fields
      .where((field) => field.required)
      .map((field) => field.key)
      .toList(growable: false);
}
