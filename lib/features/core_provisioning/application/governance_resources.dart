import 'package:mugen_ui/features/core_provisioning/application/core_provisioning_descriptors.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';

final List<AcpResourceDescriptor> governanceResources = <AcpResourceDescriptor>[
  AcpResourceDescriptor(
    key: 'ops-policy-definitions',
    title: 'Policy Definitions',
    entitySet: 'OpsPolicyDefinitions',
    scopeMode: AcpScopeMode.required,
    keyLiteralType: AcpFilterLiteralType.guid,
    description:
        'Tenant governance policies with validated documents and guarded evaluation and activation actions.',
    columns: <AcpColumnDescriptor>[
      coreColumn('Code', 'Code'),
      coreColumn('Name', 'Name', flex: 2),
      coreColumn('PolicyType', 'Policy Type'),
      coreColumn('Version', 'Version'),
      coreColumn('IsActive', 'Active'),
      coreColumn('EvaluationMode', 'Evaluation Mode'),
    ],
    createFields: <AcpFieldDescriptor>[
      coreText('Code', 'Code', required: true),
      coreText('Name', 'Name', required: true),
      coreMultiline('Description', 'Description'),
      coreText('PolicyType', 'Policy Type'),
      coreText('RuleRef', 'Rule Reference'),
      coreText(
        'EvaluationMode',
        'Evaluation Mode',
        initialValue: 'advisory',
        options: const <String>['advisory', 'enforced'],
      ),
      coreText(
        'Engine',
        'Engine',
        initialValue: 'dsl',
        options: const <String>['dsl'],
      ),
      coreInteger(
        'Version',
        'Version',
        minimumValue: 1,
        initialValue: 1,
        applyAfterCreate: true,
      ),
      coreJson(
        'DocumentJson',
        'Policy Document',
        required: true,
        initialValue: const <String, dynamic>{},
      ),
      coreJson('Attributes', 'Attributes'),
    ],
    updateFields: <AcpFieldDescriptor>[
      coreText('Code', 'Code'),
      coreText('Name', 'Name'),
      coreMultiline('Description', 'Description'),
      coreText('PolicyType', 'Policy Type'),
      coreText('RuleRef', 'Rule Reference'),
      coreText(
        'EvaluationMode',
        'Evaluation Mode',
        options: const <String>['advisory', 'enforced'],
      ),
      coreText('Engine', 'Engine', options: const <String>['dsl']),
      coreInteger('Version', 'Version', minimumValue: 1),
      coreJson('DocumentJson', 'Policy Document'),
      coreJson('Attributes', 'Attributes'),
    ],
    entityActions: <AcpActionDescriptor>[
      AcpActionDescriptor(
        name: 'evaluate_policy',
        label: 'Evaluate Policy',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        successMessage: 'Policy evaluated.',
        visibleWhenEquals: const <String, List<Object>>{
          'IsActive': <Object>[true],
        },
        fields: <AcpFieldDescriptor>[
          coreText('TraceId', 'Trace ID'),
          coreText('SubjectNamespace', 'Subject Namespace', required: true),
          coreText('SubjectId', 'Subject ID'),
          coreText('SubjectRef', 'Subject Reference'),
          coreJson('InputJson', 'Input JSON'),
          coreJson('ActorJson', 'Actor JSON'),
          coreText(
            'Decision',
            'Decision',
            options: const <String>['allow', 'deny', 'warn', 'review'],
          ),
          coreText(
            'Outcome',
            'Outcome',
            options: const <String>['applied', 'blocked', 'deferred'],
          ),
          coreMultiline('Reason', 'Reason'),
          coreJson('RequestContext', 'Request Context'),
          coreJson('Attributes', 'Attributes'),
        ],
      ),
      AcpActionDescriptor(
        name: 'activate_version',
        label: 'Activate Version',
        target: AcpActionTarget.entity,
        includeRowVersion: true,
        confirmMessage: 'Activate this policy version?',
        successMessage: 'Policy version activated.',
        fields: <AcpFieldDescriptor>[
          coreInteger('Version', 'Version', required: true, minimumValue: 1),
        ],
      ),
    ],
    searchFields: const <String>['Code', 'Name', 'PolicyType', 'RuleRef'],
    defaultOrderBy: 'Code asc, Version desc',
    allowCreate: true,
    allowUpdate: true,
  ),
];
