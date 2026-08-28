import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/acp_console/application/acp_console_resources.dart';
import 'package:mugen_ui/features/context_admin/application/context_admin_resources.dart';
import 'package:mugen_ui/features/knowledge_pack_admin/application/knowledge_pack_admin_resources.dart';
import 'package:mugen_ui/features/orchestration_admin/application/orchestration_admin_resources.dart';
import 'package:mugen_ui/features/runtime_admin/application/runtime_admin_resources.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_field_help.dart';

void main() {
  test('provider help distinguishes client profiles from key refs', () {
    expect(
      acpFieldHelpText(
        key: 'Provider',
        label: 'Provider',
        entitySet: 'MessagingClientProfiles',
      ),
      contains('transport-specific metadata'),
    );
    expect(
      acpFieldHelpText(
        key: 'Provider',
        label: 'Key Provider',
        entitySet: 'KeyRefs',
        actionName: 'rotate',
      ),
      contains('Key provider used for this KeyRef rotation'),
    );
  });

  test('repeated field keys use resource-specific backend meaning', () {
    expect(
      acpFieldHelpText(
        key: 'Category',
        label: 'Category',
        entitySet: 'RuntimeConfigProfiles',
      ),
      contains('Runtime configuration category'),
    );
    expect(
      acpFieldHelpText(
        key: 'Category',
        label: 'Category',
        entitySet: 'ContextSourceBindings',
      ),
      contains('context source allow rule'),
    );
    expect(
      acpFieldHelpText(
        key: 'TargetNamespace',
        label: 'Target Namespace',
        entitySet: 'SchemaBindings',
      ),
      contains('target entity set or action'),
    );
    expect(
      acpFieldHelpText(
        key: 'TargetNamespace',
        label: 'Target Namespace',
        entitySet: 'RoutingRules',
      ),
      contains('target service'),
    );
    expect(
      acpFieldHelpText(
        key: 'ProfileKey',
        label: 'Profile Key',
        entitySet: 'RuntimeConfigProfiles',
      ),
      contains('runtime configuration category'),
    );
    expect(
      acpFieldHelpText(
        key: 'ProfileKey',
        label: 'Profile Key',
        entitySet: 'ChannelProfiles',
      ),
      contains('paired with Channel Key'),
    );
  });

  test('Billing Price amounts consistently request major-unit input', () {
    final currencyHelp = acpFieldHelpText(
      key: 'Currency',
      label: 'Currency',
      entitySet: 'BillingPrices',
    );
    final amountHelp = acpFieldHelpText(
      key: 'UnitAmount',
      label: 'Unit Amount',
      kind: AcpFieldKind.money,
      entitySet: 'BillingPrices',
    );

    expect(currencyHelp, contains('Enter amounts in major units'));
    expect(amountHelp, contains('150.00'));
    expect(amountHelp, contains('converts it to minor units'));
    expect(amountHelp, isNot(contains('for example 15000')));
  });

  test('temporal fallback help describes selector-driven precision', () {
    expect(
      acpFieldHelpText(
        key: 'UnknownTimestamp',
        label: 'Unknown Timestamp',
        kind: AcpFieldKind.dateTime,
      ),
      contains('calendar date and 24-hour time'),
    );
    expect(
      acpFieldHelpText(
        key: 'UnknownTime',
        label: 'Unknown Time',
        kind: AcpFieldKind.timeOfDay,
      ),
      contains('minute precision'),
    );
    expect(
      acpFieldHelpText(
        key: 'UnknownDates',
        label: 'Unknown Dates',
        kind: AcpFieldKind.dateList,
      ),
      contains('YYYY-MM-DD'),
    );
  });

  test('every built-in ACP form field has explicit descriptive guidance', () {
    final resources = <AcpResourceDescriptor>[
      ...runtimeAdminResources,
      ...orchestrationAdminResources,
      ...contextAdminResources,
      ...knowledgePackAdminResources,
      ...acpConsoleResources,
    ];
    final fields =
        <
          ({
            AcpResourceDescriptor resource,
            String? actionName,
            AcpFieldDescriptor field,
          })
        >[];

    for (final resource in resources) {
      fields.addAll(
        resource.createFields.map(
          (field) => (resource: resource, actionName: null, field: field),
        ),
      );
      fields.addAll(
        resource.updateFields.map(
          (field) => (resource: resource, actionName: null, field: field),
        ),
      );
      for (final action in <AcpActionDescriptor>[
        ...resource.collectionActions,
        ...resource.entityActions,
      ]) {
        fields.addAll(
          action.fields.map(
            (field) =>
                (resource: resource, actionName: action.name, field: field),
          ),
        );
      }
    }

    final fallbackPrefixes = <String>[
      'Backend field "',
      'Whole-number value for "',
      'Controls whether "',
      'JSON value for "',
      'UTC timestamp for "',
      'Free-text value for "',
    ];
    final checked = <String>{};
    final incomplete = <String>[];

    for (final entry in fields) {
      final identity = <String>[
        entry.resource.entitySet,
        entry.actionName ?? '',
        entry.field.key,
      ].join('::');
      if (!checked.add(identity)) {
        continue;
      }
      final guidance = acpFieldHelpText(
        key: entry.field.key,
        label: entry.field.label,
        kind: entry.field.kind,
        resourceKey: entry.resource.key,
        entitySet: entry.resource.entitySet,
        actionName: entry.actionName,
      );

      final isFallback = fallbackPrefixes.any(guidance.startsWith);
      if (guidance.trim().length < 50 || isFallback) {
        incomplete.add('$identity => $guidance');
      }
    }

    expect(
      incomplete,
      isEmpty,
      reason: 'Built-in fields must not rely on generic fallback guidance.',
    );
  });
}
