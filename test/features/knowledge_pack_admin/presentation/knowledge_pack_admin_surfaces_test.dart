import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/knowledge_pack_admin/application/knowledge_pack_admin_resources.dart';
import 'package:mugen_ui/features/knowledge_pack_admin/presentation/providers/knowledge_pack_admin_providers.dart';
import 'package:mugen_ui/features/knowledge_pack_admin/presentation/widgets/knowledge_pack_panel.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_admin_repository_impl.dart';

import '../../../test_support/fake_acp_admin_repository.dart';
import '../../../test_support/recording_auth_controller.dart';

void main() {
  test('knowledge pack providers expose descriptor-backed controller', () {
    final repositoryContainer = ProviderContainer();
    addTearDown(repositoryContainer.dispose);
    expect(
      repositoryContainer.read(knowledgePackAdminRepositoryProvider),
      isA<AcpAdminRepositoryImpl>(),
    );

    final container = ProviderContainer(
      overrides: <Override>[
        knowledgePackAdminRepositoryProvider.overrideWithValue(
          FakeAcpAdminRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      knowledgePackAdminControllerProvider.notifier,
    );
    expect(controller.descriptors, hasLength(6));
    expect(controller.descriptors.first.title, 'Packs');
    expect(controller.descriptors[1].entityActions, hasLength(6));
    expect(controller.descriptors[4].allowCreate, isFalse);
    expect(controller.descriptors.last.title, 'Scopes');
  });

  testWidgets('KnowledgePackPanel renders description and tabs', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          knowledgePackAdminRepositoryProvider.overrideWithValue(
            FakeAcpAdminRepository(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: KnowledgePackPanel())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Packs'), findsWidgets);
    expect(find.text('Versions'), findsOneWidget);
    expect(find.text('Entries'), findsOneWidget);
    expect(find.text('Entry Revisions'), findsOneWidget);
    expect(find.text('Approvals'), findsOneWidget);
    expect(find.text('Scopes'), findsOneWidget);
    expect(
      find.textContaining('Configure knowledge packs, versions'),
      findsOneWidget,
    );
  });

  test(
    'knowledge pack create requirements match backend validation surface',
    () {
      final packsDescriptor = _descriptor('KnowledgePacks');
      final versionsDescriptor = _descriptor('KnowledgePackVersions');
      final entriesDescriptor = _descriptor('KnowledgeEntries');
      final revisionsDescriptor = _descriptor('KnowledgeEntryRevisions');
      final approvalsDescriptor = _descriptor('KnowledgeApprovals');
      final scopesDescriptor = _descriptor('KnowledgeScopes');

      expect(_requiredFieldKeys(packsDescriptor.createFields), <String>[
        'Key',
        'Name',
      ]);
      expect(_requiredFieldKeys(versionsDescriptor.createFields), <String>[
        'KnowledgePackId',
        'VersionNumber',
      ]);
      expect(_requiredFieldKeys(entriesDescriptor.createFields), <String>[
        'KnowledgePackId',
        'KnowledgePackVersionId',
        'EntryKey',
        'Title',
      ]);
      expect(_requiredFieldKeys(revisionsDescriptor.createFields), <String>[
        'KnowledgeEntryId',
        'KnowledgePackVersionId',
        'RevisionNumber',
      ]);
      expect(approvalsDescriptor.createFields, isEmpty);
      expect(_requiredFieldKeys(scopesDescriptor.createFields), <String>[
        'KnowledgePackVersionId',
        'KnowledgeEntryRevisionId',
      ]);
    },
  );

  test('knowledge pack version actions require row versions', () {
    final versionDescriptor = _descriptor('KnowledgePackVersions');
    final actionNames = versionDescriptor.entityActions
        .map((action) => action.name)
        .toList(growable: false);

    expect(actionNames, <String>[
      'submit_for_review',
      'approve',
      'reject',
      'publish',
      'archive',
      'rollback_version',
    ]);
    expect(
      versionDescriptor.entityActions.every(
        (action) => action.includeRowVersion,
      ),
      isTrue,
    );
    expect(
      versionDescriptor.entityActions
          .firstWhere((action) => action.name == 'reject')
          .fields
          .map((field) => field.key),
      <String>['Reason', 'Note'],
    );
    expect(
      versionDescriptor.entityActions
          .firstWhere((action) => action.name == 'archive')
          .fields
          .map((field) => field.key),
      <String>['Reason', 'Note'],
    );
  });

  test('knowledge pack admin refreshes auth on session expiry', () async {
    final repository = FakeAcpAdminRepository()
      ..entityActionResult = const Result<Object?>.failure(
        SessionExpiredFailure(),
      );
    final authController = RecordingAuthController();
    final container = ProviderContainer(
      overrides: <Override>[
        authControllerProvider.overrideWith(() => authController),
        knowledgePackAdminRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      knowledgePackAdminControllerProvider.notifier,
    );
    await controller.loadInitialData();
    await controller.selectResource('knowledge-pack-versions');
    final result = await controller.runEntityAction(
      action: controller.activeDescriptor.entityActions.first,
      rowId: 'version-1',
      values: const <String, dynamic>{},
      rowVersion: 1,
    );

    expect(result.isFailure, isTrue);
    expect(authController.refreshCount, 1);
  });
}

AcpResourceDescriptor _descriptor(String entitySet) {
  return knowledgePackAdminResources.firstWhere(
    (descriptor) => descriptor.entitySet == entitySet,
  );
}

List<String> _requiredFieldKeys(List<AcpFieldDescriptor> fields) {
  return fields
      .where((field) => field.required)
      .map((field) => field.key)
      .toList(growable: false);
}
