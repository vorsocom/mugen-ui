import 'package:flutter_test/flutter_test.dart';

import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_path_builder.dart';

void main() {
  final endpoints = AppConfig.defaults().api.endpoints;

  test('builds non-tenant collection and entity paths', () {
    final collection = AcpPathBuilder.collectionPath(
      endpoints: endpoints,
      entitySet: 'SystemFlags',
      scopeMode: AcpScopeMode.none,
    );
    final entity = AcpPathBuilder.entityPath(
      endpoints: endpoints,
      entitySet: 'SystemFlags',
      entityId: 'row-1',
      scopeMode: AcpScopeMode.none,
    );
    final action = AcpPathBuilder.collectionActionPath(
      endpoints: endpoints,
      entitySet: 'SystemFlags',
      action: 'reloadPlatformProfiles',
      scopeMode: AcpScopeMode.none,
    );

    expect(collection.data, 'core/acp/v1/SystemFlags');
    expect(entity.data, 'core/acp/v1/SystemFlags/row-1');
    expect(
      action.data,
      'core/acp/v1/SystemFlags/\$action/reloadPlatformProfiles',
    );
  });

  test('builds tenant-scoped paths when tenant is required', () {
    final collection = AcpPathBuilder.collectionPath(
      endpoints: endpoints,
      entitySet: 'ContextProfiles',
      scopeMode: AcpScopeMode.required,
      tenantId: 'tenant-1',
    );
    final restore = AcpPathBuilder.restorePath(
      endpoints: endpoints,
      entitySet: 'ContextProfiles',
      entityId: 'row-1',
      scopeMode: AcpScopeMode.required,
      tenantId: 'tenant-1',
    );
    final action = AcpPathBuilder.entityActionPath(
      endpoints: endpoints,
      entitySet: 'ConversationStates',
      entityId: 'row-1',
      action: 'route',
      scopeMode: AcpScopeMode.required,
      tenantId: 'tenant-1',
    );

    expect(collection.data, 'core/acp/v1/tenants/tenant-1/ContextProfiles');
    expect(
      restore.data,
      'core/acp/v1/tenants/tenant-1/ContextProfiles/row-1/\$restore',
    );
    expect(
      action.data,
      'core/acp/v1/tenants/tenant-1/ConversationStates/row-1/\$action/route',
    );
  });

  test('supports optional-scope resources with and without tenants', () {
    final globalPath = AcpPathBuilder.collectionPath(
      endpoints: endpoints,
      entitySet: 'Schemas',
      scopeMode: AcpScopeMode.optional,
    );
    final tenantPath = AcpPathBuilder.collectionPath(
      endpoints: endpoints,
      entitySet: 'Schemas',
      scopeMode: AcpScopeMode.optional,
      tenantId: 'tenant-1',
    );

    expect(globalPath.data, 'core/acp/v1/Schemas');
    expect(tenantPath.data, 'core/acp/v1/tenants/tenant-1/Schemas');
  });

  test('fails when tenant-scoped path is requested without a tenant', () {
    final collection = AcpPathBuilder.collectionPath(
      endpoints: endpoints,
      entitySet: 'ContextProfiles',
      scopeMode: AcpScopeMode.required,
    );

    expect(collection.isFailure, isTrue);
    expect(collection.failure?.message, 'A tenant must be selected.');
  });
}
