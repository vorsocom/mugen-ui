import 'package:mugen_ui/features/core_provisioning/application/core_provisioning_descriptors.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_standard_options.dart';

final List<AcpResourceDescriptor> slaResources = <AcpResourceDescriptor>[
  AcpResourceDescriptor(
    key: 'ops-sla-policies',
    title: 'SLA Policies',
    entitySet: 'OpsSlaPolicies',
    scopeMode: AcpScopeMode.required,
    description: 'Tenant SLA policies linked to searchable business calendars.',
    columns: <AcpColumnDescriptor>[
      coreColumn('Code', 'Code'),
      coreColumn('Name', 'Name', flex: 2),
      coreColumn(
        'CalendarId',
        'Calendar',
        flex: 2,
        reference: _calendarDisplay,
      ),
      coreColumn('IsActive', 'Active'),
    ],
    createFields: <AcpFieldDescriptor>[
      coreText('Code', 'Code', required: true),
      coreText('Name', 'Name', required: true),
      coreMultiline('Description', 'Description', applyAfterCreate: true),
      _calendar(applyAfterCreate: true),
      coreBool(
        'IsActive',
        'Is Active',
        initialValue: true,
        applyAfterCreate: true,
      ),
      coreJson('Attributes', 'Attributes', applyAfterCreate: true),
    ],
    updateFields: <AcpFieldDescriptor>[
      coreText('Code', 'Code'),
      coreText('Name', 'Name'),
      coreMultiline('Description', 'Description'),
      _calendar(),
      coreBool('IsActive', 'Is Active'),
      coreJson('Attributes', 'Attributes'),
    ],
    searchFields: const <String>['Code', 'Name', 'Description'],
    defaultOrderBy: 'Code asc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'ops-sla-calendars',
    title: 'SLA Calendars',
    entitySet: 'OpsSlaCalendars',
    scopeMode: AcpScopeMode.required,
    description:
        'Timezone-aware business windows, working days, and holiday references.',
    columns: <AcpColumnDescriptor>[
      coreColumn('Code', 'Code'),
      coreColumn('Name', 'Name', flex: 2),
      coreColumn('Timezone', 'Timezone'),
      coreColumn('BusinessStartTime', 'Start'),
      coreColumn('BusinessEndTime', 'End'),
      coreColumn('IsActive', 'Active'),
    ],
    createFields: <AcpFieldDescriptor>[
      coreText('Code', 'Code', required: true),
      coreText('Name', 'Name', required: true),
      coreText(
        'Timezone',
        'Timezone',
        required: true,
        hintText: 'IANA timezone, for example America/Guyana',
        options: acpIanaTimezoneOptions,
        searchableOptions: true,
      ),
      coreTimeOfDay(
        'BusinessStartTime',
        'Business Start Time',
        applyAfterCreate: true,
      ),
      coreTimeOfDay(
        'BusinessEndTime',
        'Business End Time',
        applyAfterCreate: true,
      ),
      coreIntegerList(
        'BusinessDays',
        'Business Days (1-7)',
        minimumValue: 1,
        maximumValue: 7,
        applyAfterCreate: true,
        options: acpBusinessDayLabels.keys.toList(growable: false),
        optionLabels: acpBusinessDayLabels,
        multiSelectOptions: true,
      ),
      coreStringList(
        'HolidayRefs',
        'Holiday Dates (ISO-8601)',
        applyAfterCreate: true,
      ),
      coreBool(
        'IsActive',
        'Is Active',
        initialValue: true,
        applyAfterCreate: true,
      ),
      coreJson('Attributes', 'Attributes', applyAfterCreate: true),
    ],
    updateFields: <AcpFieldDescriptor>[
      coreText('Code', 'Code'),
      coreText('Name', 'Name'),
      coreText(
        'Timezone',
        'Timezone',
        hintText: 'IANA timezone, for example America/Guyana',
        options: acpIanaTimezoneOptions,
        searchableOptions: true,
      ),
      coreTimeOfDay('BusinessStartTime', 'Business Start Time'),
      coreTimeOfDay('BusinessEndTime', 'Business End Time'),
      coreIntegerList(
        'BusinessDays',
        'Business Days (1-7)',
        minimumValue: 1,
        maximumValue: 7,
        options: acpBusinessDayLabels.keys.toList(growable: false),
        optionLabels: acpBusinessDayLabels,
        multiSelectOptions: true,
      ),
      coreStringList('HolidayRefs', 'Holiday Dates (ISO-8601)'),
      coreBool('IsActive', 'Is Active'),
      coreJson('Attributes', 'Attributes'),
    ],
    searchFields: const <String>['Code', 'Name', 'Timezone'],
    defaultOrderBy: 'Code asc',
    allowCreate: true,
    allowUpdate: true,
  ),
  AcpResourceDescriptor(
    key: 'ops-sla-targets',
    title: 'SLA Targets',
    entitySet: 'OpsSlaTargets',
    scopeMode: AcpScopeMode.required,
    description:
        'Typed metric, priority, severity, duration, warning, and breach targets.',
    columns: <AcpColumnDescriptor>[
      coreColumn('Metric', 'Metric'),
      coreColumn('Priority', 'Priority'),
      coreColumn('Severity', 'Severity'),
      coreColumn('TargetMinutes', 'Target Minutes'),
      coreColumn('WarnBeforeMinutes', 'Warn Before'),
      coreColumn('PolicyId', 'Policy', flex: 2, reference: _policyDisplay),
    ],
    createFields: <AcpFieldDescriptor>[
      _policy(required: true),
      coreText(
        'Metric',
        'Metric',
        required: true,
        options: const <String>['response', 'resolution'],
      ),
      coreInteger(
        'TargetMinutes',
        'Target Minutes',
        required: true,
        minimumValue: 1,
      ),
      coreText(
        'Priority',
        'Priority',
        options: const <String>['low', 'normal', 'high', 'urgent'],
      ),
      coreText(
        'Severity',
        'Severity',
        options: const <String>['low', 'medium', 'high', 'critical'],
      ),
      coreInteger('WarnBeforeMinutes', 'Warn Before Minutes', minimumValue: 0),
      coreBool('AutoBreach', 'Auto Breach'),
      coreJson('Attributes', 'Attributes'),
    ],
    updateFields: <AcpFieldDescriptor>[
      coreText(
        'Metric',
        'Metric',
        options: const <String>['response', 'resolution'],
      ),
      coreInteger('TargetMinutes', 'Target Minutes', minimumValue: 1),
      coreText(
        'Priority',
        'Priority',
        options: const <String>['low', 'normal', 'high', 'urgent'],
      ),
      coreText(
        'Severity',
        'Severity',
        options: const <String>['low', 'medium', 'high', 'critical'],
      ),
      coreInteger('WarnBeforeMinutes', 'Warn Before Minutes', minimumValue: 0),
      coreBool('AutoBreach', 'Auto Breach'),
      coreJson('Attributes', 'Attributes'),
    ],
    searchFields: const <String>['Metric', 'Priority', 'Severity'],
    defaultOrderBy: 'Metric asc, Priority asc, Severity asc',
    allowCreate: true,
    allowUpdate: true,
  ),
];

