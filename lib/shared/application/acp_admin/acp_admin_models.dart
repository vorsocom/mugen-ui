import 'package:flutter/material.dart';

enum AcpScopeMode { none, required, optional }

enum AcpActionTarget { collection, entity }

enum AcpDeletedView { active, all, archived }

enum AcpFilterLiteralType { string, guid }

enum AcpReferenceValueFormat { plain, monthYear }

enum AcpFieldKind {
  text,
  multiline,
  boolean,
  integer,
  money,
  computed,
  integerList,
  stringList,
  json,
  dateTime,
  timeOfDay,
}

typedef AcpPayloadValidator = String? Function(Map<String, dynamic> payload);
typedef AcpColumnValueBuilder = Object? Function(AcpRow row);
typedef AcpInitialValueFactory = Object? Function();
typedef AcpComputedValueBuilder = String Function(Map<String, String> values);
typedef AcpOptionsBuilder = List<String> Function(AcpRow values);

typedef AcpRow = Map<String, dynamic>;

class AcpExpandDescriptor {
  const AcpExpandDescriptor({
    required this.navigation,
    this.selectFields = const <String>[],
    this.expands = const <AcpExpandDescriptor>[],
  });

  final String navigation;
  final List<String> selectFields;
  final List<AcpExpandDescriptor> expands;
}

class AcpReferenceFieldDescriptor {
  const AcpReferenceFieldDescriptor(
    this.path, {
    this.prefix = '',
    this.suffix = '',
    this.format = AcpReferenceValueFormat.plain,
  });

  final String path;
  final String prefix;
  final String suffix;
  final AcpReferenceValueFormat format;
}

class AcpBatchReferenceDescriptor {
  const AcpBatchReferenceDescriptor({
    required this.entitySet,
    required this.scopeMode,
    required this.selectFields,
    this.idField = 'Id',
    this.literalType = AcpFilterLiteralType.string,
    this.deletedView = AcpDeletedView.active,
  });

  final String entitySet;
  final AcpScopeMode scopeMode;
  final List<String> selectFields;
  final String idField;
  final AcpFilterLiteralType literalType;
  final AcpDeletedView deletedView;
}

class AcpColumnReferenceDescriptor {
  const AcpColumnReferenceDescriptor({
    required this.navigationPath,
    required this.titleFields,
    this.subtitleFields = const <AcpReferenceFieldDescriptor>[],
    this.batchLookup,
    this.unassignedLabel = 'Not assigned',
  });

  final String navigationPath;
  final List<AcpReferenceFieldDescriptor> titleFields;
  final List<AcpReferenceFieldDescriptor> subtitleFields;
  final AcpBatchReferenceDescriptor? batchLookup;
  final String unassignedLabel;
}

class AcpFieldDescriptor {
  const AcpFieldDescriptor({
    required this.key,
    required this.label,
    this.kind = AcpFieldKind.text,
    this.required = false,
    this.requiredWhenEquals = const <String, List<String>>{},
    this.hintText,
    this.minLines,
    this.maxLines,
    this.obscureText = false,
    this.initialValue,
    this.options = const <String>[],
    this.optionsBuilder,
    this.optionLabels = const <String, String>{},
    this.searchableOptions = false,
    this.allowCustomOption = false,
    this.multiSelectOptions = false,
    this.reference,
    this.readOnly = false,
    this.minimumValue,
    this.maximumValue,
    this.visibleWhenEquals = const <String, List<Object>>{},
    this.applyAfterCreate = false,
    this.payloadContainerKey,
    this.payloadMapKey,
    this.excludedJsonKeys = const <String>[],
    this.hidden = false,
    this.includeInPayload = true,
    this.clearWhenHidden = false,
    this.submitNullWhenHidden = false,
    this.minorUnitFieldKey,
    this.currencyCodeFieldKey,
    this.defaultMinorUnit = 2,
    this.initialValueFactory,
    this.computedValueBuilder,
  });

