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
  test('resource families cover the required Core entity sets and scopes', () {
    expect(
      billingOperationsResources.map((resource) => resource.entitySet),
      <String>[
        'BillingEntitlementBuckets',
        'BillingInvoices',
        'BillingInvoiceLines',
        'BillingUsageAllocations',
        'BillingRuns',
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
          .where(
            (resource) =>
                resource.entitySet != 'OpsConnectorTypes' &&
                resource.entitySet != 'BillingPrices',
          )
          .every((resource) => resource.scopeMode == AcpScopeMode.required),
      isTrue,
    );
    expect(
      _resource(connectorResources, 'OpsConnectorTypes').scopeMode,
      AcpScopeMode.none,
    );
  });

  test('billing descriptors guard draft editing and invoice actions', () {
    final buckets = _resource(
      billingOperationsResources,
      'BillingEntitlementBuckets',
    );
    final invoices = _resource(billingOperationsResources, 'BillingInvoices');
    final lines = _resource(billingOperationsResources, 'BillingInvoiceLines');

    expect(buckets.allowCreate, isTrue);
    expect(buckets.allowUpdate, isTrue);
    expect(buckets.allowDelete, isFalse);
    expect(
      _field(buckets.createFields, 'SubscriptionId').applyAfterCreate,
      isTrue,
    );
    expect(
      _field(buckets.createFields, 'AccountId').reference?.entitySet,
      'BillingAccounts',
    );
    expect(
      _field(lines.createFields, 'PriceId').reference?.scopeMode,
      AcpScopeMode.none,
    );
    expect(lines.allowDelete, isFalse);

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
    final businessDays = _field(calendar.updateFields, 'BusinessDays');
    expect(businessDays.kind, AcpFieldKind.integerList);
    expect(businessDays.minimumValue, 1);
    expect(businessDays.maximumValue, 7);
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
      expect(connectorType.reference?.scopeMode, AcpScopeMode.none);
      expect(secretRef.reference?.valueField, 'KeyId');
      expect(secretRef.reference?.extraFilters, <String>["Status eq 'active'"]);
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
