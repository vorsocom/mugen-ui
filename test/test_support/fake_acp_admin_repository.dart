import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_repository.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class FakeAcpAdminRepository implements AcpAdminRepository {
  FakeAcpAdminRepository({
    this.tenants = const <AcpTenantOption>[
      AcpTenantOption(id: 'global-id', name: 'Global', slug: 'global'),
      AcpTenantOption(id: 'tenant-1', name: 'Tenant One', slug: 'tenant-one'),
    ],
  });

  final List<AcpTenantOption> tenants;
  Result<AcpRowPage> listRowsResult = const Result<AcpRowPage>.success(
    AcpRowPage(items: <AcpRow>[], total: 1, page: 1, pageSize: 15),
  );
  Result<Object?> createResult = const Result<Object?>.success(
    <String, Object?>{'ok': true},
  );
  Result<Object?> updateResult = const Result<Object?>.success(
    <String, Object?>{'ok': true},
  );
  Result<void> deleteResult = const Result<void>.success(null);
  Result<void> restoreResult = const Result<void>.success(null);
  Result<Object?> collectionActionResult = const Result<Object?>.success(
    <String, Object?>{'action': 'ok'},
  );
  Result<Object?> entityActionResult = const Result<Object?>.success(
    <String, Object?>{'action': 'ok'},
  );

  final List<Map<String, dynamic>> createPayloads = <Map<String, dynamic>>[];
  int collectionActionCalls = 0;

  @override
  Future<Result<List<AcpTenantOption>>> fetchTenants({int top = 200}) async {
    return Result<List<AcpTenantOption>>.success(tenants);
  }

  @override
  Future<Result<AcpRowPage>> listRows({
    required AcpResourceDescriptor descriptor,
    required PageRequest pageRequest,
    String? tenantId,
    String? searchTerm,
    List<String> extraFilters = const <String>[],
  }) async {
    if (listRowsResult.isFailure) {
      return Result<AcpRowPage>.failure(listRowsResult.failure!);
    }

    return Result<AcpRowPage>.success(
      AcpRowPage(
        items: <AcpRow>[
          <String, Object?>{
            'Id': '${descriptor.entitySet}-1',
            'TenantId': tenantId,
            'RowVersion': 1,
            'Name': descriptor.title,
          },
        ],
        total: listRowsResult.data?.total ?? 1,
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
    return Result<AcpRow>.success(<String, Object?>{
      'Id': rowId,
      'TenantId': tenantId,
      'RowVersion': 1,
      'Name': descriptor.title,
    });
  }

  @override
  Future<Result<Object?>> createRow({
    required AcpResourceDescriptor descriptor,
    required Map<String, dynamic> values,
    String? tenantId,
  }) async {
    createPayloads.add(Map<String, dynamic>.from(values));
    return createResult;
  }

  @override
  Future<Result<void>> deleteRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
    int? rowVersion,
  }) async {
    return deleteResult;
  }

  @override
  Future<Result<void>> restoreRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
    int? rowVersion,
  }) async {
    return restoreResult;
  }

  @override
  Future<Result<Object?>> runCollectionAction({
    required AcpResourceDescriptor descriptor,
    required AcpActionDescriptor action,
    required Map<String, dynamic> values,
    String? tenantId,
  }) async {
    collectionActionCalls += 1;
    if (collectionActionResult.isFailure &&
        collectionActionResult.failure is SessionExpiredFailure) {
      return collectionActionResult;
    }

    return collectionActionResult.isFailure
        ? Result<Object?>.failure(collectionActionResult.failure!)
        : collectionActionResult;
  }

  @override
  Future<Result<Object?>> runEntityAction({
    required AcpResourceDescriptor descriptor,
    required AcpActionDescriptor action,
    required String rowId,
    required Map<String, dynamic> values,
    String? tenantId,
    int? rowVersion,
  }) async {
    return entityActionResult.isFailure
        ? Result<Object?>.failure(entityActionResult.failure!)
        : entityActionResult;
  }

  @override
  Future<Result<Object?>> updateRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    required Map<String, dynamic> values,
    String? tenantId,
    int? rowVersion,
  }) async {
    return updateResult;
  }
}
