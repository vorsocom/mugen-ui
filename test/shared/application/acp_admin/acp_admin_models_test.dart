import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';

void main() {
  test('descriptor models preserve configured metadata', () {
    const field = AcpFieldDescriptor(
      key: 'SecretValue',
      label: 'Secret Value',
      kind: AcpFieldKind.multiline,
      required: true,
      requiredWhenEquals: <String, List<String>>{
        'PlatformKey': <String>['wechat'],
      },
      hintText: 'Encrypted material',
      minLines: 3,
      maxLines: 5,
      obscureText: true,
      initialValue: 'seed',
      options: <String>['local', 'managed'],
    );
    const column = AcpColumnDescriptor(
      key: 'DisplayName',
      label: 'Display Name',
      flex: 2,
    );
    const action = AcpActionDescriptor(
      name: 'rotate',
      label: 'Rotate',
      target: AcpActionTarget.collection,
      confirmMessage: 'Rotate now?',
      fields: <AcpFieldDescriptor>[field],
      includeRowVersion: true,
      successMessage: 'Rotation completed.',
      showInToolbar: false,
      showInRowMenu: true,
      prefillFieldsFromRow: true,
      showAsRowButton: true,
    );
    const resource = AcpResourceDescriptor(
      key: 'key-refs',
      title: 'Key References',
      entitySet: 'KeyRefs',
      scopeMode: AcpScopeMode.optional,
      columns: <AcpColumnDescriptor>[column],
      description: 'Managed key references.',
      createFields: <AcpFieldDescriptor>[field],
      updateFields: <AcpFieldDescriptor>[field],
      collectionActions: <AcpActionDescriptor>[action],
      entityActions: <AcpActionDescriptor>[action],
      searchFields: <String>['DisplayName'],
      defaultOrderBy: 'DisplayName asc',
      emptyMessage: 'Nothing here.',
      allowCreate: true,
      allowUpdate: true,
      allowDelete: true,
      allowRestore: true,
      pageSize: 25,
      actionsColumnLeading: false,
    );

    expect(field.key, 'SecretValue');
    expect(field.kind, AcpFieldKind.multiline);
    expect(field.required, isTrue);
    expect(field.requiredWhenEquals, <String, List<String>>{
      'PlatformKey': <String>['wechat'],
    });
    expect(field.hintText, 'Encrypted material');
    expect(field.minLines, 3);
    expect(field.maxLines, 5);
    expect(field.obscureText, isTrue);
    expect(field.initialValue, 'seed');
    expect(field.options, <String>['local', 'managed']);

    expect(column.flex, 2);
    expect(action.target, AcpActionTarget.collection);
    expect(action.confirmMessage, 'Rotate now?');
    expect(action.fields.single, same(field));
    expect(action.includeRowVersion, isTrue);
    expect(action.successMessage, 'Rotation completed.');
    expect(action.showInToolbar, isFalse);
    expect(action.showInRowMenu, isTrue);
    expect(action.prefillFieldsFromRow, isTrue);
    expect(action.showAsRowButton, isTrue);

    expect(resource.description, 'Managed key references.');
    expect(resource.columns.single, same(column));
    expect(resource.createFields.single, same(field));
    expect(resource.updateFields.single, same(field));
    expect(resource.collectionActions.single, same(action));
    expect(resource.entityActions.single, same(action));
    expect(resource.searchFields, <String>['DisplayName']);
    expect(resource.defaultOrderBy, 'DisplayName asc');
    expect(resource.emptyMessage, 'Nothing here.');
    expect(resource.allowCreate, isTrue);
    expect(resource.allowUpdate, isTrue);
    expect(resource.allowDelete, isTrue);
    expect(resource.allowRestore, isTrue);
    expect(resource.pageSize, 25);
    expect(resource.actionsColumnLeading, isFalse);
  });

  test('tenant labels and row pages normalize display values', () {
    const globalTenant = AcpTenantOption(
      id: 'global-id',
      name: 'Global',
      slug: 'global',
    );
    const plainTenant = AcpTenantOption(id: 'tenant-1', name: 'Tenant One');
    const paged = AcpRowPage(
      items: <AcpRow>[],
      total: 11,
      page: 1,
      pageSize: 5,
    );
    const unpaged = AcpRowPage(
      items: <AcpRow>[],
      total: 0,
      page: 1,
      pageSize: 0,
    );

    expect(globalTenant.label, 'Global (global)');
    expect(plainTenant.label, 'Tenant One');
    expect(paged.pages, 3);
    expect(unpaged.pages, 1);
  });

  test('row extensions normalize identifiers and row versions', () {
    final row = <String, dynamic>{
      'Id': ' row-1 ',
      'TenantId': ' tenant-1 ',
      'RowVersion': '7',
    };
    final numericRow = <String, dynamic>{'RowVersion': 9};
    final blankRow = <String, dynamic>{
      'Id': '   ',
      'TenantId': '',
      'RowVersion': 'not-a-number',
    };

    expect(row.id, 'row-1');
    expect(row.tenantId, 'tenant-1');
    expect(row.rowVersion, 7);
    expect(numericRow.rowVersion, 9);
    expect(blankRow.id, isNull);
    expect(blankRow.tenantId, isNull);
    expect(blankRow.rowVersion, isNull);
  });
}
