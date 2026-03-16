import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class AcpPathBuilder {
  const AcpPathBuilder._(); // coverage:ignore-line

  static Result<String> collectionPath({
    required ApiEndpointsConfig endpoints,
    required String entitySet,
    required AcpScopeMode scopeMode,
    String? tenantId,
  }) {
    final root = endpoints.acpBase;
    final resolvedTenant = _resolveTenant(
      scopeMode: scopeMode,
      tenantId: tenantId,
    );
    if (resolvedTenant.isFailure) {
      return Result<String>.failure(resolvedTenant.failure!);
    }

    final tenant = resolvedTenant.data;
    if (tenant == null) {
      return Result<String>.success('$root/$entitySet');
    }

    return Result<String>.success('$root/tenants/$tenant/$entitySet');
  }

  static Result<String> entityPath({
    required ApiEndpointsConfig endpoints,
    required String entitySet,
    required String entityId,
    required AcpScopeMode scopeMode,
    String? tenantId,
  }) {
    final base = collectionPath(
      endpoints: endpoints,
      entitySet: entitySet,
      scopeMode: scopeMode,
      tenantId: tenantId,
    );
    if (base.isFailure) {
      return base;
    }

    return Result<String>.success('${base.data}/$entityId');
  }

  static Result<String> restorePath({
    required ApiEndpointsConfig endpoints,
    required String entitySet,
    required String entityId,
    required AcpScopeMode scopeMode,
    String? tenantId,
  }) {
    final entity = entityPath(
      endpoints: endpoints,
      entitySet: entitySet,
      entityId: entityId,
      scopeMode: scopeMode,
      tenantId: tenantId,
    );
    if (entity.isFailure) {
      return entity;
    }

    return Result<String>.success('${entity.data}/\$restore');
  }

  static Result<String> collectionActionPath({
    required ApiEndpointsConfig endpoints,
    required String entitySet,
    required String action,
    required AcpScopeMode scopeMode,
    String? tenantId,
  }) {
    final base = collectionPath(
      endpoints: endpoints,
      entitySet: entitySet,
      scopeMode: scopeMode,
      tenantId: tenantId,
    );
    if (base.isFailure) {
      return base;
    }

    return Result<String>.success('${base.data}/\$action/$action');
  }

  static Result<String> entityActionPath({
    required ApiEndpointsConfig endpoints,
    required String entitySet,
    required String entityId,
    required String action,
    required AcpScopeMode scopeMode,
    String? tenantId,
  }) {
    final entity = entityPath(
      endpoints: endpoints,
      entitySet: entitySet,
      entityId: entityId,
      scopeMode: scopeMode,
      tenantId: tenantId,
    );
    if (entity.isFailure) {
      return entity;
    }

    return Result<String>.success('${entity.data}/\$action/$action');
  }

  static Result<String?> _resolveTenant({
    required AcpScopeMode scopeMode,
    String? tenantId,
  }) {
    final trimmedTenantId = tenantId?.trim();
    switch (scopeMode) {
      case AcpScopeMode.none:
        return const Result<String?>.success(null);
      case AcpScopeMode.required:
        if (trimmedTenantId == null || trimmedTenantId.isEmpty) {
          return const Result<String?>.failure(
            ValidationFailure('A tenant must be selected.'),
          );
        }
        return Result<String?>.success(trimmedTenantId);
      case AcpScopeMode.optional:
        if (trimmedTenantId == null || trimmedTenantId.isEmpty) {
          return const Result<String?>.success(null);
        }
        return Result<String?>.success(trimmedTenantId);
    }
  }
}
