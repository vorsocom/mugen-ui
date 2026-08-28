import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_reference_display.dart';

void main() {
  const plainColumn = AcpColumnDescriptor(key: 'Name', label: 'Name');
  const referenceColumn = AcpColumnDescriptor(
    key: 'AccountId',
    label: 'Account',
    reference: AcpColumnReferenceDescriptor(
      navigationPath: 'Account',
      titleFields: <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('DisplayName'),
        AcpReferenceFieldDescriptor('Code'),
      ],
      subtitleFields: <AcpReferenceFieldDescriptor>[
        AcpReferenceFieldDescriptor('Code'),
        AcpReferenceFieldDescriptor('Duplicate'),
        AcpReferenceFieldDescriptor('Active'),
      ],
    ),
  );

  test('returns scalar values for ordinary columns', () {
    expect(
      acpReferenceDisplayValue(
        row: <String, dynamic>{'Name': 'Example'},
        column: plainColumn,
      ),
      'Example',
    );
    expect(
      acpReferenceDisplayValue(
        row: const <String, dynamic>{},
        column: plainColumn,
      ),
      isEmpty,
    );
  });

  test('renders unassigned and UUID fallback states', () {
    expect(
      acpReferenceDisplayValue(
        row: const <String, dynamic>{'AccountId': null},
        column: referenceColumn,
      ),
      'Not assigned',
    );
    expect(
      acpReferenceDisplayValue(
        row: const <String, dynamic>{'AccountId': 'account-id'},
        column: referenceColumn,
      ),
      'account-id',
    );
    expect(
      acpReferenceDisplayValue(
        row: const <String, dynamic>{
          'AccountId': 'account-id',
          'Account': 'unavailable',
        },
        column: referenceColumn,
      ),
      'account-id',
    );
  });

  test('composes title and unique subtitles from expanded maps', () {
    final value = acpReferenceDisplayValue(
      row: const <String, dynamic>{
        'AccountId': 'account-id',
        'Account': <String, dynamic>{
          'DisplayName': 'Example Company',
          'Code': 'valet-primary',
          'Duplicate': 'VALET-PRIMARY',
          'Active': true,
        },
      },
      column: referenceColumn,
    );

    expect(value, 'Example Company · valet-primary · Yes');
  });

  test('supports nested paths, prefixes, suffixes, and month-year values', () {
    const column = AcpColumnDescriptor(
      key: 'RuleId',
      label: 'Rule',
      reference: AcpColumnReferenceDescriptor(
        navigationPath: 'Rule',
        titleFields: <AcpReferenceFieldDescriptor>[
          AcpReferenceFieldDescriptor('Price.Product.Name'),
          AcpReferenceFieldDescriptor('Version', prefix: 'v'),
        ],
        subtitleFields: <AcpReferenceFieldDescriptor>[
          AcpReferenceFieldDescriptor(
            'PeriodStart',
            format: AcpReferenceValueFormat.monthYear,
          ),
          AcpReferenceFieldDescriptor('Included', suffix: ' included'),
        ],
      ),
    );

    expect(
      acpReferenceDisplayValue(
        row: <String, dynamic>{
          'RuleId': 'rule-id',
          'Rule': <String, dynamic>{
            'Price': <String, dynamic>{
              'Product': <String, dynamic>{'Name': 'Standard package'},
            },
            'Version': 3,
            'PeriodStart': DateTime.utc(2026, 8, 1),
            'Included': 350,
          },
        },
        column: column,
      ),
      'Standard package · Aug 2026 · 350 included',
    );
  });

  test('ignores unusable fields and falls back when no label is available', () {
    const column = AcpColumnDescriptor(
      key: 'RuleId',
      label: 'Rule',
      reference: AcpColumnReferenceDescriptor(
        navigationPath: 'Wrapper.Rule',
        titleFields: <AcpReferenceFieldDescriptor>[
          AcpReferenceFieldDescriptor('Missing'),
          AcpReferenceFieldDescriptor('Object'),
          AcpReferenceFieldDescriptor('Empty'),
        ],
        subtitleFields: <AcpReferenceFieldDescriptor>[
          AcpReferenceFieldDescriptor('Items'),
          AcpReferenceFieldDescriptor(
            'InvalidDate',
            format: AcpReferenceValueFormat.monthYear,
          ),
        ],
      ),
    );

    expect(
      acpReferenceDisplayValue(
        row: const <String, dynamic>{
          'RuleId': 'rule-id',
          'Wrapper': <String, dynamic>{
            'Rule': <String, dynamic>{
              'Object': <String, dynamic>{},
              'Empty': '  ',
              'Items': <Object>[],
              'InvalidDate': 'not-a-date',
            },
          },
        },
        column: column,
      ),
      'rule-id',
    );
    expect(
      acpReferenceDisplayValue(
        row: const <String, dynamic>{
          'RuleId': 'rule-id',
          'Wrapper': <String, dynamic>{},
        },
        column: column,
      ),
      'rule-id',
    );
  });
}
