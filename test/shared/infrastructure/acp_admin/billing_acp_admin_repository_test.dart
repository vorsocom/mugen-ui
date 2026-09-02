import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/billing_acp_admin_repository.dart';

import '../../../test_support/fake_acp_admin_repository.dart';

void main() {
  test(
    'enriches direct, Price, code, and invoice currency relationships',
    () async {
      final delegate = _MetadataRepository()
        ..pages['BillingCurrencyDefinitions'] = <AcpRow>[
          <String, Object?>{
            'Id': 'currency-usd',
            'Code': 'usd',
            'MinorUnit': 2,
          },
          <String, Object?>{
            'Id': 'currency-jpy',
            'Code': 'JPY',
            'MinorUnit': '0',
          },
        ]
        ..pages['BillingPrices'] = <AcpRow>[
          <String, Object?>{
            'Id': 'price-1',
            'CurrencyDefinitionId': 'currency-usd',
          },
        ]
        ..pages['BillingPayments'] = <AcpRow>[
          <String, Object?>{
            'Id': 'payment-1',
            'CurrencyDefinitionId': 'currency-usd',
            'Currency': 'usd',
            'Amount': 1999,
          },
          <String, Object?>{
            'Id': 'payment-2',
            'Currency': 'JPY',
            'Amount': 250,
          },
          <String, Object?>{
            'Id': 'payment-3',
            'PriceId': 'price-1',
            'Amount': 500,
          },
        ]
        ..referenceWarnings['BillingPayments'] =
            'Some reference labels could not be resolved: Account.'
        ..pages['BillingInvoices'] = <AcpRow>[
          <String, Object?>{
            'Id': 'invoice-1',
            'CurrencyDefinitionId': 'currency-jpy',
            'Currency': 'jpy',
          },
        ]
        ..pages['BillingInvoiceLines'] = <AcpRow>[
          <String, Object?>{
            'Id': 'line-1',
            'InvoiceId': 'invoice-1',
            'Amount': 900,
          },
        ];
      final repository = BillingAcpAdminRepository(delegate);

      final payments = await repository.listRows(
        descriptor: _descriptor('BillingPayments'),
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: 'tenant-1',
      );
      expect(payments.data!.items[0]['_CurrencyMinorUnit'], 2);
      expect(payments.data!.items[0]['_CurrencyCode'], 'USD');
      expect(payments.data!.items[1]['_CurrencyMinorUnit'], 0);
      expect(payments.data!.items[1]['_CurrencyCode'], 'JPY');
      expect(payments.data!.items[2]['_CurrencyMinorUnit'], 2);
      expect(payments.data!.referenceWarning, contains('Account'));

      final lines = await repository.listRows(
        descriptor: _descriptor('BillingInvoiceLines'),
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: 'tenant-1',
      );
      expect(lines.data!.items.single['_CurrencyMinorUnit'], 0);
      expect(lines.data!.items.single['_CurrencyCode'], 'JPY');
      expect(
        delegate.calls.where(
          (call) => call.entitySet == 'BillingCurrencyDefinitions',
        ),
        hasLength(1),
        reason: 'global metadata is cached',
      );
      expect(
        delegate.calls
            .firstWhere(
              (call) => call.entitySet == 'BillingCurrencyDefinitions',
            )
            .deletedView,
        AcpDeletedView.active,
        reason: 'currency definitions do not support archived collection views',
      );
      expect(
        delegate.calls
            .firstWhere((call) => call.entitySet == 'BillingPrices')
            .deletedView,
        AcpDeletedView.all,
      );
      expect(
        delegate.calls
            .firstWhere((call) => call.entitySet == 'BillingInvoices')
            .tenantId,
        'tenant-1',
      );
      expect(
        delegate.calls
            .firstWhere((call) => call.entitySet == 'BillingInvoices')
            .deletedView,
        AcpDeletedView.active,
        reason: 'invoices do not support archived collection views',
      );
    },
  );

  test('fetchRow enriches values and preserves delegate failures', () async {
    final delegate = _MetadataRepository()
      ..pages['BillingCurrencyDefinitions'] = <AcpRow>[
        <String, Object?>{'Id': 'currency-kwd', 'Code': 'KWD', 'MinorUnit': 3},
      ]
      ..pages['BillingPrices'] = <AcpRow>[]
      ..pages['BillingInvoices'] = <AcpRow>[
        <String, Object?>{
          'Id': 'invoice-1',
          'CurrencyDefinitionId': 'currency-kwd',
          'Currency': 'KWD',
        },
      ]
      ..rows['payment-1'] = <String, Object?>{
        'Id': 'payment-1',
        'CurrencyDefinitionId': 'currency-kwd',
        'Currency': 'KWD',
      }
      ..rows['line-1'] = <String, Object?>{
        'Id': 'line-1',
        'InvoiceId': 'invoice-1',
      };
    final repository = BillingAcpAdminRepository(delegate);

    final result = await repository.fetchRow(
      descriptor: _descriptor('BillingPayments'),
      rowId: 'payment-1',
      tenantId: 'tenant-1',
    );
    expect(result.data!['_CurrencyMinorUnit'], 3);
    expect(result.data!['_CurrencyCode'], 'KWD');

    final line = await repository.fetchRow(
      descriptor: _descriptor('BillingInvoiceLines'),
      rowId: 'line-1',
      tenantId: 'tenant-1',
    );
    expect(line.data!['_CurrencyMinorUnit'], 3);
    expect(line.data!['_CurrencyCode'], 'KWD');

    delegate.failedRowIds.add('missing');
    final failure = await repository.fetchRow(
      descriptor: _descriptor('BillingPayments'),
      rowId: 'missing',
      tenantId: 'tenant-1',
    );
    expect(failure.failure, isA<ApiFailure>());
  });

  test(
    'metadata failures degrade safely without failing the requested list',
    () async {
      final delegate = _MetadataRepository()
        ..pages['BillingPayments'] = <AcpRow>[
          <String, Object?>{'Id': 'payment-1', 'Currency': 'ZZZ'},
        ]
        ..failedEntitySets.addAll(<String>[
          'BillingCurrencyDefinitions',
          'BillingPrices',
          'BillingInvoices',
        ]);
      final repository = BillingAcpAdminRepository(delegate);

      final result = await repository.listRows(
        descriptor: _descriptor('BillingPaymentAllocations'),
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: 'tenant-1',
      );
      expect(result.isSuccess, isTrue);
      expect(result.data!.items, isEmpty);

      delegate.failedEntitySets.add('BillingPayments');
      final requestedFailure = await repository.listRows(
        descriptor: _descriptor('BillingPayments'),
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: 'tenant-1',
      );
      expect(requestedFailure.failure, isA<ApiFailure>());
    },
  );

  test('forwards mutations and invalidates affected metadata caches', () async {
    final delegate = _MetadataRepository()
      ..pages['BillingCurrencyDefinitions'] = <AcpRow>[]
      ..pages['BillingPrices'] = <AcpRow>[]
      ..pages['BillingInvoices'] = <AcpRow>[]
      ..pages['BillingPayments'] = <AcpRow>[]
      ..pages['BillingPaymentAllocations'] = <AcpRow>[];
    final repository = BillingAcpAdminRepository(delegate);
    const action = AcpActionDescriptor(
      name: 'activate',
      label: 'Activate',
      target: AcpActionTarget.entity,
    );
    final prices = _descriptor('BillingPrices');
    final payments = _descriptor('BillingPayments');

    expect(
      (await repository.fetchTenants(top: 5)).data,
      hasLength(delegate.tenants.length),
    );
    await repository.listRows(
      descriptor: _descriptor('BillingPaymentAllocations'),
      pageRequest: const PageRequest(page: 1, pageSize: 15),
      tenantId: 'tenant-1',
    );
    await repository.createRow(
      descriptor: _descriptor('BillingCurrencyDefinitions'),
      values: const <String, Object?>{'Code': 'USD'},
    );
    await repository.updateRow(
      descriptor: prices,
      rowId: 'price-1',
      values: const <String, Object?>{'Code': 'MONTHLY'},
      tenantId: 'tenant-1',
      rowVersion: 2,
    );
    await repository.deleteRow(
      descriptor: payments,
      rowId: 'payment-1',
      tenantId: 'tenant-1',
      rowVersion: 2,
    );
    await repository.restoreRow(
      descriptor: payments,
      rowId: 'payment-1',
      tenantId: 'tenant-1',
      rowVersion: 3,
    );
    await repository.runCollectionAction(
      descriptor: payments,
      action: action,
      values: const <String, Object?>{},
      tenantId: 'tenant-1',
    );
    await repository.runEntityAction(
      descriptor: payments,
      action: action,
      rowId: 'payment-1',
      values: const <String, Object?>{},
      tenantId: 'tenant-1',
      rowVersion: 4,
    );
    await repository.listRows(
      descriptor: _descriptor('BillingPaymentAllocations'),
      pageRequest: const PageRequest(page: 1, pageSize: 15),
      tenantId: 'tenant-1',
    );

    expect(delegate.createPayloads, hasLength(1));
    expect(delegate.updateCalls, 1);
    expect(delegate.deleteCalls, 1);
    expect(delegate.restoreCalls, 1);
    expect(delegate.collectionActionCalls, 1);
    expect(delegate.entityActionCalls, 1);
    expect(
      delegate.calls.where(
        (call) => call.entitySet == 'BillingCurrencyDefinitions',
      ),
      hasLength(2),
      reason: 'currency and Price mutations invalidate global metadata',
    );
    expect(
      delegate.calls.where((call) => call.entitySet == 'BillingInvoices'),
      hasLength(2),
      reason: 'tenant mutations invalidate inferred invoice metadata',
    );
  });
}

