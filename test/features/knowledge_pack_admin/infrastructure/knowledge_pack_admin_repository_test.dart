import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/knowledge_pack_admin/application/knowledge_pack_admin_resources.dart';
import 'package:mugen_ui/features/knowledge_pack_admin/infrastructure/knowledge_pack_admin_repository.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';

import '../../../test_support/fake_acp_admin_repository.dart';

void main() {
  late _RepositoryDelegate delegate;
  late KnowledgePackAdminRepository repository;
  late AcpResourceDescriptor projectionDescriptor;
  late AcpResourceDescriptor versionDescriptor;
  late AcpResourceDescriptor packDescriptor;

  setUp(() {
    delegate = _RepositoryDelegate();
    projectionDescriptor = _descriptor('KnowledgeIndexProjections');
    versionDescriptor = _descriptor('KnowledgePackVersions');
    packDescriptor = _descriptor('KnowledgePacks');
    repository = KnowledgePackAdminRepository(
      delegate: delegate,
      projectionDescriptor: projectionDescriptor,
    );
  });

  test(
    'projection rows expose operational fields but strip unsafe internals',
    () async {
      delegate.pages['KnowledgeIndexProjections'] = <AcpRow>[
        _projection(
          id: 'projection-1',
          versionId: 'version-1',
          status: 'failed',
          failureDetail:
              'token=secret https://internal.example /home/operator/config',
        )..addAll(<String, Object?>{
          'RequestPayload': <String, Object?>{'note': 'private'},
          'LeaseOwner': 'worker-host-1',
          'LeaseExpiresAt': 'later',
        }),
      ];

      final result = await repository.listRows(
        descriptor: projectionDescriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: 'tenant-1',
      );

      final row = result.data!.items.single;
      expect(row, isNot(contains('RequestPayload')));
      expect(row, isNot(contains('LeaseOwner')));
      expect(row, isNot(contains('LeaseExpiresAt')));
      expect(row['FailureDetail'], contains('[credential redacted]'));
      expect(row['FailureDetail'], contains('[endpoint]'));
      expect(row['FailureDetail'], contains('[path]'));
      expect(row['AttemptSummary'], '1/3');
      expect(row['LastCompletedOrFailedAt'], '2026-09-01T02:00:00Z');
      expect(row['ActiveTargetMatch'], 'No');
    },
  );

  test(
    'version enrichment distinguishes lifecycle and projection readiness',
    () async {
      delegate.pages['KnowledgePackVersions'] = <AcpRow>[
        _version('current', status: 'published', currentId: 'current'),
        _version('stale', status: 'published', currentId: 'current'),
        _version('pending', status: 'approved', currentId: 'current'),
        _version('reindexing', status: 'published', currentId: 'current'),
        _version('failed', status: 'published', currentId: 'current'),
        _version('cancelled', status: 'published', currentId: 'current'),
        _version('relational', status: 'published', currentId: 'current'),
        _version('historical', status: 'archived', currentId: 'current'),
      ];
      delegate.pages['KnowledgeIndexProjections'] = <AcpRow>[
        _projection(
          id: 'old-pending',
          versionId: 'pending',
          status: 'ready',
          requestedAt: '2026-08-01T00:00:00Z',
          isCurrentReady: true,
        ),
        _projection(
          id: 'current-ready',
          versionId: 'current',
          status: 'ready',
          isCurrentReady: true,
        ),
        _projection(id: 'stale-ready', versionId: 'stale', status: 'ready'),
        _projection(
          id: 'new-pending',
          versionId: 'pending',
          status: 'queued',
          requestedAt: '2026-09-02T00:00:00Z',
        ),
        _projection(
          id: 'reindexing',
          versionId: 'reindexing',
          status: 'processing',
          operation: 'reindex',
        ),
        _projection(id: 'failed', versionId: 'failed', status: 'failed'),
        _projection(
          id: 'cancelled',
          versionId: 'cancelled',
          status: 'cancelled',
        ),
      ];

      final result = await repository.listRows(
        descriptor: versionDescriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: 'tenant-1',
      );
      final rows = <String, AcpRow>{
        for (final row in result.data!.items) row.id!: row,
      };

      expect(rows['current']!['IsCurrentVersion'], 'Current');
      expect(rows['current']!['ProjectionStatus'], 'Searchable');
      expect(rows['current']!['ProjectionMatchesActive'], 'Yes');
      expect(
        rows['stale']!['ProjectionStatus'],
        'Stale provider configuration',
      );
      expect(rows['pending']!['ProjectionStatus'], 'Queued');
      expect(rows['pending']!['HasActiveProjection'], isTrue);
      expect(rows['pending']!['CanRollback'], isFalse);
      expect(rows['reindexing']!['ProjectionStatus'], 'Reindexing');
      expect(rows['failed']!['ProjectionStatus'], 'Failed');
      expect(rows['cancelled']!['ProjectionStatus'], 'Cancelled');
      expect(rows['relational']!['ProjectionStatus'], 'Relational only');
      expect(rows['relational']!['CanReindex'], isTrue);
      expect(rows['historical']!['CanRollback'], isTrue);
      expect(rows['historical']!['IsPublishedOrIndexing'], isFalse);
      expect(rows['current']!['ProjectionTarget'], startsWith('generic · '));
      expect(rows['current']!['ProjectionDocumentCount'], 4);
      expect(rows['current']!['ProjectionApiAvailable'], isTrue);
    },
  );

  test(
    'pack summary preserves relational current while staging replacement',
    () async {
      delegate.pages['KnowledgePacks'] = <AcpRow>[
        <String, Object?>{
          'Id': 'pack-1',
          'CurrentVersionId': 'version-current',
        },
        <String, Object?>{'Id': 'pack-2'},
      ];
      delegate.pages['KnowledgeIndexProjections'] = <AcpRow>[
        _projection(
          id: 'ready',
          packId: 'pack-1',
          versionId: 'version-current',
          status: 'ready',
          isCurrentReady: true,
        ),
        _projection(
          id: 'pending',
          packId: 'pack-1',
          versionId: 'version-next',
          versionNumber: 9,
          status: 'processing',
        ),
        _projection(
          id: 'failed-old',
          packId: 'pack-1',
          versionId: 'version-failed',
          status: 'failed',
          failureDetail: 'Provider operation failed safely.',
        ),
      ];

      final result = await repository.listRows(
        descriptor: packDescriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: 'tenant-1',
      );
      final pack = result.data!.items.first;
      expect(pack['CurrentVersionId'], 'version-current');
      expect(pack['Searchability'], 'Searchable');
      expect(pack['PendingReplacement'], 'v9 · Indexing');
      expect(pack['ProjectionAttention'], contains('retry from Projections'));
      expect(result.data!.items.last['Searchability'], 'No current version');

      delegate.pages['KnowledgeIndexProjections'] = const <AcpRow>[];
      final notSearchable = await repository.listRows(
        descriptor: packDescriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: 'tenant-1',
      );
      expect(
        notSearchable.data!.items.first['Searchability'],
        'Published, not searchable',
      );
    },
  );

  test(
    'projection discovery failures hide controls or show actionable warning',
    () async {
      delegate.pages['KnowledgePackVersions'] = <AcpRow>[
        _version('version-1', status: 'published', currentId: 'version-1'),
      ];
      delegate.projectionFailure = const ApiFailure(404, 'not found');

      final missing = await repository.listRows(
        descriptor: versionDescriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: 'tenant-1',
      );
      expect(missing.data!.items.single['ProjectionApiAvailable'], isFalse);
      expect(missing.data!.items.single['CanReindex'], isFalse);
      expect(missing.data!.referenceWarning, isNull);

      delegate.pages['KnowledgePacks'] = const <AcpRow>[
        <String, Object?>{'Id': 'pack-1', 'CurrentVersionId': 'version-1'},
      ];
      final missingPack = await repository.listRows(
        descriptor: packDescriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: 'tenant-1',
      );
      expect(
        missingPack.data!.items.single['Searchability'],
        'Status unavailable',
      );

      delegate.projectionFailure = const ApiFailure(403, 'forbidden');
      delegate.referenceWarnings['KnowledgePackVersions'] = 'Existing warning.';
      final forbidden = await repository.listRows(
        descriptor: versionDescriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: 'tenant-1',
      );
      expect(forbidden.data!.referenceWarning, contains('Existing warning.'));
      expect(
        forbidden.data!.referenceWarning,
        contains('could not be determined reliably'),
      );
    },
  );

  test(
    'empty, unidentified, failed, and unrelated pages pass through safely',
    () async {
      delegate.listFailure = const NetworkFailure('offline');
      final failed = await repository.listRows(
        descriptor: packDescriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 15),
      );
      expect(failed.isFailure, isTrue);

      delegate.listFailure = null;
      delegate.pages['KnowledgePacks'] = const <AcpRow>[];
      final empty = await repository.listRows(
        descriptor: packDescriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 15),
      );
      expect(empty.data!.items, isEmpty);

      delegate.pages['KnowledgePacks'] = const <AcpRow>[
        <String, Object?>{'Name': 'No ID'},
      ];
      final unidentified = await repository.listRows(
        descriptor: packDescriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 15),
      );
      expect(unidentified.data!.items.single['Name'], 'No ID');

      final approvalDescriptor = _descriptor('KnowledgeApprovals');
      delegate.pages['KnowledgeApprovals'] = const <AcpRow>[
        <String, Object?>{'Id': 'approval-1'},
      ];
      final unrelated = await repository.listRows(
        descriptor: approvalDescriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 15),
      );
      expect(unrelated.data!.items.single.id, 'approval-1');
    },
  );

  test(
    'fetches enrich rows and forwards the complete repository contract',
    () async {
      delegate.fetchRows['KnowledgeIndexProjections'] = _projection(
        id: 'projection-1',
        versionId: 'version-1',
        status: 'failed',
      )..['RequestPayload'] = <String, Object?>{'secret': true};
      final projection = await repository.fetchRow(
        descriptor: projectionDescriptor,
        rowId: 'projection-1',
        tenantId: 'tenant-1',
      );
      expect(projection.data!, isNot(contains('RequestPayload')));

      delegate.fetchRows['KnowledgePackVersions'] = _version(
        'version-1',
        status: 'published',
        currentId: 'version-1',
      );
      delegate.pages['KnowledgeIndexProjections'] = <AcpRow>[
        _projection(
          id: 'ready',
          versionId: 'version-1',
          status: 'ready',
          isCurrentReady: true,
        ),
      ];
      final version = await repository.fetchRow(
        descriptor: versionDescriptor,
        rowId: 'version-1',
        tenantId: 'tenant-1',
      );
      expect(version.data!['ProjectionStatus'], 'Searchable');

      delegate.fetchFailure = const ApiFailure(404, 'missing');
      final missing = await repository.fetchRow(
        descriptor: packDescriptor,
        rowId: 'missing',
      );
      expect(missing.isFailure, isTrue);
      delegate.fetchFailure = null;

      final approvals = _descriptor('KnowledgeApprovals');
      delegate.fetchRows['KnowledgeApprovals'] = const <String, Object?>{
        'Id': 'approval-1',
      };
      expect(
        (await repository.fetchRow(
          descriptor: approvals,
          rowId: 'approval-1',
        )).data!.id,
        'approval-1',
      );

      expect((await repository.fetchTenants()).data, isNotEmpty);
      expect(
        (await repository.createRow(
          descriptor: packDescriptor,
          values: const <String, Object?>{'Name': 'Pack'},
        )).isSuccess,
        isTrue,
      );
      expect(
        (await repository.updateRow(
          descriptor: packDescriptor,
          rowId: 'pack-1',
          values: const <String, Object?>{'Name': 'Updated'},
          rowVersion: 2,
        )).isSuccess,
        isTrue,
      );
      expect(
        (await repository.deleteRow(
          descriptor: packDescriptor,
          rowId: 'pack-1',
          rowVersion: 2,
        )).isSuccess,
        isTrue,
      );
      expect(
        (await repository.restoreRow(
          descriptor: packDescriptor,
          rowId: 'pack-1',
          rowVersion: 2,
        )).isSuccess,
        isTrue,
      );
      const action = AcpActionDescriptor(
        name: 'test',
        label: 'Test',
        target: AcpActionTarget.entity,
      );
      expect(
        (await repository.runCollectionAction(
          descriptor: packDescriptor,
          action: action,
          values: const <String, Object?>{},
        )).isSuccess,
        isTrue,
      );
      expect(
        (await repository.runEntityAction(
          descriptor: packDescriptor,
          action: action,
          rowId: 'pack-1',
          values: const <String, Object?>{},
          rowVersion: 2,
        )).isSuccess,
        isTrue,
      );
    },
  );
}