  final String key;
  final String label;
  final AcpFieldKind kind;
  final bool required;
  final Map<String, List<String>> requiredWhenEquals;
  final String? hintText;
  final int? minLines;
  final int? maxLines;
  final bool obscureText;
  final Object? initialValue;
  final List<String> options;
  final AcpOptionsBuilder? optionsBuilder;
  final Map<String, String> optionLabels;
  final bool searchableOptions;
  final bool allowCustomOption;
  final bool multiSelectOptions;
  final AcpFieldReferenceDescriptor? reference;
  final bool readOnly;
  final int? minimumValue;
  final int? maximumValue;
  final Map<String, List<Object>> visibleWhenEquals;
  final bool applyAfterCreate;
  final String? payloadContainerKey;
  final String? payloadMapKey;
  final List<String> excludedJsonKeys;
  final bool hidden;
  final bool includeInPayload;
  final bool clearWhenHidden;
  final bool submitNullWhenHidden;
  final String? minorUnitFieldKey;
  final String? currencyCodeFieldKey;
  final int defaultMinorUnit;
  final AcpInitialValueFactory? initialValueFactory;
  final AcpComputedValueBuilder? computedValueBuilder;
}

class AcpFieldReferenceDescriptor {
  const AcpFieldReferenceDescriptor({
    required this.entitySet,
    required this.scopeMode,
    required this.title,
    this.idField = 'Id',
    this.searchFields = const <String>[],
    this.titleFields = const <String>[],
    this.subtitleFields = const <String>[],
    this.defaultOrderBy,
    this.pageSize = 20,
    this.valueField = 'Id',
    this.multiSelect = false,
    this.extraFilters = const <String>[],
    this.filterFieldsFromForm = const <String, String>{},
    this.copyFieldsFromSelection = const <String, String>{},
    this.retainHistoricalSelection = false,
  });

  final String entitySet;
  final AcpScopeMode scopeMode;
  final String title;
  final String idField;
  final List<String> searchFields;
  final List<String> titleFields;
  final List<String> subtitleFields;
  final String? defaultOrderBy;
  final int pageSize;
  final String valueField;
  final bool multiSelect;
  final List<String> extraFilters;

  /// Maps a referenced resource field to the current form field supplying its
  /// filter value, for example `WorkflowVersionId -> WorkflowVersionId`.
  final Map<String, String> filterFieldsFromForm;

  /// Maps fields on the selected row to other form fields. This supports
  /// dependent typed inputs without placing reference records in payloads.
  final Map<String, String> copyFieldsFromSelection;

  /// Exact-ID hydration ignores active-only search filters so an existing
  /// historical relationship remains understandable.
  final bool retainHistoricalSelection;
}

class AcpColumnDescriptor {
  const AcpColumnDescriptor({
    required this.key,
    required this.label,
    this.flex = 1,
    this.money = false,
    this.minorUnitKey = '_CurrencyMinorUnit',
    this.currencyCodeKey = 'Currency',
    this.defaultMinorUnit = 2,
    this.valueBuilder,
    this.reference,
    this.opaqueIdentifier = false,
  });

  final String key;
  final String label;
  final int flex;
  final bool money;
  final String minorUnitKey;
  final String currencyCodeKey;
  final int defaultMinorUnit;
  final AcpColumnValueBuilder? valueBuilder;
  final AcpColumnReferenceDescriptor? reference;
  final bool opaqueIdentifier;
}

class AcpActionDescriptor {
  const AcpActionDescriptor({
    required this.name,
    required this.label,
    required this.target,
    this.confirmMessage,
    this.fields = const <AcpFieldDescriptor>[],
    this.includeRowVersion = false,
    this.icon,
    this.successMessage,
    this.showInToolbar = true,
    this.showInRowMenu = false,
    this.prefillFieldsFromRow = false,
    this.showAsRowButton = false,
    this.visibleWhenEquals = const <String, List<Object>>{},
    this.refreshResourceKeys = const <String>[],
    this.payloadValidator,
  });

  final String name;
  final String label;
  final AcpActionTarget target;
  final String? confirmMessage;
  final List<AcpFieldDescriptor> fields;
  final bool includeRowVersion;
  final IconData? icon;
  final String? successMessage;
  final bool showInToolbar;
  final bool showInRowMenu;
  final bool prefillFieldsFromRow;
  final bool showAsRowButton;
  final Map<String, List<Object>> visibleWhenEquals;
  final List<String> refreshResourceKeys;
  final AcpPayloadValidator? payloadValidator;

