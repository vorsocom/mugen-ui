import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/acp_console/application/acp_console_resources.dart';
import 'package:mugen_ui/features/billing_catalog/application/billing_catalog_resources.dart';
import 'package:mugen_ui/features/core_provisioning/application/billing_operations_resources.dart';
import 'package:mugen_ui/features/core_provisioning/application/reporting_resources.dart';
import 'package:mugen_ui/features/core_provisioning/application/sla_resources.dart';
import 'package:mugen_ui/features/core_provisioning/application/workflow_resources.dart';
import 'package:mugen_ui/features/orchestration_admin/application/orchestration_admin_resources.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';

void main() {
  test('every descriptor surface retains its typed temporal inputs', () {
    final expectedCounts =
        <({String surface, List<AcpResourceDescriptor> resources, int count})>[
          (
            surface: 'Billing Catalog',
            resources: billingCatalogResources,
            count: 8,
          ),
          (
            surface: 'Billing Operations',
            resources: billingOperationsResources,
            count: 18,
          ),
          (surface: 'ACP Console', resources: acpConsoleResources, count: 9),
          (
            surface: 'Orchestration',
            resources: orchestrationAdminResources,
            count: 2,
          ),
          (surface: 'Workflow', resources: workflowResources, count: 2),
          (surface: 'SLA', resources: slaResources, count: 4),
          (surface: 'Reporting', resources: reportingResources, count: 4),
        ];

    for (final expected in expectedCounts) {
      final resources = expected.resources;
      final fields = resources
          .expand(_formFields)
          .where(
            (field) =>
                field.kind == AcpFieldKind.dateTime ||
                field.kind == AcpFieldKind.timeOfDay,
          )
          .toList(growable: false);
      expect(fields, hasLength(expected.count), reason: expected.surface);
    }
  });

  test('SLA Holiday Dates use date-list fields on create and update', () {
    final dateLists = slaResources
        .expand(_formFields)
        .where((field) => field.kind == AcpFieldKind.dateList)
        .toList(growable: false);

    expect(dateLists, hasLength(2));
    expect(dateLists.every((field) => field.key == 'HolidayRefs'), isTrue);
    expect(dateLists.every((field) => field.label == 'Holiday Dates'), isTrue);
  });
}

Iterable<AcpFieldDescriptor> _formFields(AcpResourceDescriptor resource) sync* {
  yield* resource.createFields;
  yield* resource.updateFields;
  for (final action in <AcpActionDescriptor>[
    ...resource.collectionActions,
    ...resource.entityActions,
  ]) {
    yield* action.fields;
  }
}