AcpResourceDescriptor _descriptor(String entitySet) =>
    knowledgePackAdminResources.firstWhere(
      (descriptor) => descriptor.entitySet == entitySet,
    );

AcpRow _version(
  String id, {
  required String status,
  required String currentId,
}) => <String, Object?>{
  'Id': id,
  'Status': status,
  'KnowledgePack': <String, Object?>{'CurrentVersionId': currentId},
};

AcpRow _projection({
  required String id,
  String packId = 'pack-1',
  required String versionId,
  int? versionNumber,
  required String status,
  String operation = 'publish',
  String requestedAt = '2026-09-01T00:00:00Z',
  bool isCurrentReady = false,
  String? failureDetail,
}) => <String, Object?>{
  'Id': id,
  'KnowledgePackId': packId,
  'KnowledgePackVersionId': versionId,
  if (versionNumber != null)
    'KnowledgePackVersion': <String, Object?>{'VersionNumber': versionNumber},
  'Provider': 'generic',
  'TargetFingerprint': '12345678901234567890123456789012',
  'ContentChecksum': 'abcdef',
  'Status': status,
  'Operation': operation,
  'RequestedAt': requestedAt,
  'CompletedAt': status == 'ready' ? '2026-09-01T01:00:00Z' : null,
  'FailedAt': status == 'failed' ? '2026-09-01T02:00:00Z' : null,
  'FailureDetail': failureDetail,
  'DocumentCount': 4,
  'AttemptCount': 1,
  'MaxAttempts': 3,
  'IsCurrentReady': isCurrentReady,
  'RowVersion': 2,
};

