import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/billing_catalog/application/billing_catalog_admin_controller.dart';
import 'package:mugen_ui/features/billing_catalog/application/billing_catalog_resources.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';

import '../../../test_support/fake_acp_admin_repository.dart';

void main() {
  test('catalog exposes all normalized global resources without deletion', () {
    expect(
      billingCatalogResources.map((resource) => resource.entitySet),
      <String>[
        'BillingProducts',
        'BillingPrices',
        'BillingMeterDefinitions',
        'BillingPriceEntitlements',
        'BillingRunDefinitions',
        'BillingCurrencyDefinitions',
        'BillingTaxCodes',
        'BillingTaxRates',
        'BillingPaymentTerms',
        'BillingInvoiceTemplates',
        'BillingDiscountDefinitions',
      ],
    );
    expect(
      billingCatalogResources.every(
        (resource) =>
            resource.scopeMode == AcpScopeMode.none && !resource.allowDelete,
      ),
      isTrue,
    );
    expect(
      billingCatalogResources
          .expand(
            (resource) => <AcpFieldDescriptor>[
              ...resource.createFields,
              ...resource.updateFields,
            ],
          )
          .any((field) => field.key == 'TenantId'),
      isFalse,
    );
    expect(_resource('BillingCurrencyDefinitions').allowCreate, isFalse);
  });

  test('meter lifecycle and Price meter relationships are canonical', () {
    final meters = _resource('BillingMeterDefinitions');
    expect(meters.allowCreate, isTrue);
    expect(meters.allowUpdate, isTrue);
    expect(meters.entityActions.map((action) => action.name), <String>[
      'activate',
      'deactivate',
    ]);
    expect(
      meters.entityActions.every((action) => action.includeRowVersion),
      isTrue,
    );
    expect(
      meters.entityActions.first.isVisibleFor(<String, Object?>{
        'IsActive': false,
      }),
      isTrue,
    );
    expect(
      meters.entityActions.last.isVisibleFor(<String, Object?>{
        'IsActive': true,
      }),
      isTrue,
    );

    final prices = _resource('BillingPrices');
    final meter = _field(prices.createFields, 'MeterDefinitionId');
    final currency = _field(prices.createFields, 'CurrencyDefinitionId');
    expect(meter.reference?.scopeMode, AcpScopeMode.none);
    expect(meter.reference?.extraFilters, <String>['IsActive eq true']);
    expect(meter.visibleWhenEquals, <String, List<Object>>{
      'PriceType': <Object>['metered'],
    });
    expect(meter.clearWhenHidden, isTrue);
    expect(meter.submitNullWhenHidden, isTrue);
    expect(currency.reference?.extraFilters, <String>['IsActive eq true']);
    expect(
      currency.reference?.copyFieldsFromSelection,
      containsPair('MinorUnit', '_CurrencyMinorUnit'),
    );
    expect(_field(prices.createFields, 'UnitAmount').kind, AcpFieldKind.money);
    expect(
      prices.updateFields.any(
        (field) => field.key == 'MeterCode' || field.key == 'UsageUnit',
      ),
      isFalse,
    );
    expect(
      prices.columns.map((column) => column.key),
      containsAll(<String>['MeterCode', 'UsageUnit']),
    );
    expect(prices.deletedViews, AcpDeletedView.values);
  });

  test('Price Entitlements constrain packages, meters, and allowances', () {
    final entitlements = _resource('BillingPriceEntitlements');
    final price = _field(entitlements.createFields, 'PriceId');
    final meter = _field(entitlements.createFields, 'MeterDefinitionId');
    final included = _field(entitlements.createFields, 'IncludedQuantity');

    expect(price.reference?.extraFilters, <String>["PriceType eq 'recurring'"]);
    expect(price.reference?.retainHistoricalSelection, isTrue);
    expect(meter.reference?.extraFilters, <String>['IsActive eq true']);
    expect(included.kind, AcpFieldKind.integer);
    expect(included.minimumValue, 0);
    expect(
      _field(entitlements.createFields, 'RolloverPolicy').options,
      <String>['none'],
    );
    expect(entitlements.allowRestore, isFalse);
    expect(entitlements.entityActions.single.name, 'archive');
  });

  test('global payload validators preserve commercial boundaries', () {
    expect(
      validateGlobalBillingPayload(<String, Object?>{'TenantId': 'tenant-1'}),
      contains('cannot contain TenantId'),
    );
    expect(validateGlobalBillingPayload(const <String, Object?>{}), isNull);
    expect(
      validateGlobalBillingPayload(<String, Object?>{
        'Attributes': <String, Object?>{
          'safe': <Object?>[
            <String, Object?>{'customer_email': 'private@example.test'},
          ],
        },
      }),
      contains('safe[0].customer_email'),
    );
    expect(
      validateGlobalBillingPayload(<String, Object?>{
        'Attributes': <String, Object?>{'tier': 1},
      }),
      isNull,
    );

    expect(
      validateBillingPricePayload(<String, Object?>{'PriceType': 'metered'}),
      contains('require an active global Meter Definition'),
    );
    expect(
      validateBillingPricePayload(<String, Object?>{
        'PriceType': 'recurring',
        'MeterDefinitionId': 'meter-1',
      }),
      contains('must not retain'),
    );
    expect(
      validateBillingPricePayload(<String, Object?>{
        'PriceType': 'recurring',
        'Attributes': <String, Object?>{'included_usage': 100},
      }),
      contains('Price Entitlements'),
    );
    expect(
      validateBillingPricePayload(<String, Object?>{
        'PriceType': 'metered',
        'MeterDefinitionId': 'meter-1',
      }),
      isNull,
    );
    expect(
      validateBillingPricePayload(<String, Object?>{
        'PriceType': 'metered',
        'MeterDefinitionId': 'meter-1',
        'TenantId': 'tenant-1',
      }),
      contains('TenantId'),
    );

    expect(
      validateTaxRatePayload(<String, Object?>{
        'EffectiveFrom': '2026-08-28T00:00:00Z',
        'EffectiveTo': '2026-08-27T00:00:00Z',
      }),
      'EffectiveTo must be later than EffectiveFrom.',
    );
    expect(
      validateTaxRatePayload(<String, Object?>{
        'EffectiveFrom': '2026-08-27T00:00:00Z',
        'EffectiveTo': '2026-08-28T00:00:00Z',
      }),
      isNull,
    );
    expect(
      validateTaxRatePayload(<String, Object?>{'TenantId': 'tenant-1'}),
      contains('TenantId'),
    );

    expect(
      validateDiscountPayload(<String, Object?>{'Kind': 'percentage'}),
      contains('Percentage Basis Points'),
    );
    expect(
      validateDiscountPayload(<String, Object?>{'Kind': 'fixed_amount'}),
      contains('Amount and Currency'),
    );
    expect(
      validateDiscountPayload(<String, Object?>{
        'Kind': 'percentage',
        'PercentageBasisPoints': 500,
        'Amount': 100,
      }),
      contains('must omit Amount and Currency'),
    );
    expect(
      validateDiscountPayload(<String, Object?>{
        'Kind': 'fixed_amount',
        'Amount': 100,
        'CurrencyDefinitionId': 'usd',
        'PercentageBasisPoints': 500,
      }),
      contains('must omit Percentage Basis Points'),
    );
    expect(
      validateDiscountPayload(<String, Object?>{
        'Kind': 'fixed_amount',
        'Amount': 100,
        'CurrencyDefinitionId': 'usd',
        'ValidFrom': '2026-08-28T00:00:00Z',
        'ValidUntil': '2026-08-27T00:00:00Z',
      }),
      contains('ValidUntil'),
    );
    expect(
      validateDiscountPayload(<String, Object?>{
        'Kind': 'fixed_amount',
        'Amount': 100,
        'CurrencyDefinitionId': 'usd',
      }),
      isNull,
    );
    expect(
      validateDiscountPayload(<String, Object?>{
        'Kind': 'percentage',
        'PercentageBasisPoints': 500,
        'TenantId': 'tenant-1',
      }),
      contains('TenantId'),
    );
  });

  test('controller preflights duplicate Price and meter pairs', () async {
    final repository = _CatalogRepository();
    final controller = BillingCatalogAdminController(
      repository: repository,
      onSessionExpired: () {},
    );
    addTearDown(controller.dispose);
    await controller.selectResource('billing-price-entitlements');

    final duplicate = await controller.createRow(<String, Object?>{
      'PriceId': "price'1",
      'MeterDefinitionId': 'meter-1',
      'IncludedQuantity': 10,
    });
    expect(duplicate.failure, isA<ValidationFailure>());
    expect(repository.createPayloads, isEmpty);
    expect(repository.lastFilters, <String>[
      "PriceId eq 'price''1'",
      "MeterDefinitionId eq 'meter-1'",
    ]);

    final duplicateUpdate = await controller.updateRow(
      rowId: 'different-entitlement',
      values: const <String, Object?>{
        'PriceId': 'price-1',
        'MeterDefinitionId': 'meter-1',
      },
      rowVersion: 2,
    );
    expect(duplicateUpdate.failure, isA<ValidationFailure>());

    final update = await controller.updateRow(
      rowId: 'BillingPriceEntitlements-1',
      values: const <String, Object?>{
        'PriceId': 'price-1',
        'MeterDefinitionId': 'meter-1',
      },
      rowVersion: 3,
    );
    expect(update.isSuccess, isTrue);

    repository.listRowsResult = const Result<AcpRowPage>.failure(
      ApiFailure(503, 'catalog unavailable'),
    );
    final authoritative = await controller.createRow(const <String, Object?>{
      'PriceId': 'price-2',
      'MeterDefinitionId': 'meter-2',
    });
    expect(authoritative.isSuccess, isTrue);
    expect(repository.createPayloads, hasLength(1));
  });

  test(
    'controller bypasses entitlement preflight for other resources',
    () async {
      final repository = _CatalogRepository();
      final controller = BillingCatalogAdminController(
        repository: repository,
        onSessionExpired: () {},
      );
      addTearDown(controller.dispose);

      final result = await controller.createRow(const <String, Object?>{
        'Code': 'PRO',
        'Name': 'Professional',
      });

      expect(result.isSuccess, isTrue);
      expect(repository.createPayloads, hasLength(1));
    },
  );
}

AcpResourceDescriptor _resource(String entitySet) {
  return billingCatalogResources.firstWhere(
    (resource) => resource.entitySet == entitySet,
  );
}

AcpFieldDescriptor _field(List<AcpFieldDescriptor> fields, String key) {
  return fields.firstWhere((field) => field.key == key);
}

class _CatalogRepository extends FakeAcpAdminRepository {
  List<String> lastFilters = <String>[];

  @override
  Future<Result<AcpRowPage>> listRows({
    required AcpResourceDescriptor descriptor,
    required PageRequest pageRequest,
    String? tenantId,
    String? searchTerm,
    List<String> extraFilters = const <String>[],
    AcpDeletedView deletedView = AcpDeletedView.active,
    bool enrichReferences = true,
  }) {
    lastFilters = List<String>.from(extraFilters);
    return super.listRows(
      descriptor: descriptor,
      pageRequest: pageRequest,
      tenantId: tenantId,
      searchTerm: searchTerm,
      extraFilters: extraFilters,
      deletedView: deletedView,
    );
  }
}
