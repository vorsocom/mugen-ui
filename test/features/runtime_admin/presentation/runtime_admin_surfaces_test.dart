import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/runtime_admin/presentation/providers/runtime_admin_providers.dart';
import 'package:mugen_ui/features/runtime_admin/presentation/widgets/runtime_control_panel.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
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

  testWidgets(
    'messaging client profile create form only requires universal fields before platform selection',
    (WidgetTester tester) async {
      final repository = _RecordingAcpAdminRepository();
      await _pumpRuntimeControlPanel(tester, repository);

      await tester.tap(find.byKey(const Key('acp-admin-create-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(find.text('Platform Key is required.'), findsOneWidget);
      expect(find.text('Profile Key is required.'), findsOneWidget);
      expect(find.text('Path Token is required.'), findsNothing);
      expect(find.text('Recipient User ID is required.'), findsNothing);
      expect(repository.createCalls, isEmpty);
    },
  );

  testWidgets(
    'messaging client profile create form applies platform-specific required fields',
    (WidgetTester tester) async {
      final repository = _RecordingAcpAdminRepository();
      await _pumpRuntimeControlPanel(tester, repository);

      await tester.tap(find.byKey(const Key('acp-admin-create-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('acp-dynamic-field-PlatformKey')),
        'matrix',
      );
      await tester.enterText(
        find.byKey(const Key('acp-dynamic-field-ProfileKey')),
        'primary',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(find.text('Recipient User ID is required.'), findsOneWidget);
      expect(find.text('Path Token is required.'), findsNothing);
      expect(find.text('Phone Number ID is required.'), findsNothing);
      expect(repository.createCalls, isEmpty);

      await tester.enterText(
        find.byKey(const Key('acp-dynamic-field-RecipientUserId')),
        '@assistant:example.org',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(repository.createCalls, hasLength(1));
      expect(repository.createCalls.single['PlatformKey'], 'matrix');
      expect(repository.createCalls.single['ProfileKey'], 'primary');
      expect(repository.createCalls.single['DisplayName'], '');
      expect(
        repository.createCalls.single['RecipientUserId'],
        '@assistant:example.org',
      );
      expect(repository.createCalls.single['PathToken'], '');
      expect(repository.createCalls.single['AccountNumber'], '');
      expect(repository.createCalls.single['PhoneNumberId'], '');
      expect(repository.createCalls.single['Provider'], '');
    },
  );

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

Future<void> _pumpRuntimeControlPanel(
  WidgetTester tester,
  FakeAcpAdminRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(1800, 1200));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        runtimeAdminRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: Scaffold(body: RuntimeControlPanel())),
    ),
  );
  await tester.pumpAndSettle();
}

class _RecordingAcpAdminRepository extends FakeAcpAdminRepository {
  final List<Map<String, dynamic>> createCalls = <Map<String, dynamic>>[];

  @override
  Future<Result<Object?>> createRow({
    required AcpResourceDescriptor descriptor,
    required Map<String, dynamic> values,
    String? tenantId,
  }) async {
    createCalls.add(Map<String, dynamic>.from(values));
    return super.createRow(
      descriptor: descriptor,
      values: values,
      tenantId: tenantId,
    );
  }
}
