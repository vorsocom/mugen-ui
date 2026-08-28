import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';

AcpColumnDescriptor coreColumn(
  String key,
  String label, {
  int flex = 1,
  bool money = false,
  String minorUnitKey = '_CurrencyMinorUnit',
  String currencyCodeKey = 'Currency',
  int defaultMinorUnit = 2,
  AcpColumnValueBuilder? valueBuilder,
  AcpColumnReferenceDescriptor? reference,
  bool opaqueIdentifier = false,
}) {
  return AcpColumnDescriptor(
    key: key,
    label: label,
    flex: flex,
    money: money,
    minorUnitKey: minorUnitKey,
    currencyCodeKey: currencyCodeKey,
    defaultMinorUnit: defaultMinorUnit,
    valueBuilder: valueBuilder,
    reference: reference,
    opaqueIdentifier: opaqueIdentifier,
  );
}

AcpColumnReferenceDescriptor coreBatchReference({
  required String navigationPath,
  required String entitySet,
  required AcpScopeMode scopeMode,
  required List<String> selectFields,
  required List<AcpReferenceFieldDescriptor> titleFields,
  List<AcpReferenceFieldDescriptor> subtitleFields =
      const <AcpReferenceFieldDescriptor>[],
  AcpDeletedView deletedView = AcpDeletedView.active,
}) {
  return AcpColumnReferenceDescriptor(
    navigationPath: navigationPath,
    titleFields: titleFields,
    subtitleFields: subtitleFields,
    batchLookup: AcpBatchReferenceDescriptor(
      entitySet: entitySet,
      scopeMode: scopeMode,
      selectFields: selectFields,
      deletedView: deletedView,
    ),
  );
}

AcpFieldDescriptor coreText(
  String key,
  String label, {
  bool required = false,
  Map<String, List<String>> requiredWhenEquals = const <String, List<String>>{},
  String? hintText,
  Object? initialValue,
  List<String> options = const <String>[],
  bool applyAfterCreate = false,
  Map<String, List<Object>> visibleWhenEquals = const <String, List<Object>>{},
  AcpFieldReferenceDescriptor? reference,
  String? payloadContainerKey,
  String? payloadMapKey,
  bool hidden = false,
  bool includeInPayload = true,
  bool clearWhenHidden = false,
  bool submitNullWhenHidden = false,
  AcpInitialValueFactory? initialValueFactory,
  AcpComputedValueBuilder? computedValueBuilder,
  bool readOnly = false,
}) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    required: required,
    requiredWhenEquals: requiredWhenEquals,
    hintText: hintText,
    initialValue: initialValue,
    options: options,
    applyAfterCreate: applyAfterCreate,
    visibleWhenEquals: visibleWhenEquals,
    reference: reference,
    payloadContainerKey: payloadContainerKey,
    payloadMapKey: payloadMapKey,
    hidden: hidden,
    includeInPayload: includeInPayload,
    clearWhenHidden: clearWhenHidden,
    submitNullWhenHidden: submitNullWhenHidden,
    initialValueFactory: initialValueFactory,
    computedValueBuilder: computedValueBuilder,
    readOnly: readOnly,
  );
}

AcpFieldDescriptor coreComputed(
  String key,
  String label,
  AcpComputedValueBuilder builder,
) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    kind: AcpFieldKind.computed,
    readOnly: true,
    includeInPayload: false,
    computedValueBuilder: builder,
  );
}

AcpFieldDescriptor coreMoney(
  String key,
  String label, {
  bool required = false,
  bool applyAfterCreate = false,
  String minorUnitFieldKey = '_CurrencyMinorUnit',
  String currencyCodeFieldKey = '_CurrencyCode',
  int defaultMinorUnit = 2,
}) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    kind: AcpFieldKind.money,
    required: required,
    applyAfterCreate: applyAfterCreate,
    minorUnitFieldKey: minorUnitFieldKey,
    currencyCodeFieldKey: currencyCodeFieldKey,
    defaultMinorUnit: defaultMinorUnit,
    hintText: 'Enter the amount in major currency units.',
  );
}

AcpFieldDescriptor coreInternalText(String key, {Object? initialValue}) {
  return coreText(
    key,
    key,
    hidden: true,
    includeInPayload: false,
    initialValue: initialValue,
  );
}

AcpFieldDescriptor coreMultiline(
  String key,
  String label, {
  bool required = false,
  bool applyAfterCreate = false,
}) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    kind: AcpFieldKind.multiline,
    required: required,
    minLines: 3,
    maxLines: 6,
    applyAfterCreate: applyAfterCreate,
  );
}