  bool isVisibleFor(AcpRow row) => acpRowMatches(row, visibleWhenEquals);
}

class AcpResourceDescriptor {
  const AcpResourceDescriptor({
    required this.key,
    required this.title,
    required this.entitySet,
    required this.scopeMode,
    required this.columns,
    this.description,
    this.createFields = const <AcpFieldDescriptor>[],
    this.updateFields = const <AcpFieldDescriptor>[],
    this.collectionActions = const <AcpActionDescriptor>[],
    this.entityActions = const <AcpActionDescriptor>[],
    this.searchFields = const <String>[],
    this.defaultOrderBy,
    this.emptyMessage = 'No rows found.',
    this.allowCreate = false,
    this.allowUpdate = false,
    this.allowDelete = false,
    this.allowRestore = false,
    this.pageSize = 15,
    this.actionsColumnLeading = false,
    this.updateWhenEquals = const <String, List<Object>>{},
    this.group,
    this.refreshResourceKeys = const <String>[],
    this.payloadValidator,
    this.deletedViews = const <AcpDeletedView>[AcpDeletedView.active],
    this.expansions = const <AcpExpandDescriptor>[],
    this.keyLiteralType = AcpFilterLiteralType.string,
  });

  final String key;
  final String title;
  final String entitySet;
  final AcpScopeMode scopeMode;
  final List<AcpColumnDescriptor> columns;
  final String? description;
  final List<AcpFieldDescriptor> createFields;
  final List<AcpFieldDescriptor> updateFields;
  final List<AcpActionDescriptor> collectionActions;
  final List<AcpActionDescriptor> entityActions;
  final List<String> searchFields;
  final String? defaultOrderBy;
  final String emptyMessage;
  final bool allowCreate;
  final bool allowUpdate;
  final bool allowDelete;
  final bool allowRestore;
  final int pageSize;
  final bool actionsColumnLeading;
  final Map<String, List<Object>> updateWhenEquals;
  final String? group;
  final List<String> refreshResourceKeys;
  final AcpPayloadValidator? payloadValidator;
  final List<AcpDeletedView> deletedViews;
  final List<AcpExpandDescriptor> expansions;
  final AcpFilterLiteralType keyLiteralType;

  bool canUpdate(AcpRow row) =>
      allowUpdate && acpRowMatches(row, updateWhenEquals);
}

bool acpRowMatches(AcpRow row, Map<String, List<Object>> expectedValues) {
  for (final entry in expectedValues.entries) {
    final actual = row[entry.key];
    if (!entry.value.any((expected) => _acpValuesEqual(actual, expected))) {
      return false;
    }
  }
  return true;
}

bool _acpValuesEqual(Object? actual, Object? expected) {
  if (actual is bool || expected is bool) {
    return actual.toString().toLowerCase() == expected.toString().toLowerCase();
  }
  return actual?.toString().trim().toLowerCase() ==
      expected?.toString().trim().toLowerCase();
}

class AcpTenantOption {
  const AcpTenantOption({required this.id, required this.name, this.slug});

  final String id;
  final String name;
  final String? slug;

  String get label {
    final trimmedSlug = slug?.trim();
    if (trimmedSlug == null || trimmedSlug.isEmpty) {
      return name;
    }

    return '$name ($trimmedSlug)';
  }
}

class AcpRowPage {
  const AcpRowPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    this.referenceWarning,
  });

  final List<AcpRow> items;
  final int total;
  final int page;
  final int pageSize;
  final String? referenceWarning;

  int get pages {
    if (pageSize <= 0) {
      return 1;
    }

    final computed = (total / pageSize).ceil();
    return computed <= 0 ? 1 : computed;
  }
}

extension AcpRowX on AcpRow {
  String? get id {
    final raw = this['Id'];
    if (raw == null) {
      return null;
    }

    final text = raw.toString().trim();
    return text.isEmpty ? null : text;
  }

  String? get tenantId {
    final raw = this['TenantId'];
    if (raw == null) {
      return null;
    }

    final text = raw.toString().trim();
    return text.isEmpty ? null : text;
  }

  int? get rowVersion {
    final raw = this['RowVersion'];
    if (raw is int) {
      return raw;
    }

    return int.tryParse(raw?.toString() ?? '');
  }
}
