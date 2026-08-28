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
    });
  });
}
