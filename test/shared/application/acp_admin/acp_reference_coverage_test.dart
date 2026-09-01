import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/acp_console/application/acp_console_resources.dart';
import 'package:mugen_ui/features/billing_catalog/application/billing_catalog_resources.dart';
import 'package:mugen_ui/features/context_admin/application/context_admin_resources.dart';
import 'package:mugen_ui/features/core_provisioning/application/billing_operations_resources.dart';
import 'package:mugen_ui/features/core_provisioning/application/connector_resources.dart';
import 'package:mugen_ui/features/core_provisioning/application/governance_resources.dart';
import 'package:mugen_ui/features/core_provisioning/application/reporting_resources.dart';
import 'package:mugen_ui/features/core_provisioning/application/sla_resources.dart';
import 'package:mugen_ui/features/core_provisioning/application/workflow_resources.dart';
import 'package:mugen_ui/features/knowledge_pack_admin/application/knowledge_pack_admin_resources.dart';
import 'package:mugen_ui/features/orchestration_admin/application/orchestration_admin_resources.dart';
import 'package:mugen_ui/features/runtime_admin/application/runtime_admin_resources.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';

void main() {
  final resources = <AcpResourceDescriptor>[
    ...acpConsoleResources,
    ...billingCatalogResources,
    ...contextAdminResources,
    ...billingOperationsResources,
    ...connectorResources,
    ...governanceResources,
    ...reportingResources,
    ...slaResources,
    ...workflowResources,
    ...knowledgePackAdminResources,
    ...orchestrationAdminResources,
    ...runtimeAdminResources,
  ];

  test('registered UUID resources declare GUID key literals', () {
    final malformed = resources
        .where(
          (resource) => resource.keyLiteralType != AcpFilterLiteralType.guid,
        )
        .map((resource) => '${resource.key} (${resource.entitySet})')
        .toList(growable: false);

    expect(
      malformed,
      isEmpty,
      reason: 'UUID resources without GUID key metadata: $malformed',
    );
  });

  test('registered UUID batch references declare GUID literals', () {
    final malformed = <String>[];
    for (final resource in resources) {
      for (final column in resource.columns) {
        final lookup = column.reference?.batchLookup;
        if (lookup != null && lookup.literalType != AcpFilterLiteralType.guid) {
          malformed.add('${resource.key}.${column.key} -> ${lookup.entitySet}');
        }
      }
    }

    expect(
      malformed,
      isEmpty,
      reason: 'UUID batch references without GUID metadata: $malformed',
    );
  });

  test('every displayed ID is a reference or explicitly opaque', () {
    final missing = <String>[];
    for (final resource in resources) {
      for (final column in resource.columns) {
        if (!column.key.endsWith('Id')) {
          continue;
        }
        if (column.reference == null && !column.opaqueIdentifier) {
          missing.add('${resource.key}.${column.key}');
        }
      }
    }

    expect(missing, isEmpty, reason: 'Unclassified ID columns: $missing');
  });

  test('expanded references declare matching resource expansion roots', () {
    final missing = <String>[];
    for (final resource in resources) {
      final roots = resource.expansions
          .map((expansion) => expansion.navigation)
          .toSet();
      for (final column in resource.columns) {
        final reference = column.reference;
        if (reference == null || reference.batchLookup != null) {
          continue;
        }
        final root = reference.navigationPath.split('.').first;
        if (!roots.contains(root)) {
          missing.add('${resource.key}.${column.key} -> $root');
        }
      }
    }

    expect(missing, isEmpty, reason: 'Missing expansion roots: $missing');
  });

  test(
    'editable IDs are searchable references or classified operational IDs',
    () {
      const operationalIds = <String>{
        'evidence-blobs.collection:register.TraceId',
        'evidence-blobs.collection:register.SubjectId',
        'audit-correlation-links.collection:resolve_trace.TraceId',
        'audit-correlation-links.collection:resolve_trace.CorrelationId',
        'audit-correlation-links.collection:resolve_trace.RequestId',
        'audit-biz-trace-events.collection:inspect_trace.TraceId',
        'audit-biz-trace-events.collection:inspect_trace.CorrelationId',
        'audit-biz-trace-events.collection:inspect_trace.RequestId',
        'ops-connector-instances.entity:test_connection.TraceId',
        'ops-connector-instances.entity:invoke.TraceId',
        'ops-policy-definitions.entity:evaluate_policy.TraceId',
        'ops-policy-definitions.entity:evaluate_policy.SubjectId',
        'work-items.create.TraceId',
        'work-items.collection:create_from_channel.TraceId',
        'messaging-client-profiles.create.RecipientUserId',
        'messaging-client-profiles.create.PhoneNumberId',
        'messaging-client-profiles.update.RecipientUserId',
        'messaging-client-profiles.update.PhoneNumberId',
        'key-refs.collection:rotate.KeyId',
      };
      final rawIds = <String>{};
      for (final resource in resources) {
        final fieldGroups = <String, List<AcpFieldDescriptor>>{
          'create': resource.createFields,
          'update': resource.updateFields,
          for (final action in resource.collectionActions)
            'collection:${action.name}': action.fields,
          for (final action in resource.entityActions)
            'entity:${action.name}': action.fields,
        };
        for (final group in fieldGroups.entries) {
          for (final field in group.value) {
            if (field.readOnly ||
                !field.key.endsWith('Id') ||
                field.reference != null) {
              continue;
            }
            rawIds.add('${resource.key}.${group.key}.${field.key}');
          }
        }
      }

      expect(
        rawIds,
        operationalIds,
        reason: 'Classify new IDs or replace them with searchable references.',
      );
    },
  );

  test('billing operations and catalog cover every required relationship', () {
    const required = <String, Set<String>>{
      'billing-subscriptions': <String>{'AccountId', 'PriceId'},
      'billing-entitlement-buckets': <String>{
        'SubscriptionId',
        'PriceId',
        'PriceEntitlementId',
        'MeterDefinitionId',
      },
      'billing-entitlement-adjustments': <String>{'BucketId', 'ActorUserId'},
      'billing-usage-events': <String>{
        'AccountId',
        'SubscriptionId',
        'PriceId',
      },
      'billing-usage-allocations': <String>{
        'UsageEventId',
        'EntitlementBucketId',
      },
      'billing-runs': <String>{
        'DefinitionId',
        'AccountId',
        'SubscriptionId',
        'RetryOfRunId',
      },
      'billing-invoices': <String>{
        'AccountId',
        'SubscriptionId',
        'BillingRunId',
      },
      'billing-invoice-lines': <String>{
        'InvoiceId',
        'PriceId',
        'TaxCodeId',
        'TaxRateId',
      },
      'billing-credit-notes': <String>{'AccountId', 'InvoiceId'},
      'billing-adjustments': <String>{'AccountId', 'InvoiceId', 'CreditNoteId'},
      'billing-payments': <String>{'AccountId', 'InvoiceId'},
      'billing-payment-allocations': <String>{'PaymentId', 'InvoiceId'},
      'billing-ledger-entries': <String>{'AccountId', 'InvoiceId', 'PaymentId'},
      'billing-price-entitlements': <String>{'PriceId', 'MeterDefinitionId'},
    };
    final byKey = <String, AcpResourceDescriptor>{
      for (final resource in <AcpResourceDescriptor>[
        ...billingOperationsResources,
        ...billingCatalogResources,
      ])
        resource.key: resource,
    };

    for (final entry in required.entries) {
      final resource = byKey[entry.key];
      expect(resource, isNotNull, reason: entry.key);
      final covered = resource!.columns
          .where((column) => column.reference != null)
          .map((column) => column.key)
          .toSet();
      expect(covered, containsAll(entry.value), reason: entry.key);
    }
  });

  test('audited form fields declare a bounded selection strategy', () {
    const expected = <String, Set<String>>{
      'schemas': <String>{'ActivatedByUserId'},
      'schema-bindings': <String>{
        'SchemaDefinitionId',
        'TargetNamespace',
        'TargetEntitySet',
        'TargetAction',
        'BindingKind',
      },
      'plugin-capability-grants': <String>{'PluginKey', 'Capabilities'},
      'context-profiles': <String>{
        'Platform',
        'ServiceRouteKey',
        'ClientProfileKey',
        'PolicyId',
      },
      'context-contributor-bindings': <String>{
        'ContributorKey',
        'Platform',
        'ServiceRouteKey',
      },
      'context-source-bindings': <String>{
        'SourceKind',
        'Platform',
        'ServiceRouteKey',
        'Locale',
      },
      'ops-workflow-versions': <String>{
        'WorkflowDefinitionId',
        'Status',
        'PublishedByUserId',
      },
      'ops-workflow-states': <String>{'WorkflowVersionId'},
      'ops-workflow-transitions': <String>{
        'WorkflowVersionId',
        'FromStateId',
        'ToStateId',
        'AutoAssignUserId',
        'AutoAssignQueue',
      },
      'ops-sla-policies': <String>{'CalendarId'},
      'ops-sla-calendars': <String>{'Timezone', 'BusinessDays'},
      'ops-sla-targets': <String>{'PolicyId', 'Metric', 'Priority', 'Severity'},
      'ops-reporting-metric-definitions': <String>{
        'FormulaType',
        'SourceTable',
        'SourceTimeColumn',
        'SourceValueColumn',
        'ScopeColumn',
      },
      'ops-reporting-report-definitions': <String>{
        'MetricCodes',
        'GroupByJson',
      },
      'ops-connector-instances': <String>{
        'ConnectorTypeId',
        'SecretRef',
        'Status',
        'EscalationPolicyKey',
        'CapabilityName',
      },
      'knowledge-packs': <String>{'CurrentVersionId'},
      'knowledge-pack-versions': <String>{'KnowledgePackId'},
      'knowledge-entries': <String>{
        'KnowledgePackId',
        'KnowledgePackVersionId',
      },
      'knowledge-entry-revisions': <String>{
        'KnowledgeEntryId',
        'KnowledgePackVersionId',
        'Channel',
        'Locale',
      },
      'knowledge-scopes': <String>{
        'KnowledgePackVersionId',
        'KnowledgeEntryRevisionId',
        'Channel',
        'Locale',
        'ServiceRouteKey',
        'ClientProfileKey',
      },
      'channel-profiles': <String>{
        'ClientProfileId',
        'ChannelKey',
        'RouteDefaultKey',
        'PolicyId',
      },
      'ingress-bindings': <String>{
        'ChannelProfileId',
        'ChannelKey',
        'IdentifierType',
        'ServiceRouteKey',
      },
      'intake-rules': <String>{'ChannelProfileId', 'MatchKind', 'RouteKey'},
      'routing-rules': <String>{'ChannelProfileId', 'OwnerUserId'},
      'conversation-states': <String>{
        'ChannelProfileId',
        'PolicyId',
        'ServiceRouteKey',
        'RouteKey',
        'AssignedQueueName',
        'AssignedOwnerUserId',
        'AssignedServiceKey',
        'QueueName',
        'OwnerUserId',
        'ServiceKey',
      },
      'work-items': <String>{'LinkedCaseId', 'LinkedWorkflowInstanceId'},
      'billing-run-definitions': <String>{'Timezone'},
      'billing-invoice-templates': <String>{'Locale'},
      'messaging-client-profiles': <String>{'PlatformKey'},
      'runtime-config-profiles': <String>{'Category'},
    };
    final byKey = <String, AcpResourceDescriptor>{
      for (final resource in resources) resource.key: resource,
    };

    for (final entry in expected.entries) {
      final resource = byKey[entry.key];
      expect(resource, isNotNull, reason: entry.key);
      final fields = <AcpFieldDescriptor>[
        ...resource!.createFields,
        ...resource.updateFields,
        for (final action in resource.collectionActions) ...action.fields,
        for (final action in resource.entityActions) ...action.fields,
      ].where((field) => !field.readOnly).toList(growable: false);

      for (final key in entry.value) {
        final matching = fields.where((field) => field.key == key).toList();
        expect(matching, isNotEmpty, reason: '${entry.key}.$key is absent');
        for (final field in matching) {
          final hasStrategy =
              field.reference != null ||
              field.options.isNotEmpty ||
              field.optionsBuilder != null ||
              field.multiSelectOptions;
          expect(
            hasStrategy,
            isTrue,
            reason: '${entry.key}.$key has no selection strategy',
          );
        }
      }
    }
  });

  test('only operational identifiers use the opaque classification', () {
    final opaque = <String>{
      for (final resource in resources)
        for (final column in resource.columns)
          if (column.opaqueIdentifier) '${resource.key}.${column.key}',
    };

    expect(opaque, <String>{
      'evidence-blobs.TraceId',
      'audit-correlation-links.TraceId',
      'audit-correlation-links.CorrelationId',
      'audit-biz-trace-events.TraceId',
      'work-items.TraceId',
      'key-refs.KeyId',
      'knowledge-index-projections.TargetFingerprint',
      'knowledge-index-projections.ContentChecksum',
    });
  });

  test('billing amount fields use money presentation exclusively', () {
    const amountKeys = <String>{
      'Amount',
      'AmountDue',
      'SubtotalAmount',
      'TaxAmount',
      'TotalAmount',
      'UnitAmount',
    };
    final billingResources = <AcpResourceDescriptor>[
      ...billingCatalogResources,
      ...billingOperationsResources,
    ];
    final fieldFailures = <String>[];
    final columnFailures = <String>[];
    final referenceFailures = <String>[];

    for (final resource in billingResources) {
      final fields = <AcpFieldDescriptor>[
        ...resource.createFields,
        ...resource.updateFields,
        for (final action in resource.collectionActions) ...action.fields,
        for (final action in resource.entityActions) ...action.fields,
      ];
      for (final field in fields) {
        if (amountKeys.contains(field.key) &&
            (field.kind != AcpFieldKind.money ||
                field.minorUnitFieldKey == null)) {
          fieldFailures.add('${resource.key}.${field.key}');
        }
        final reference = field.reference;
        if (reference == null) {
          continue;
        }
        for (final subtitle in reference.subtitleFields) {
          if (amountKeys.contains(subtitle)) {
            referenceFailures.add('${resource.key}.${field.key} -> $subtitle');
          }
        }
      }
      for (final column in resource.columns) {
        if (amountKeys.contains(column.key) && !column.money) {
          columnFailures.add('${resource.key}.${column.key}');
        }
      }
    }

    expect(fieldFailures, isEmpty, reason: 'Non-money fields: $fieldFailures');
    expect(
      columnFailures,
      isEmpty,
      reason: 'Non-money columns: $columnFailures',
    );
    expect(
      referenceFailures,
      isEmpty,
      reason: 'Raw minor-unit reference subtitles: $referenceFailures',
    );
  });
}
