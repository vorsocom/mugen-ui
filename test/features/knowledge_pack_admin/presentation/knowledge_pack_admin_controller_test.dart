import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/knowledge_pack_admin/presentation/providers/knowledge_pack_admin_providers.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_controller.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/presentation/feedback/snackbar_dispatcher.dart';
import 'package:mugen_ui/shared/presentation/navigation/app_navigator.dart';

import '../../../test_support/fake_acp_admin_repository.dart';

void main() {
  test('immediate relational publication completes without polling', () async {
    final fixture = await _fixture(
      actionResult: const Result<Object?>.success(null),
    );
    final result = await fixture.controller.runEntityAction(
      action: _action(fixture.controller, 'publish'),
      rowId: 'version-next',
      values: const <String, Object?>{},
      rowVersion: 7,
    );
    await pumpEventQueue();

    expect(result.isSuccess, isTrue);
    expect(fixture.repository.projectionFetchCalls, 0);
    expect(fixture.repository.entityActionRowVersions, <int?>[7]);
    expect(fixture.messages, isEmpty);
  });

  test(
    'queued publication polls processing to ready and preserves current',
    () async {
      final fixture = await _fixture(
        actionResult: _queuedResult,
        projectionResults: <Result<AcpRow>>[
          Result<AcpRow>.success(
            _projection(status: 'processing', operation: 'publish'),
          ),
          Result<AcpRow>.success(
            _projection(status: 'ready', isCurrentReady: true),
          ),
        ],
      );
      await fixture.controller.runEntityAction(
        action: _action(fixture.controller, 'publish'),
        rowId: 'version-next',
        values: const <String, Object?>{},
        rowVersion: 7,
      );
      await _waitFor(
        () => fixture.messages.contains('Projection is searchable.'),
      );

      expect(fixture.messages, <String>[
        'Projection indexing started.',
        'Projection is searchable.',
      ]);
      expect(fixture.repository.projectionFetchCalls, 2);
      expect(
        fixture.controller
            .resourceStateFor('knowledge-packs')
            .rows
            .single['CurrentVersionId'],
        'version-current',
      );
    },
  );

  test('reindex can return to queued before failing and then stops', () async {
    final fixture = await _fixture(
      actionResult: _queuedResult,
      projectionResults: <Result<AcpRow>>[
        Result<AcpRow>.success(
          _projection(status: 'processing', operation: 'reindex'),
        ),
        Result<AcpRow>.success(_projection(status: 'queued')),
        Result<AcpRow>.success(_projection(status: 'failed')),
      ],
    );
    await fixture.controller.runEntityAction(
      action: _action(fixture.controller, 'reindex'),
      rowId: 'version-next',
      values: const <String, Object?>{},
      tenantIdOverride: 'tenant-override',
      useTenantIdOverride: true,
      rowVersion: 7,
    );
    await _waitFor(
      () =>
          fixture.messages.any((item) => item.startsWith('Projection failed')),
    );

    expect(fixture.messages, <String>[
      'Projection reindexing started.',
      'Projection status changed to Queued.',
      'Projection failed. Review the safe failure detail and retry.',
    ]);
    expect(fixture.repository.lastProjectionTenantId, 'tenant-override');
    expect(fixture.repository.projectionFetchCalls, 3);
  });

  test(
    'cancelled projection is terminal and duplicate poll is prevented',
    () async {
      final fixture = await _fixture(
        actionResult: _queuedResult,
        projectionResults: <Result<AcpRow>>[
          Result<AcpRow>.success(_projection(status: 'cancelled')),
        ],
      );
      final publish = _action(fixture.controller, 'publish');
      await fixture.controller.runEntityAction(
        action: publish,
        rowId: 'version-next',
        values: const <String, Object?>{},
        rowVersion: 7,
      );
      await fixture.controller.runEntityAction(
        action: publish,
        rowId: 'version-next',
        values: const <String, Object?>{},
        rowVersion: 7,
      );
      await _waitFor(
        () => fixture.messages.contains('Projection was cancelled.'),
      );

      expect(fixture.repository.projectionFetchCalls, 1);
      expect(fixture.repository.entityActionCallCount, 2);
    },
  );

  test('unreliable status polling reports an actionable error', () async {
    final fixture = await _fixture(
      actionResult: _queuedResult,
      maxStatusFailures: 2,
      projectionResults: const <Result<AcpRow>>[
        Result<AcpRow>.failure(NetworkFailure('offline')),
        Result<AcpRow>.success(<String, Object?>{'Status': ''}),
      ],
    );
    await fixture.controller.runEntityAction(
      action: _action(fixture.controller, 'publish'),
      rowId: 'version-next',
      values: const <String, Object?>{},
      rowVersion: 7,
    );
    await _waitFor(
      () =>
          fixture.controller.state.errorMessage?.contains(
            'could not be determined',
          ) ==
          true,
    );

    expect(
      fixture.controller.state.errorMessage,
      contains('Refresh Projections before retrying publication'),
    );
  });

  test('repeated projection request failures stop polling', () async {
    final fixture = await _fixture(
      actionResult: _queuedResult,
      maxStatusFailures: 1,
      projectionResults: const <Result<AcpRow>>[
        Result<AcpRow>.failure(NetworkFailure('offline')),
      ],
    );
    await fixture.controller.runEntityAction(
      action: _action(fixture.controller, 'publish'),
      rowId: 'version-next',
      values: const <String, Object?>{},
      rowVersion: 7,
    );
    await _waitFor(() => fixture.controller.state.errorMessage != null);

    expect(fixture.repository.projectionFetchCalls, 1);
    expect(
      fixture.controller.state.errorMessage,
      contains('could not be determined reliably'),
    );
  });

  test('production provider dispatches projection state changes', () async {
    final repository = _PollingRepository(<Result<AcpRow>>[
      Result<AcpRow>.success(
        _projection(status: 'processing', operation: 'publish'),
      ),
    ])..entityActionResult = _queuedResult;
    final snackBars = _RecordingSnackBars();
    final container = ProviderContainer(
      overrides: <Override>[
        knowledgePackAdminRepositoryProvider.overrideWithValue(repository),
        snackBarDispatcherProvider.overrideWith((ref) => snackBars),
        appNavigatorProvider.overrideWith((ref) => AppNavigator()),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(
      knowledgePackAdminControllerProvider.notifier,
    );
    await controller.runEntityAction(
      action: _action(controller, 'publish'),
      rowId: 'version-next',
      values: const <String, Object?>{},
      rowVersion: 7,
    );
    await _waitFor(
      () => snackBars.messages.isNotEmpty,
      maxAttempts: 300,
      delay: const Duration(milliseconds: 10),
    );

    expect(snackBars.messages, <String>['Projection indexing started.']);
  });

  test(
    'non-projection, malformed, and inactive responses do not poll',
    () async {
      final fixture = await _fixture(
        actionResult: const Result<Object?>.success('ok'),
      );
      await fixture.controller.runEntityAction(
        action: _action(fixture.controller, 'approve'),
        rowId: 'version-next',
        values: const <String, Object?>{},
        rowVersion: 7,
      );
      await fixture.controller.runEntityAction(
        action: _action(fixture.controller, 'publish'),
        rowId: 'version-next',
        values: const <String, Object?>{},
        rowVersion: 7,
      );
      fixture.repository.entityActionResult = const Result<Object?>.success(
        <String, Object?>{'ProjectionId': '', 'Status': 'queued'},
      );
      await fixture.controller.runEntityAction(
        action: _action(fixture.controller, 'publish'),
        rowId: 'version-next',
        values: const <String, Object?>{},
        rowVersion: 7,
      );
      fixture.repository.entityActionResult = const Result<Object?>.success(
        <String, Object?>{'ProjectionId': 'projection-1', 'Status': 'ready'},
      );
      await fixture.controller.runEntityAction(
        action: _action(fixture.controller, 'publish'),
        rowId: 'version-next',
        values: const <String, Object?>{},
        rowVersion: 7,
      );
      await pumpEventQueue();
      expect(fixture.repository.projectionFetchCalls, 0);
    },
  );

  test('conflicts and permissions stay clear and keep RowVersion', () async {
    final forbidden = await _fixture(
      actionResult: const Result<Object?>.failure(
        ApiFailure(403, 'Forbidden.'),
      ),
    );
    final forbiddenResult = await forbidden.controller.runEntityAction(
      action: _action(forbidden.controller, 'publish'),
      rowId: 'version-next',
      values: const <String, Object?>{},
      rowVersion: 8,
    );
    expect(forbiddenResult.isFailure, isTrue);
    expect(forbidden.controller.state.errorMessage, 'Forbidden.');
    expect(forbidden.repository.entityActionRowVersions, <int?>[8]);

    final conflict = await _fixture(
      actionResult: const Result<Object?>.failure(
        ConflictFailure(ConflictKind.lifecycle, 'RowVersion conflict.'),
      ),
    );
    await conflict.controller.runEntityAction(
      action: _action(conflict.controller, 'publish'),
      rowId: 'version-next',
      values: const <String, Object?>{},
      rowVersion: 9,
    );
    expect(conflict.controller.state.errorMessage, contains('Conflict.'));
    expect(conflict.repository.entityActionRowVersions, <int?>[9]);
  });

  test('disposing an active poll stops further status requests', () async {
    final fixture = await _fixture(
      actionResult: _queuedResult,
      pollInterval: const Duration(milliseconds: 20),
      projectionResults: <Result<AcpRow>>[
        Result<AcpRow>.success(_projection(status: 'processing')),
      ],
    );
    await fixture.controller.runEntityAction(
      action: _action(fixture.controller, 'publish'),
      rowId: 'version-next',
      values: const <String, Object?>{},
      rowVersion: 7,
    );
    fixture.container.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(fixture.repository.projectionFetchCalls, 0);
  });
}

const Result<Object?> _queuedResult = Result<Object?>.success(<String, Object?>{
  'ProjectionId': 'projection-1',
  'Status': 'queued',
});

Future<_Fixture> _fixture({
  required Result<Object?> actionResult,
  List<Result<AcpRow>> projectionResults = const <Result<AcpRow>>[],
  Duration pollInterval = Duration.zero,
  int maxStatusFailures = 3,
}) async {
  final repository = _PollingRepository(projectionResults)
    ..entityActionResult = actionResult;
  final messages = <String>[];
  late StateNotifierProvider<KnowledgePackAdminController, AcpAdminState>
  provider;
  provider = StateNotifierProvider<KnowledgePackAdminController, AcpAdminState>(
    (ref) => KnowledgePackAdminController(
      ref,
      pollInterval: pollInterval,
      maxStatusFailures: maxStatusFailures,
      onProjectionUpdate: messages.add,
    ),
  );
  final container = ProviderContainer(
    overrides: <Override>[
      knowledgePackAdminRepositoryProvider.overrideWithValue(repository),
    ],
  );
  final controller = container.read(provider.notifier);
  await controller.loadInitialData();
  await controller.selectResource('knowledge-pack-versions');
  return _Fixture(
    container: container,
    controller: controller,
    repository: repository,
    messages: messages,
  );
}

AcpActionDescriptor _action(
  KnowledgePackAdminController controller,
  String name,
) => controller
    .descriptorForKey('knowledge-pack-versions')
    .entityActions
    .firstWhere((action) => action.name == name);

AcpRow _projection({
  required String status,
  String operation = 'publish',
  bool isCurrentReady = false,
}) => <String, Object?>{
  'Id': 'projection-1',
  'Status': status,
  'Operation': operation,
  'IsCurrentReady': isCurrentReady,
  'KnowledgePackId': 'pack-1',
  'KnowledgePackVersionId': 'version-next',
};

Future<void> _waitFor(
  bool Function() condition, {
  int maxAttempts = 100,
  Duration delay = const Duration(milliseconds: 1),
}) async {
  for (var attempt = 0; attempt < maxAttempts; attempt += 1) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(delay);
  }
  fail('Timed out waiting for projection polling.');
}

class _Fixture {
  const _Fixture({
    required this.container,
    required this.controller,
    required this.repository,
    required this.messages,
  });

  final ProviderContainer container;
  final KnowledgePackAdminController controller;
  final _PollingRepository repository;
  final List<String> messages;
}

class _RecordingSnackBars extends SnackBarDispatcher {
  final List<String> messages = <String>[];

  @override
  void show(AppNavigator navigator, String content) {
    messages.add(content);
  }
}

class _PollingRepository extends FakeAcpAdminRepository {
  _PollingRepository(List<Result<AcpRow>> projectionResults)
    : projectionResults = Queue<Result<AcpRow>>.from(projectionResults);

  final Queue<Result<AcpRow>> projectionResults;
  int projectionFetchCalls = 0;
  String? lastProjectionTenantId;

  @override
  Future<Result<AcpRowPage>> listRows({
    required AcpResourceDescriptor descriptor,
    required PageRequest pageRequest,
    String? tenantId,
    String? searchTerm,
    List<String> extraFilters = const <String>[],
    AcpDeletedView deletedView = AcpDeletedView.active,
    bool enrichReferences = true,
  }) async {
    final rows = switch (descriptor.entitySet) {
      'KnowledgePacks' => const <AcpRow>[
        <String, Object?>{
          'Id': 'pack-1',
          'CurrentVersionId': 'version-current',
        },
      ],
      'KnowledgePackVersions' => const <AcpRow>[
        <String, Object?>{
          'Id': 'version-next',
          'RowVersion': 7,
          'Status': 'approved',
          'KnowledgePack': <String, Object?>{
            'CurrentVersionId': 'version-current',
          },
        },
      ],
      _ => const <AcpRow>[],
    };
    return Result<AcpRowPage>.success(
      AcpRowPage(
        items: rows,
        total: rows.length,
        page: pageRequest.page,
        pageSize: pageRequest.pageSize,
      ),
    );
  }

  @override
  Future<Result<AcpRow>> fetchRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
  }) async {
    if (descriptor.entitySet != 'KnowledgeIndexProjections') {
      return Result<AcpRow>.success(<String, Object?>{
        'Id': rowId,
        'RowVersion': 7,
        'Status': 'approved',
        'KnowledgePack': const <String, Object?>{
          'CurrentVersionId': 'version-current',
        },
      });
    }
    projectionFetchCalls += 1;
    lastProjectionTenantId = tenantId;
    if (projectionResults.isEmpty) {
      return Result<AcpRow>.success(
        _projection(status: 'ready', isCurrentReady: true),
      );
    }
    return projectionResults.removeFirst();
  }
}
