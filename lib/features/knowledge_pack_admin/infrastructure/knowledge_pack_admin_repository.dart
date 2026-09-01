import 'package:mugen_ui/features/knowledge_pack_admin/application/knowledge_pack_projection_status.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_repository.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class KnowledgePackAdminRepository implements AcpAdminRepository {
  KnowledgePackAdminRepository({
    required this.delegate,
    required this.projectionDescriptor,
  });

  final AcpAdminRepository delegate;
  final AcpResourceDescriptor projectionDescriptor;

  @override
  Future<Result<List<AcpTenantOption>>> fetchTenants({int top = 200}) =>
      delegate.fetchTenants(top: top);

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
    final result = await delegate.listRows(
      descriptor: descriptor,
      pageRequest: pageRequest,
      tenantId: tenantId,
      searchTerm: searchTerm,
      extraFilters: extraFilters,
      deletedView: deletedView,
      enrichReferences: enrichReferences,
    );
    if (result.isFailure) {
      return result;
    }
    final page = result.data!;
    if (descriptor.entitySet == projectionDescriptor.entitySet) {
      return Result<AcpRowPage>.success(
        _copyPage(page, rows: page.items.map(_safeProjection).toList()),
      );
    }
    if (descriptor.entitySet != 'KnowledgePackVersions' &&
        descriptor.entitySet != 'KnowledgePacks') {
      return result;
    }
    return _enrichPage(descriptor: descriptor, page: page, tenantId: tenantId);
  }

  @override
  Future<Result<AcpRow>> fetchRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
  }) async {
    final result = await delegate.fetchRow(
      descriptor: descriptor,
      rowId: rowId,
      tenantId: tenantId,
    );
    if (result.isFailure) {
      return result;
    }
    if (descriptor.entitySet == projectionDescriptor.entitySet) {
      return Result<AcpRow>.success(_safeProjection(result.data!));
    }
    if (descriptor.entitySet != 'KnowledgePackVersions' &&
        descriptor.entitySet != 'KnowledgePacks') {
      return result;
    }
    final enriched = await _enrichPage(
      descriptor: descriptor,
      page: AcpRowPage(
        items: <AcpRow>[result.data!],
        total: 1,
        page: 1,
        pageSize: 1,
      ),
      tenantId: tenantId,
    );
    return Result<AcpRow>.success(enriched.data!.items.single);
  }

  Future<Result<AcpRowPage>> _enrichPage({
    required AcpResourceDescriptor descriptor,
    required AcpRowPage page,
    required String? tenantId,
  }) async {
    if (page.items.isEmpty) {
      return Result<AcpRowPage>.success(page);
    }
    final idField = descriptor.entitySet == 'KnowledgePacks'
        ? 'KnowledgePackId'
        : 'KnowledgePackVersionId';
    final ids = page.items
        .map((row) => row.id)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty) {
      return Result<AcpRowPage>.success(page);
    }
    final projectionResult = await delegate.listRows(
      descriptor: projectionDescriptor,
      pageRequest: const PageRequest(page: 1, pageSize: 500),
      tenantId: tenantId,
      extraFilters: <String>[
        '(${ids.map((id) => "$idField eq guid'$id'").join(' or ')})',
      ],
    );
    if (projectionResult.isFailure) {
      final missingSurface = switch (projectionResult.failure) {
        ApiFailure(statusCode: 404) => true,
        _ => false,
      };
      final rows = page.items
          .map(
            (row) => descriptor.entitySet == 'KnowledgePacks'
                ? _enrichPack(row, const <AcpRow>[], apiAvailable: false)
                : _enrichVersion(row, const <AcpRow>[], apiAvailable: false),
          )
          .toList(growable: false);
      return Result<AcpRowPage>.success(
        _copyPage(
          page,
          rows: rows,
          referenceWarning: missingSurface
              ? page.referenceWarning
              : _mergeWarning(
                  page.referenceWarning,
                  'Projection status could not be determined reliably. '
                  'Refresh to retry before changing publication.',
                ),
        ),
      );
    }
    final projections =
        projectionResult.data!.items
            .map(_safeProjection)
            .toList(growable: false)
          ..sort(_newestProjectionFirst);
    final rows = page.items
        .map(
          (row) => descriptor.entitySet == 'KnowledgePacks'
              ? _enrichPack(row, projections, apiAvailable: true)
              : _enrichVersion(row, projections, apiAvailable: true),
        )
        .toList(growable: false);
    return Result<AcpRowPage>.success(_copyPage(page, rows: rows));
  }

  AcpRow _enrichVersion(
    AcpRow source,
    List<AcpRow> projections, {
    required bool apiAvailable,
  }) {
    final row = Map<String, dynamic>.from(source);
    final versionId = row.id;
    final relevant = projections
        .where(
          (item) => item['KnowledgePackVersionId']?.toString() == versionId,
        )
        .toList(growable: false);
    final projection = relevant.isEmpty ? null : relevant.first;
    final hasActive = relevant.any(knowledgeProjectionIsActive);
    final pack = _map(row['KnowledgePack']);
    final isCurrent =
        versionId != null && pack?['CurrentVersionId']?.toString() == versionId;
    final lifecycle = row['Status']?.toString().trim().toLowerCase() ?? '';
    final rollbackEligible = const <String>{
      'approved',
      'published',
      'archived',
    }.contains(lifecycle);
    row.addAll(<String, dynamic>{
      'ProjectionApiAvailable': apiAvailable,
      'IsCurrentVersion': isCurrent ? 'Current' : '',
      'ProjectionStatus': knowledgeProjectionStateLabel(projection),
      'ProjectionTarget': knowledgeProjectionTargetLabel(projection),
      'ProjectionDocumentCount': projection?['DocumentCount'] ?? '',
      'ProjectionLastAt': knowledgeProjectionLastEvent(projection),
      'ProjectionFailure': sanitizeKnowledgeProjectionFailure(
        projection?['FailureDetail'],
      ),
      'ProjectionMatchesActive': knowledgeProjectionMatchLabel(projection),
      'HasActiveProjection': hasActive,
      'CanReindex': apiAvailable && lifecycle == 'published' && !hasActive,
      'CanRollback': rollbackEligible && !isCurrent && !hasActive,
      'IsPublishedOrIndexing': isCurrent || hasActive,
    });
    return row;
  }

  AcpRow _enrichPack(
    AcpRow source,
    List<AcpRow> projections, {
    required bool apiAvailable,
  }) {
    final row = Map<String, dynamic>.from(source);
    final packId = row.id;
    final currentVersionId = row['CurrentVersionId']?.toString();
    final relevant = projections
        .where((item) => item['KnowledgePackId']?.toString() == packId)
        .toList(growable: false);
    final currentIsSearchable = relevant.any(
      (item) =>
          item['KnowledgePackVersionId']?.toString() == currentVersionId &&
          item['Status']?.toString().toLowerCase() == 'ready' &&
          item['IsCurrentReady'] == true,
    );
    AcpRow? pending;
    AcpRow? failed;
    final seenTargets = <String>{};
    for (final projection in relevant) {
      final targetKey = <Object?>[
        projection['KnowledgePackVersionId'],
        projection['Provider'],
        projection['TargetFingerprint'],
      ].join('|');
      if (seenTargets.add(targetKey) &&
          projection['Status']?.toString().toLowerCase() == 'failed') {
        failed ??= projection;
      }
      final operation = projection['Operation']?.toString().toLowerCase();
      if (pending == null &&
          knowledgeProjectionIsActive(projection) &&
          projection['KnowledgePackVersionId']?.toString() !=
              currentVersionId &&
          const <String>{'publish', 'rollback'}.contains(operation)) {
        pending = projection;
      }
    }
    final searchability = !apiAvailable
        ? 'Status unavailable'
        : currentVersionId == null || currentVersionId.isEmpty
        ? 'No current version'
        : currentIsSearchable
        ? 'Searchable'
        : 'Published, not searchable';
    row.addAll(<String, dynamic>{
      'ProjectionApiAvailable': apiAvailable,
      'Searchability': searchability,
      'PendingReplacement': pending == null
          ? ''
          : '${knowledgePackVersionLabel(pending)} · ${knowledgeProjectionStateLabel(pending)}',
      'ProjectionAttention': failed == null
          ? ''
          : 'Projection failed — retry from Projections. '
                '${sanitizeKnowledgeProjectionFailure(failed['FailureDetail'])}',
    });
    return row;
  }

  AcpRow _safeProjection(AcpRow source) {
    final row = Map<String, dynamic>.from(source)
      ..remove('RequestPayload')
      ..remove('LeaseOwner')
      ..remove('LeaseExpiresAt');
    row['FailureDetail'] = sanitizeKnowledgeProjectionFailure(
      row['FailureDetail'],
    );
    row['AttemptSummary'] =
        '${row['AttemptCount'] ?? 0}/${row['MaxAttempts'] ?? 0}';
    row['LastCompletedOrFailedAt'] = knowledgeProjectionLastEvent(row);
    row['ActiveTargetMatch'] = knowledgeProjectionMatchLabel(row);
    return row;
  }

  AcpRowPage _copyPage(
    AcpRowPage source, {
    required List<AcpRow> rows,
    String? referenceWarning,
  }) {
    return AcpRowPage(
      items: rows,
      total: source.total,
      page: source.page,
      pageSize: source.pageSize,
      referenceWarning: referenceWarning ?? source.referenceWarning,
    );
  }

  int _newestProjectionFirst(AcpRow left, AcpRow right) =>
      (right['RequestedAt']?.toString() ?? '').compareTo(
        left['RequestedAt']?.toString() ?? '',
      );

  Map<String, dynamic>? _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  String _mergeWarning(String? existing, String message) {
    final normalized = existing?.trim() ?? '';
    return normalized.isEmpty ? message : '$normalized $message';
  }

  @override
  Future<Result<Object?>> createRow({
    required AcpResourceDescriptor descriptor,
    required Map<String, dynamic> values,
    String? tenantId,
  }) => delegate.createRow(
    descriptor: descriptor,
    values: values,
    tenantId: tenantId,
  );

  @override
  Future<Result<Object?>> updateRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    required Map<String, dynamic> values,
    String? tenantId,
    int? rowVersion,
  }) => delegate.updateRow(
    descriptor: descriptor,
    rowId: rowId,
    values: values,
    tenantId: tenantId,
    rowVersion: rowVersion,
  );

  @override
  Future<Result<void>> deleteRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
    int? rowVersion,
  }) => delegate.deleteRow(
    descriptor: descriptor,
    rowId: rowId,
    tenantId: tenantId,
    rowVersion: rowVersion,
  );

  @override
  Future<Result<void>> restoreRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
    int? rowVersion,
  }) => delegate.restoreRow(
    descriptor: descriptor,
    rowId: rowId,
    tenantId: tenantId,
    rowVersion: rowVersion,
  );

  @override
  Future<Result<Object?>> runCollectionAction({
    required AcpResourceDescriptor descriptor,
    required AcpActionDescriptor action,
    required Map<String, dynamic> values,
    String? tenantId,
  }) => delegate.runCollectionAction(
    descriptor: descriptor,
    action: action,
    values: values,
    tenantId: tenantId,
  );

  @override
  Future<Result<Object?>> runEntityAction({
    required AcpResourceDescriptor descriptor,
    required AcpActionDescriptor action,
    required String rowId,
    required Map<String, dynamic> values,
    String? tenantId,
    int? rowVersion,
  }) => delegate.runEntityAction(
    descriptor: descriptor,
    action: action,
    rowId: rowId,
    values: values,
    tenantId: tenantId,
    rowVersion: rowVersion,
  );
}
