import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/orchestration_admin/presentation/providers/orchestration_admin_providers.dart';
import 'package:mugen_ui/features/orchestration_admin/presentation/widgets/channel_orchestration_panel.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/result.dart';

import '../../../test_support/fake_acp_admin_repository.dart';

void main() {
  testWidgets(
    'invalid legacy ingress binding deactivates without an ownership form',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _LegacyIngressRepository()
        ..entityActionResult = const Result<Object?>.success(null)
        ..fetchRowResult = Result<AcpRow>.success(<String, dynamic>{
          ..._legacyBinding,
          'IsActive': false,
          'RowVersion': 8,
        });

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            orchestrationAdminRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ChannelOrchestrationPanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('acp-admin-tab-ingress-bindings')));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Deactivate this ingress binding? It will stop routing inbound messages.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('acp-dynamic-field-ChannelKey')),
        findsNothing,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(repository.entityActionCallCount, 0);

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Deactivate'));
      await tester.pumpAndSettle();

      expect(repository.entityActionNames, <String>['deactivate']);
      expect(repository.entityActionRowVersions, <int>[7]);
      expect(repository.actionTenantId, 'tenant-1');
      expect(repository.actionValues, isEmpty);
      expect(repository.actionPatchValues, <String, dynamic>{
        'IsActive': false,
      });
      expect(repository.updatePayloads, isEmpty);
      expect(find.text('No'), findsOneWidget);
      expect(find.byTooltip('More actions'), findsNothing);
    },
  );
}

const _legacyBinding = <String, dynamic>{
  'Id': 'binding-1',
  'TenantId': 'tenant-1',
  'RowVersion': 7,
  'ChannelProfileId': null,
  'ChannelKey': 'whatsapp',
  'IdentifierType': 'tenant_slug',
  'IdentifierValue': 'unowned-identifier',
  'IsActive': true,
  'Attributes': <String, dynamic>{'legacy': true},
};

class _LegacyIngressRepository extends FakeAcpAdminRepository {
  _LegacyIngressRepository()
    : super(
        tenants: const <AcpTenantOption>[
          AcpTenantOption(
            id: 'tenant-1',
            name: 'Tenant One',
            slug: 'tenant-one',
          ),
        ],
      );

  String? actionTenantId;
  Map<String, dynamic>? actionValues;
  Map<String, dynamic>? actionPatchValues;

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
    return Result<AcpRowPage>.success(
      AcpRowPage(
        items: descriptor.entitySet == 'IngressBindings'
            ? const <AcpRow>[_legacyBinding]
            : const <AcpRow>[],
        total: descriptor.entitySet == 'IngressBindings' ? 1 : 0,
        page: pageRequest.page,
        pageSize: pageRequest.pageSize,
      ),
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
  }) {
    actionTenantId = tenantId;
    actionValues = values;
    actionPatchValues = action.patchValues;
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
