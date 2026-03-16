import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/context_admin/presentation/providers/context_admin_providers.dart';
import 'package:mugen_ui/features/context_admin/presentation/widgets/context_engine_panel.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_admin_repository_impl.dart';

import '../../../test_support/fake_acp_admin_repository.dart';
import '../../../test_support/recording_auth_controller.dart';

void main() {
  test('context admin providers expose descriptor-backed controller', () {
    final repositoryContainer = ProviderContainer();
    addTearDown(repositoryContainer.dispose);
    expect(
      repositoryContainer.read(contextAdminRepositoryProvider),
      isA<AcpAdminRepositoryImpl>(),
    );

    final container = ProviderContainer(
      overrides: <Override>[
        contextAdminRepositoryProvider.overrideWithValue(
          FakeAcpAdminRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(contextAdminControllerProvider.notifier);
    expect(controller.descriptors, hasLength(5));
    expect(controller.descriptors.first.title, 'Profiles');
    expect(controller.descriptors[1].updateFields, isNotEmpty);
    expect(controller.descriptors.last.title, 'Trace Policies');
  });

  testWidgets('ContextEnginePanel renders description and tabs', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          contextAdminRepositoryProvider.overrideWithValue(
            FakeAcpAdminRepository(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ContextEnginePanel())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profiles'), findsWidgets);
    expect(find.text('Policies'), findsOneWidget);
    expect(find.text('Contributor Bindings'), findsOneWidget);
    expect(find.text('Trace Policies'), findsOneWidget);
    expect(
      find.textContaining('Configure context profiles, policies'),
      findsOneWidget,
    );
  });

  test('context admin refreshes auth on session expiry', () async {
    final repository = FakeAcpAdminRepository()
      ..createResult = const Result<Object?>.failure(SessionExpiredFailure());
    final authController = RecordingAuthController();
    final container = ProviderContainer(
      overrides: <Override>[
        authControllerProvider.overrideWith(() => authController),
        contextAdminRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(contextAdminControllerProvider.notifier);
    await controller.loadInitialData();
    final result = await controller.createRow(const <String, dynamic>{
      'Name': 'profile-a',
    });

    expect(result.isFailure, isTrue);
    expect(authController.refreshCount, 1);
  });
}
