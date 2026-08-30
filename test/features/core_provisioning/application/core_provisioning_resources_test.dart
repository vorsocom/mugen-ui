import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/core_provisioning/application/billing_operations_resources.dart';
import 'package:mugen_ui/features/core_provisioning/application/connector_resources.dart';
import 'package:mugen_ui/features/core_provisioning/application/core_plugin_access_service.dart';
import 'package:mugen_ui/features/core_provisioning/application/core_provisioning_descriptors.dart';
import 'package:mugen_ui/features/core_provisioning/application/governance_resources.dart';
import 'package:mugen_ui/features/core_provisioning/application/reporting_resources.dart';
import 'package:mugen_ui/features/core_provisioning/application/sla_resources.dart';
import 'package:mugen_ui/features/core_provisioning/application/workflow_resources.dart';
import 'package:mugen_ui/features/core_provisioning/domain/entities/core_plugin_access.dart';
import 'package:mugen_ui/features/core_provisioning/domain/repositories/core_plugin_repository.dart';
import 'package:mugen_ui/features/runtime_admin/application/runtime_admin_resources.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';

void main() {
  test('core batch references preserve their required literal type', () {
    final guidReference = coreBatchReference(
      navigationPath: 'Target',
      entitySet: 'Targets',
      scopeMode: AcpScopeMode.none,
      literalType: AcpFilterLiteralType.guid,
      selectFields: const <String>['Name'],
      titleFields: const <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('Name'),
      ],
    );
    final stringReference = coreBatchReference(
      navigationPath: 'Target',
      entitySet: 'Targets',
      scopeMode: AcpScopeMode.none,
      literalType: AcpFilterLiteralType.string,
      selectFields: const <String>['Name'],
      titleFields: const <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('Name'),
      ],
    );

    expect(guidReference.batchLookup?.literalType, AcpFilterLiteralType.guid);
    expect(
      stringReference.batchLookup?.literalType,
      AcpFilterLiteralType.string,
    );
  });

  test('resource families cover the required Core entity sets and scopes', () {
    expect(
      billingOperationsResources.map((resource) => resource.entitySet),
      <String>[
        'BillingAccounts',
        'BillingSubscriptions',
        'BillingEntitlementBuckets',
        'BillingEntitlementAdjustments',
        'BillingUsageEvents',
        'BillingUsageAllocations',
        'BillingRuns',
        'BillingInvoices',
        'BillingInvoiceLines',
        'BillingCreditNotes',
        'BillingAdjustments',
        'BillingPayments',
        'BillingPaymentAllocations',
        'BillingLedgerEntries',
      ],
    );
    expect(governanceResources.map((resource) => resource.entitySet), <String>[
      'OpsPolicyDefinitions',
    ]);
    expect(workflowResources.map((resource) => resource.entitySet), <String>[
      'OpsWorkflowDefinitions',
      'OpsWorkflowVersions',
      'OpsWorkflowStates',
      'OpsWorkflowTransitions',
    ]);
    expect(slaResources.map((resource) => resource.entitySet), <String>[
      'OpsSlaPolicies',
      'OpsSlaCalendars',
      'OpsSlaTargets',
    ]);
    expect(reportingResources.map((resource) => resource.entitySet), <String>[
      'OpsReportingMetricDefinitions',
      'OpsReportingReportDefinitions',
      'OpsReportingMetricSeries',
      'OpsReportingAggregationJobs',
      'OpsReportingReportSnapshots',
    ]);
    expect(connectorResources.map((resource) => resource.entitySet), <String>[
      'OpsConnectorTypes',
      'OpsConnectorInstances',
      'OpsConnectorCallLogs',
    ]);

    final allResources = <AcpResourceDescriptor>[
      ...billingOperationsResources,
      ...governanceResources,
      ...workflowResources,
      ...slaResources,
      ...reportingResources,
      ...connectorResources,
    ];
    expect(allResources.every((resource) => !resource.allowDelete), isTrue);
    expect(
      allResources
          .where((resource) => resource.entitySet != 'OpsConnectorTypes')
          .every((resource) => resource.scopeMode == AcpScopeMode.required),
      isTrue,
    );
    expect(
      _resource(connectorResources, 'OpsConnectorTypes').scopeMode,
      AcpScopeMode.none,
    );
  });

  test('billing descriptors separate catalog adoption from operations', () {
    final buckets = _resource(
      billingOperationsResources,
      'BillingEntitlementBuckets',
    );
    final invoices = _resource(billingOperationsResources, 'BillingInvoices');
    final lines = _resource(billingOperationsResources, 'BillingInvoiceLines');
    final runs = _resource(billingOperationsResources, 'BillingRuns');

    final subscriptions = _resource(
      billingOperationsResources,
      'BillingSubscriptions',
    );
    expect(buckets.allowCreate, isFalse);
    expect(buckets.allowUpdate, isFalse);
    expect(buckets.allowDelete, isFalse);
    expect(
      buckets.columns.map((column) => column.key),
      containsAll(<String>[
        'SubscriptionId',
        'PriceId',
        'PriceEntitlementId',
        'MeterDefinitionId',
        'GenerationSource',
        'RemainingQuantity',
      ]),
    );
    final adjust = buckets.entityActions.single;
    expect(adjust.name, 'adjust');
    expect(adjust.includeRowVersion, isTrue);
    expect(_field(adjust.fields, 'Reason').required, isTrue);
    expect(_field(adjust.fields, 'BalanceImpact').kind, AcpFieldKind.computed);

    expect(
      _field(subscriptions.createFields, 'PriceId').reference?.scopeMode,
      AcpScopeMode.none,
    );
    expect(subscriptions.keyLiteralType, AcpFilterLiteralType.guid);
    final accountLookup = subscriptions.columns
        .singleWhere((column) => column.key == 'AccountId')
        .reference
        ?.batchLookup;
    final priceLookup = subscriptions.columns
        .singleWhere((column) => column.key == 'PriceId')
        .reference
        ?.batchLookup;
    expect(accountLookup?.entitySet, 'BillingAccounts');
    expect(accountLookup?.scopeMode, AcpScopeMode.required);
    expect(accountLookup?.literalType, AcpFilterLiteralType.guid);
    expect(priceLookup?.entitySet, 'BillingPrices');
    expect(priceLookup?.scopeMode, AcpScopeMode.none);
    expect(priceLookup?.deletedView, AcpDeletedView.all);
    final priceRuleLookup = buckets.columns
        .singleWhere((column) => column.key == 'PriceEntitlementId')
        .reference
        ?.batchLookup;
    final meterLookup = buckets.columns
        .singleWhere((column) => column.key == 'MeterDefinitionId')
        .reference
        ?.batchLookup;
    expect(priceRuleLookup?.entitySet, 'BillingPriceEntitlements');
    expect(priceRuleLookup?.scopeMode, AcpScopeMode.none);
    expect(priceRuleLookup?.literalType, AcpFilterLiteralType.guid);
    expect(priceRuleLookup?.deletedView, AcpDeletedView.all);
    expect(priceRuleLookup?.selectFields, <String>['IncludedQuantity']);
    expect(
      priceRuleLookup?.expansions.map((expansion) => expansion.navigation),
      <String>['Price', 'MeterDefinition'],
    );
    expect(
      priceRuleLookup?.expansions.first.expands.single.navigation,
      'Product',
    );
    expect(meterLookup?.entitySet, 'BillingMeterDefinitions');
    expect(meterLookup?.scopeMode, AcpScopeMode.none);
    expect(meterLookup?.literalType, AcpFilterLiteralType.guid);
    expect(meterLookup?.selectFields, <String>['Code', 'Description', 'Unit']);
    expect(
      billingOperationsResources.every(
        (resource) => resource.keyLiteralType == AcpFilterLiteralType.guid,
      ),
      isTrue,
    );
    expect(
      _field(subscriptions.createFields, 'PriceId').reference?.extraFilters,
      <String>["PriceType eq 'recurring'"],
    );
    expect(
      subscriptions.refreshResourceKeys,
      contains('billing-entitlement-buckets'),
    );
    expect(
      subscriptions.entityActions
          .firstWhere((action) => action.name == 'reconcile_entitlements')
          .includeRowVersion,
      isTrue,
    );
    expect(
      _field(lines.createFields, 'PriceId').reference?.scopeMode,
      AcpScopeMode.none,
    );
    expect(lines.allowDelete, isFalse);
    expect(
      _field(runs.createFields, 'DefinitionId').reference?.entitySet,
      'BillingRunDefinitions',
    );
    expect(
      runs.columns.map((column) => column.key),
      containsAll(<String>[
        'DefinitionId',
        'Status',
        'PeriodStart',
        'PeriodEnd',
        'StartedAt',
        'CompletedAt',
        'FailureDetail',
      ]),
    );
    expect(runs.entityActions.map((action) => action.name), <String>[
      'start',
      'complete',
      'fail',
      'cancel',
      'retry',
      'reconcile_entitlements',
    ]);
    expect(
      runs.entityActions.every((action) => action.includeRowVersion),
      isTrue,
    );

    expect(invoices.canUpdate(<String, dynamic>{'Status': 'draft'}), isTrue);
    expect(invoices.canUpdate(<String, dynamic>{'Status': 'issued'}), isFalse);
    expect(
      invoices.updateFields.any((field) => field.key == 'Status'),
      isFalse,
    );
    final actions = <String, AcpActionDescriptor>{
      for (final action in invoices.entityActions) action.name: action,
    };
    expect(actions.keys, <String>{'issue', 'void', 'mark_paid'});
    expect(actions.values.every((action) => action.includeRowVersion), isTrue);
    expect(
      actions['issue']!.isVisibleFor(<String, dynamic>{'Status': 'draft'}),
      isTrue,
    );
    expect(
      actions['issue']!.isVisibleFor(<String, dynamic>{'Status': 'issued'}),
      isFalse,
    );
    expect(
      actions['void']!.isVisibleFor(<String, dynamic>{'Status': 'issued'}),
      isTrue,
    );
    expect(
      actions['mark_paid']!.isVisibleFor(<String, dynamic>{'Status': 'paid'}),
      isFalse,
    );
  });

  test('billing financial suite uses typed global references and money', () {
    expect(
      billingOperationsResources.every(
        (resource) =>
            resource.scopeMode == AcpScopeMode.required &&
            !resource.allowDelete,
      ),
      isTrue,
    );
    final accounts = _resource(billingOperationsResources, 'BillingAccounts');
    final accountCurrency = _field(
      accounts.createFields,
      'CurrencyDefinitionId',
    );
    expect(accountCurrency.applyAfterCreate, isTrue);
    expect(accountCurrency.reference?.scopeMode, AcpScopeMode.none);
    expect(accountCurrency.reference?.extraFilters, <String>[
      'IsActive eq true',
    ]);

    for (final entitySet in <String>[
      'BillingInvoices',
      'BillingCreditNotes',
      'BillingAdjustments',
      'BillingPayments',
    ]) {
      final resource = _resource(billingOperationsResources, entitySet);
      expect(
        resource.updateFields.any((field) => field.key == 'Status'),
        isFalse,
        reason: '$entitySet must not edit lifecycle status',
      );
      expect(
        resource.createFields.any((field) => field.kind == AcpFieldKind.money),
        isTrue,
      );
    }

    final lines = _resource(billingOperationsResources, 'BillingInvoiceLines');
    expect(
      _field(lines.createFields, 'InvoiceId').reference?.extraFilters,
      <String>["Status eq 'draft'"],
    );
    expect(
      _field(lines.createFields, 'PriceId').reference?.scopeMode,
      AcpScopeMode.none,
    );
    expect(
      _field(lines.createFields, 'PeriodStart').required,
      isFalse,
      reason: 'one-time setup charges do not require a recurring period',
    );

    final paymentAllocations = _resource(
      billingOperationsResources,
      'BillingPaymentAllocations',
    );
    expect(paymentAllocations.allowCreate, isTrue);
    expect(paymentAllocations.allowUpdate, isFalse);
    expect(paymentAllocations.entityActions.single.name, 'sync_invoice');
    expect(paymentAllocations.entityActions.single.includeRowVersion, isTrue);

    for (final entitySet in <String>[
      'BillingEntitlementAdjustments',
      'BillingEntitlementBuckets',
    ]) {
      final resource = _resource(billingOperationsResources, entitySet);
      expect(resource.allowCreate, isFalse);
      expect(resource.allowUpdate, isFalse);
    }
    for (final entitySet in <String>[
      'BillingUsageEvents',
      'BillingUsageAllocations',
      'BillingPaymentAllocations',
      'BillingLedgerEntries',
    ]) {
      final resource = _resource(billingOperationsResources, entitySet);
      expect(resource.allowCreate, isTrue);
      expect(resource.allowUpdate, isFalse);
    }
  });

  test('billing period and adjustment helpers enforce operator contracts', () {
    expect(
      remainingEntitlementQuantity(<String, Object?>{
        'IncludedQuantity': 100,
        'ConsumedQuantity': '25',
        'RolloverQuantity': 10,
        'AdjustmentQuantity': -5,
      }),
      80,
    );
    expect(remainingEntitlementQuantity(const <String, Object?>{}), 0);
    expect(
      adjustmentPreview(<String, String>{
        'IncludedQuantity': '100',
        'ConsumedQuantity': '25',
        'RolloverQuantity': '10',
        'AdjustmentQuantity': '-5',
        'QuantityDelta': '8',
      }),
      'Adjustment: -5 → 3; capacity after: 113; remaining after: 88.',
    );
    expect(
      adjustmentPreview(const <String, String>{}),
      contains('remaining after: 0'),
    );
    expect(newBillingIdempotencyKey().toString(), startsWith('billing-ui-'));

    expect(
      validateSubscriptionPayload(<String, Object?>{
        'CurrentPeriodStart': '2026-08-27T00:00:00Z',
      }),
      contains('must be provided together'),
    );
    expect(
      validateSubscriptionPayload(<String, Object?>{
        'CurrentPeriodStart': '2026-08-27T00:00:00Z',
        'CurrentPeriodEnd': '2026-08-28T00:00:00Z',
      }),
      isNull,
    );
    expect(validateOptionalPeriodPayload(const <String, Object?>{}), isNull);
    expect(
      validateOptionalPeriodPayload(<String, Object?>{
        'PeriodStart': 'invalid',
        'PeriodEnd': 'also-invalid',
      }),
      contains('must be later'),
    );
    expect(
      validateBillingRunPayload(const <String, Object?>{}),
      'PeriodStart and PeriodEnd are required.',
    );
    expect(
      validateBillingRunPayload(<String, Object?>{
        'PeriodStart': '2026-08-27T00:00:00Z',
        'PeriodEnd': '2026-08-28T00:00:00Z',
        'SubscriptionId': 'subscription-1',
      }),
      contains('also require a Billing Account'),
    );
    expect(
      validateBillingRunPayload(<String, Object?>{
        'PeriodStart': '2026-08-27T00:00:00Z',
        'PeriodEnd': '2026-08-28T00:00:00Z',
        'SubscriptionId': 'subscription-1',
        'AccountId': 'account-1',
      }),
      isNull,
    );
    expect(validateInvoicePayload(const <String, Object?>{}), isNull);
    expect(
      validateInvoicePayload(<String, Object?>{'TotalAmount': 100}),
      contains('Select an explicit Currency'),
    );
    expect(
      validateInvoicePayload(<String, Object?>{
        'TotalAmount': 100,
        'CurrencyDefinitionId': 'currency-1',
      }),
      isNull,
    );

    expect(
      validateEntitlementAdjustmentPayload(<String, Object?>{
        'QuantityDelta': 0,
      }),
      contains('non-zero whole number'),
    );
    expect(
      validateEntitlementAdjustmentPayload(<String, Object?>{
        'QuantityDelta': 1,
        'Reason': ' ',
        'IdempotencyKey': 'adjust-1',
      }),
      contains('reason is required'),
    );
    expect(
      validateEntitlementAdjustmentPayload(<String, Object?>{
        'QuantityDelta': 1,
        'Reason': 'correction',
        'IdempotencyKey': ' ',
      }),
      contains('Idempotency Key'),
    );
    expect(
      validateEntitlementAdjustmentPayload(<String, Object?>{
        'QuantityDelta': -2,
        'Reason': 'correction',
        'IdempotencyKey': 'adjust-1',
      }),
      isNull,
    );
  });

  test('governance, workflow, SLA, and reporting fields are typed', () {
    final policy = governanceResources.single;
    expect(_field(policy.createFields, 'DocumentJson').kind, AcpFieldKind.json);
    expect(
      policy.updateFields.any((field) => field.key == 'IsActive'),
      isFalse,
    );
    expect(policy.entityActions.map((action) => action.name), <String>[
      'evaluate_policy',
      'activate_version',
    ]);
    expect(
      policy.entityActions.every((action) => action.includeRowVersion),
      isTrue,
    );

    final versions = _resource(workflowResources, 'OpsWorkflowVersions');
    expect(_field(versions.updateFields, 'Status').options, <String>[
      'draft',
      'published',
      'retired',
    ]);
    expect(
      _field(versions.updateFields, 'IsDefault').kind,
      AcpFieldKind.boolean,
    );
    final transitions = _resource(workflowResources, 'OpsWorkflowTransitions');
    final sourceState = _field(transitions.createFields, 'FromStateId');
    expect(sourceState.reference?.entitySet, 'OpsWorkflowStates');
    expect(sourceState.reference?.filterFieldsFromForm, <String, String>{
      'WorkflowVersionId': 'WorkflowVersionId',
    });
    expect(
      transitions.updateFields.any((field) => field.key == 'WorkflowVersionId'),
      isFalse,
    );

    final calendar = _resource(slaResources, 'OpsSlaCalendars');
    expect(
      _field(calendar.updateFields, 'BusinessStartTime').kind,
      AcpFieldKind.timeOfDay,
    );
    expect(
      _field(calendar.updateFields, 'BusinessStartTime').hintText,
      'Select a 24-hour time',
    );
    final businessDays = _field(calendar.updateFields, 'BusinessDays');
    expect(businessDays.kind, AcpFieldKind.integerList);
    expect(businessDays.minimumValue, 1);
    expect(businessDays.maximumValue, 7);
    expect(
      _field(calendar.createFields, 'HolidayRefs').kind,
      AcpFieldKind.dateList,
    );
    expect(
      _field(calendar.updateFields, 'HolidayRefs').kind,
      AcpFieldKind.dateList,
    );
    final target = _resource(slaResources, 'OpsSlaTargets');
    expect(_field(target.createFields, 'TargetMinutes').minimumValue, 1);
    expect(
      _field(target.createFields, 'PolicyId').reference?.entitySet,
      'OpsSlaPolicies',
    );

    final metrics = _resource(
      reportingResources,
      'OpsReportingMetricDefinitions',
    );
    expect(_field(metrics.createFields, 'FormulaType').options, hasLength(5));
    expect(
      _field(metrics.createFields, 'SourceValueColumn').requiredWhenEquals,
      contains('FormulaType'),
    );
    expect(metrics.entityActions.map((action) => action.name), <String>[
      'run_aggregation',
      'recompute_window',
    ]);
    expect(
      metrics.entityActions
          .expand((action) => action.fields)
          .where((field) => field.key.startsWith('Window'))
          .every((field) => field.kind == AcpFieldKind.dateTime),
      isTrue,
    );
    expect(
      metrics.entityActions
          .expand((action) => action.fields)
          .where((field) => field.key.startsWith('Window'))
          .every((field) => field.hintText == 'Select a UTC date and time'),
      isTrue,
    );
    final reports = _resource(
      reportingResources,
      'OpsReportingReportDefinitions',
    );
    final metricCodes = _field(reports.createFields, 'MetricCodes');
    expect(metricCodes.kind, AcpFieldKind.stringList);
    expect(metricCodes.reference?.multiSelect, isTrue);
    expect(metricCodes.reference?.valueField, 'Code');
  });

  test(
    'connector and messaging references preserve KeyId versus UUID rules',
    () {
      final instances = _resource(connectorResources, 'OpsConnectorInstances');
      final connectorType = _field(instances.createFields, 'ConnectorTypeId');
      final secretRef = _field(instances.createFields, 'SecretRef');
      final escalationPolicy = _field(
        instances.createFields,
        'EscalationPolicyKey',
      );
      final capability = _field(
        instances.entityActions
            .firstWhere((action) => action.name == 'invoke')
            .fields,
        'CapabilityName',
      );
      expect(connectorType.reference?.scopeMode, AcpScopeMode.none);
      expect(secretRef.reference?.valueField, 'KeyId');
      expect(secretRef.reference?.extraFilters, <String>["Status eq 'active'"]);
      expect(escalationPolicy.reference?.entitySet, 'OpsSlaEscalationPolicies');
      expect(escalationPolicy.reference?.valueField, 'PolicyKey');
      expect(capability.optionsBuilder, isNotNull);
      expect(capability.optionsBuilder!(const <String, Object?>{}), isEmpty);
      expect(
        capability.optionsBuilder!(const <String, Object?>{
          'ConnectorType': <String, Object?>{
            'CapabilitiesJson': <String, Object?>{
              'zeta': <String, Object?>{},
              '': <String, Object?>{},
              'alpha': <String, Object?>{},
            },
          },
        }),
        <String>['alpha', 'zeta'],
      );
      expect(
        capability.optionsBuilder!(const <String, Object?>{
          'ConnectorType': <String, Object?>{
            'CapabilitiesJson': '{"ping": {}}',
          },
        }),
        <String>['ping'],
      );
      expect(
        capability.optionsBuilder!(const <String, Object?>{
          'ConnectorType': <String, Object?>{'CapabilitiesJson': '{'},
        }),
        isEmpty,
      );
      expect(
        capability.optionsBuilder!(const <String, Object?>{
          'ConnectorType': <String, Object?>{'CapabilitiesJson': 1},
        }),
        isEmpty,
      );
      expect(
        instances.entityActions
            .firstWhere((action) => action.name == 'invoke')
            .confirmMessage,
        contains('external service'),
      );

      final messaging = _resource(
        runtimeAdminResources,
        'MessagingClientProfiles',
      );
      final advanced = _field(messaging.createFields, 'SecretRefs');
      final accessToken = _field(
        messaging.createFields,
        'WhatsappGraphApiAccessTokenKeyRefId',
      );
      final verificationToken = _field(
        messaging.createFields,
        'WhatsappWebhookVerificationTokenKeyRefId',
      );
      expect(advanced.excludedJsonKeys, <String>[
        'graphapi.access_token',
        'webhook.verification_token',
      ]);
      expect(accessToken.payloadContainerKey, 'SecretRefs');
      expect(accessToken.payloadMapKey, 'graphapi.access_token');
      expect(accessToken.reference?.valueField, 'Id');
      expect(verificationToken.payloadMapKey, 'webhook.verification_token');
      expect(accessToken.visibleWhenEquals, <String, List<Object>>{
        'PlatformKey': <Object>['whatsapp'],
      });
    },
  );

  test('descriptor helpers and row guards preserve configured metadata', () {
    final field = coreText(
      'Nested',
      'Nested',
      visibleWhenEquals: const <String, List<Object>>{
        'Mode': <Object>['on'],
      },
      payloadContainerKey: 'Container',
      payloadMapKey: 'path',
    );
    final reference = coreReference(
      'Ref',
      'Reference',
      entitySet: 'Rows',
      scopeMode: AcpScopeMode.optional,
      valueField: 'Code',
      extraFilters: const <String>['Enabled eq true'],
      filterFieldsFromForm: const <String, String>{'ParentId': 'ParentId'},
    );
    expect(field.payloadContainerKey, 'Container');
    expect(field.payloadMapKey, 'path');
    expect(field.visibleWhenEquals, isNotEmpty);
    expect(reference.reference?.valueField, 'Code');
    expect(reference.reference?.extraFilters, isNotEmpty);
    expect(reference.reference?.filterFieldsFromForm, isNotEmpty);

    expect(
      acpRowMatches(
        <String, dynamic>{'Enabled': true, 'Status': 'DRAFT'},
        const <String, List<Object>>{
          'Enabled': <Object>[true],
          'Status': <Object>['draft'],
        },
      ),
      isTrue,
    );
    expect(
      acpRowMatches(
        <String, dynamic>{'Enabled': false},
        const <String, List<Object>>{
          'Enabled': <Object>[true],
        },
      ),
      isFalse,
    );
  });

  group('CorePluginAccessService', () {
    test('available access state reports availability', () {
      final access = CorePluginAccess.available();

      expect(access.status, CorePluginAccessStatus.available);
      expect(access.message, isEmpty);
      expect(access.isAvailable, isTrue);
    });

    test('allows registered plugins and exposes entity access state', () async {
      final repository = _PluginRepository();
      final access = await CorePluginAccessService(
        repository: repository,
        onSessionExpired: () {},
      ).resolve('core.fw.ops_sla');

      expect(access.status, CorePluginAccessStatus.available);
      expect(access.message, isEmpty);
      expect(access.isAvailable, isTrue);
      expect(repository.tokens, <String>['core.fw.ops_sla']);
      expect(repository.status.isRegistered, isTrue);
    });

    test('hides unavailable plugins with reason or status', () async {
      final withReason = _PluginRepository(
        status: const CorePluginStatus(
          token: 'token',
          available: false,
          status: 'failed',
          reason: 'bootstrap failed',
        ),
      );
      final withoutReason = _PluginRepository(
        status: const CorePluginStatus(
          token: 'token',
          available: false,
          status: 'disabled',
        ),
      );

      final reasonAccess = await CorePluginAccessService(
        repository: withReason,
        onSessionExpired: () {},
      ).resolve('token');
      final statusAccess = await CorePluginAccessService(
        repository: withoutReason,
        onSessionExpired: () {},
      ).resolve('token');

      expect(reasonAccess.message, contains('bootstrap failed'));
      expect(statusAccess.message, contains('disabled'));
      expect(reasonAccess.isAvailable, isFalse);
    });

    test('reports failures and refreshes expired sessions', () async {
      var refreshes = 0;
      final expired = _PluginRepository(
        result: const Result<CorePluginStatus>.failure(
          SessionExpiredFailure(''),
        ),
      );
      final unauthorized = _PluginRepository(
        result: const Result<CorePluginStatus>.failure(
          UnauthorizedFailure('denied'),
        ),
      );

      final expiredAccess = await CorePluginAccessService(
        repository: expired,
        onSessionExpired: () => refreshes += 1,
      ).resolve('token');
      final deniedAccess = await CorePluginAccessService(
        repository: unauthorized,
        onSessionExpired: () => refreshes += 1,
      ).resolve('token');

      expect(expiredAccess.status, CorePluginAccessStatus.error);
      expect(
        expiredAccess.message,
        'Plugin availability could not be verified.',
      );
      expect(deniedAccess.message, 'denied');
      expect(refreshes, 2);
    });
  });
}

AcpResourceDescriptor _resource(
  List<AcpResourceDescriptor> resources,
  String entitySet,
) {
  return resources.firstWhere((resource) => resource.entitySet == entitySet);
}

AcpFieldDescriptor _field(List<AcpFieldDescriptor> fields, String key) {
  return fields.firstWhere((field) => field.key == key);
}

class _PluginRepository implements CorePluginRepository {
  _PluginRepository({CorePluginStatus? status, this.result})
    : status =
          status ??
          const CorePluginStatus(
            token: 'token',
            available: true,
            status: 'registered',
          );

  final CorePluginStatus status;
  final Result<CorePluginStatus>? result;
  final List<String> tokens = <String>[];

  @override
  Future<Result<CorePluginStatus>> fetchStatus(String token) async {
    tokens.add(token);
    return result ?? Result<CorePluginStatus>.success(status);
  }
}