class _RepositoryDelegate extends FakeAcpAdminRepository {
  final Map<String, List<AcpRow>> pages = <String, List<AcpRow>>{};
  final Map<String, AcpRow> fetchRows = <String, AcpRow>{};
  final Map<String, String> referenceWarnings = <String, String>{};
  Failure? listFailure;
  Failure? projectionFailure;
  Failure? fetchFailure;

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
    final failure = descriptor.entitySet == 'KnowledgeIndexProjections'
        ? projectionFailure
        : listFailure;
    if (failure != null) {
      return Result<AcpRowPage>.failure(failure);
    }
    final rows = pages[descriptor.entitySet] ?? const <AcpRow>[];
    return Result<AcpRowPage>.success(
      AcpRowPage(
        items: rows,
        total: rows.length,
        page: pageRequest.page,
        pageSize: pageRequest.pageSize,
        referenceWarning: referenceWarnings[descriptor.entitySet],
      ),
    );
  }

  @override
  Future<Result<AcpRow>> fetchRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
  }) async {
    if (fetchFailure != null) {
      return Result<AcpRow>.failure(fetchFailure!);
    }
    return Result<AcpRow>.success(
      fetchRows[descriptor.entitySet] ?? <String, Object?>{'Id': rowId},
    );
  }
}