AcpFieldDescriptor coreBool(
  String key,
  String label, {
  Object? initialValue,
  bool applyAfterCreate = false,
}) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    kind: AcpFieldKind.boolean,
    initialValue: initialValue,
    applyAfterCreate: applyAfterCreate,
  );
}

AcpFieldDescriptor coreInteger(
  String key,
  String label, {
  bool required = false,
  int? minimumValue,
  int? maximumValue,
  Object? initialValue,
  bool applyAfterCreate = false,
}) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    kind: AcpFieldKind.integer,
    required: required,
    minimumValue: minimumValue,
    maximumValue: maximumValue,
    initialValue: initialValue,
    applyAfterCreate: applyAfterCreate,
  );
}

AcpFieldDescriptor coreJson(
  String key,
  String label, {
  bool required = false,
  Object? initialValue,
  bool applyAfterCreate = false,
  List<String> excludedJsonKeys = const <String>[],
}) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    kind: AcpFieldKind.json,
    required: required,
    minLines: 5,
    maxLines: 10,
    initialValue: initialValue,
    applyAfterCreate: applyAfterCreate,
    excludedJsonKeys: excludedJsonKeys,
  );
}

AcpFieldDescriptor coreDateTime(
  String key,
  String label, {
  bool required = false,
  bool applyAfterCreate = false,
}) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    kind: AcpFieldKind.dateTime,
    required: required,
    hintText: 'ISO-8601 with timezone, for example 2026-08-26T12:00:00Z',
    applyAfterCreate: applyAfterCreate,
  );
}

AcpFieldDescriptor coreTimeOfDay(
  String key,
  String label, {
  bool applyAfterCreate = false,
}) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    kind: AcpFieldKind.timeOfDay,
    hintText: '24-hour time, for example 09:00 or 17:30:00',
    applyAfterCreate: applyAfterCreate,
  );
}

AcpFieldDescriptor coreIntegerList(
  String key,
  String label, {
  int? minimumValue,
  int? maximumValue,
  bool applyAfterCreate = false,
}) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    kind: AcpFieldKind.integerList,
    hintText: 'Comma-separated whole numbers or a JSON array',
    minimumValue: minimumValue,
    maximumValue: maximumValue,
    applyAfterCreate: applyAfterCreate,
  );
}

AcpFieldDescriptor coreStringList(
  String key,
  String label, {
  AcpFieldReferenceDescriptor? reference,
  bool applyAfterCreate = false,
}) {
  return AcpFieldDescriptor(
    key: key,
    label: label,
    kind: AcpFieldKind.stringList,
    reference: reference,
    applyAfterCreate: applyAfterCreate,
  );
}

AcpFieldDescriptor coreReference(
  String key,
  String label, {
  required String entitySet,
  required AcpScopeMode scopeMode,
  bool required = false,
  bool applyAfterCreate = false,
  String valueField = 'Id',
  List<String> searchFields = const <String>[],
  List<String> titleFields = const <String>[],
  List<String> subtitleFields = const <String>[],
  String? defaultOrderBy,
  List<String> extraFilters = const <String>[],
  Map<String, String> filterFieldsFromForm = const <String, String>{},
  Map<String, String> copyFieldsFromSelection = const <String, String>{},
  bool retainHistoricalSelection = false,
  Map<String, List<Object>> visibleWhenEquals = const <String, List<Object>>{},
  bool clearWhenHidden = false,
  bool submitNullWhenHidden = false,
  String? hintText,
  AcpInitialValueFactory? initialValueFactory,
}) {
  return coreText(
    key,
    label,
    required: required,
    applyAfterCreate: applyAfterCreate,
    visibleWhenEquals: visibleWhenEquals,
    clearWhenHidden: clearWhenHidden,
    submitNullWhenHidden: submitNullWhenHidden,
    hintText: hintText,
    initialValueFactory: initialValueFactory,
    reference: AcpFieldReferenceDescriptor(
      entitySet: entitySet,
      scopeMode: scopeMode,
      title: label,
      valueField: valueField,
      searchFields: searchFields,
      titleFields: titleFields,
      subtitleFields: subtitleFields,
      defaultOrderBy: defaultOrderBy,
      extraFilters: extraFilters,
      filterFieldsFromForm: filterFieldsFromForm,
      copyFieldsFromSelection: copyFieldsFromSelection,
      retainHistoricalSelection: retainHistoricalSelection,
    ),
  );
}
