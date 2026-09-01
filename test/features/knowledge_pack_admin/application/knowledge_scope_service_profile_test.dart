import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/knowledge_pack_admin/application/knowledge_pack_admin_resources.dart';

void main() {
  test('Service Profile scope fields are capability gated', () {
    final disabled = buildKnowledgePackAdminResources(
      serviceProfilesEnabled: false,
    ).firstWhere((item) => item.entitySet == 'KnowledgeScopes');
    expect(
      disabled.columns.where((item) => item.key == 'ServiceProfileId'),
      isEmpty,
    );
    expect(
      disabled.createFields.where((item) => item.key == 'ServiceProfileId'),
      isEmpty,
    );

    final enabled = buildKnowledgePackAdminResources(
      serviceProfilesEnabled: true,
    ).firstWhere((item) => item.entitySet == 'KnowledgeScopes');
    final column = enabled.columns.firstWhere(
      (item) => item.key == 'ServiceProfileId',
    );
    expect(column.reference?.unassignedLabel, 'All service profiles');
    expect(column.reference?.targetRouteId, 'service-profiles');
    expect(column.reference?.targetResourceKey, 'service-profiles');
    expect(column.reference?.batchLookup?.entitySet, 'ServiceProfiles');
    final field = enabled.createFields.firstWhere(
      (item) => item.key == 'ServiceProfileId',
    );
    expect(field.required, isFalse);
    expect(field.reference?.scopeMode.name, 'required');
    expect(field.hintText, contains('stable service identity'));
    expect(field.hintText, contains('Service Route'));
    expect(field.hintText, contains('Client Profile'));
    expect(
      enabled.updateFields.where((item) => item.key == 'ServiceProfileId'),
      hasLength(1),
    );
    expect(
      enabled.filters
          .firstWhere((item) => item.key == 'ServiceProfileId')
          .reference
          ?.entitySet,
      'ServiceProfiles',
    );
    expect(
      enabled.detailSections.single.fields
          .firstWhere((item) => item.key == 'ServiceProfileLabel')
          .label,
      'Service Profile',
    );
  });
}