AcpResourceDescriptor _descriptor(String entitySet) {
  return AcpResourceDescriptor(
    key: entitySet,
    title: entitySet,
    entitySet: entitySet,
    scopeMode:
        entitySet == 'BillingCurrencyDefinitions' ||
            entitySet == 'BillingPrices'
        ? AcpScopeMode.none
        : AcpScopeMode.required,
    columns: const <AcpColumnDescriptor>[],
  );
}

typedef _ListCall = ({
  String entitySet,
  String? tenantId,
  AcpDeletedView deletedView,
});

class _MetadataRepository extends FakeAcpAdminRepository {
  final Map<String, List<AcpRow>> pages = <String, List<AcpRow>>{};
  final Map<String, String> referenceWarnings = <String, String>{};
  final Map<String, AcpRow> rows = <String, AcpRow>{};
  final Set<String> failedEntitySets = <String>{};
  final Set<String> failedRowIds = <String>{};
  final List<_ListCall> calls = <_ListCall>[];
  int updateCalls = 0;
  int deleteCalls = 0;
  int restoreCalls = 0;
  int entityActionCalls = 0;

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
    calls.add((
      entitySet: descriptor.entitySet,
      tenantId: tenantId,
      deletedView: deletedView,
    ));
    if (failedEntitySets.contains(descriptor.entitySet)) {
      return const Result<AcpRowPage>.failure(
        ApiFailure(503, 'metadata unavailable'),
      );
    }
    final items = pages[descriptor.entitySet] ?? const <AcpRow>[];
    return Result<AcpRowPage>.success(
      AcpRowPage(
        items: items,
        total: items.length,
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
    if (failedRowIds.contains(rowId)) {
      return const Result<AcpRow>.failure(ApiFailure(404, 'not found'));
    }
    return Result<AcpRow>.success(
      rows[rowId] ?? <String, Object?>{'Id': rowId},
    );
  }

  @override
  Future<Result<Object?>> updateRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    required Map<String, dynamic> values,
    String? tenantId,
    int? rowVersion,
  }) async {
    updateCalls += 1;
    return super.updateRow(
      descriptor: descriptor,
      rowId: rowId,
      values: values,
      tenantId: tenantId,
      rowVersion: rowVersion,
    );
  }

  @override
  Future<Result<void>> deleteRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
    int? rowVersion,
  }) async {
    deleteCalls += 1;
    return super.deleteRow(
      descriptor: descriptor,
      rowId: rowId,
      tenantId: tenantId,
      rowVersion: rowVersion,
    );
  }

  @override
  Future<Result<void>> restoreRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
    int? rowVersion,
  }) async {
    restoreCalls += 1;
    return super.restoreRow(
      descriptor: descriptor,
      rowId: rowId,
      tenantId: tenantId,
      rowVersion: rowVersion,
    );
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
    entityActionCalls += 1;
    return super.runEntityAction(
      descriptor: descriptor,
      action: action,
      rowId: rowId,
      values: values,
      tenantId: tenantId,
      rowVersion: rowVersion,
    );
  }
}