final AcpColumnReferenceDescriptor _calendarDisplay = coreBatchReference(
  navigationPath: 'Calendar',
  entitySet: 'OpsSlaCalendars',
  scopeMode: AcpScopeMode.required,
  selectFields: const <String>['Name', 'Code', 'Timezone'],
  titleFields: const <AcpReferenceFieldDescriptor>[
    AcpReferenceFieldDescriptor('Name'),
    AcpReferenceFieldDescriptor('Code'),
  ],
  subtitleFields: const <AcpReferenceFieldDescriptor>[
    AcpReferenceFieldDescriptor('Code'),
    AcpReferenceFieldDescriptor('Timezone'),
  ],
);

final AcpColumnReferenceDescriptor _policyDisplay = coreBatchReference(
  navigationPath: 'Policy',
  entitySet: 'OpsSlaPolicies',
  scopeMode: AcpScopeMode.required,
  selectFields: const <String>['Name', 'Code'],
  titleFields: const <AcpReferenceFieldDescriptor>[
    AcpReferenceFieldDescriptor('Name'),
    AcpReferenceFieldDescriptor('Code'),
  ],
  subtitleFields: const <AcpReferenceFieldDescriptor>[
    AcpReferenceFieldDescriptor('Code'),
  ],
);

AcpFieldDescriptor _calendar({bool applyAfterCreate = false}) {
  return coreReference(
    'CalendarId',
    'Calendar',
    entitySet: 'OpsSlaCalendars',
    scopeMode: AcpScopeMode.required,
    applyAfterCreate: applyAfterCreate,
    searchFields: const <String>['Code', 'Name', 'Timezone'],
    titleFields: const <String>['Name', 'Code'],
    subtitleFields: const <String>['Code', 'Timezone', 'IsActive', 'Id'],
    defaultOrderBy: 'Code asc',
  );
}

AcpFieldDescriptor _policy({bool required = false}) {
  return coreReference(
    'PolicyId',
    'SLA Policy',
    entitySet: 'OpsSlaPolicies',
    scopeMode: AcpScopeMode.required,
    required: required,
    searchFields: const <String>['Code', 'Name'],
    titleFields: const <String>['Name', 'Code'],
    subtitleFields: const <String>['Code', 'IsActive', 'Id'],
    defaultOrderBy: 'Code asc',
  );
}
