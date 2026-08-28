import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';

String acpReferenceDisplayValue({
  required AcpRow row,
  required AcpColumnDescriptor column,
}) {
  final reference = column.reference;
  if (reference == null) {
    return row[column.key]?.toString() ?? '';
  }

  final rawValue = row[column.key]?.toString().trim() ?? '';
  if (rawValue.isEmpty) {
    return reference.unassignedLabel;
  }

  final expanded = _readPath(row, reference.navigationPath);
  if (expanded is! Map) {
    return rawValue;
  }

  final values = <String>[];
  final normalizedValues = <String>{};
  for (final field in reference.titleFields) {
    final value = _formatField(expanded, field);
    if (value == null) {
      continue;
    }
    _addUnique(values, normalizedValues, value);
    break;
  }
  for (final field in reference.subtitleFields) {
    final value = _formatField(expanded, field);
    if (value != null) {
      _addUnique(values, normalizedValues, value);
    }
  }

  return values.isEmpty ? rawValue : values.join(' · ');
}

Object? _readPath(Object? value, String path) {
  Object? current = value;
  for (final segment in path.split('.')) {
    if (current is! Map || !current.containsKey(segment)) {
      return null;
    }
    current = current[segment];
  }
  return current;
}

String? _formatField(
  Map<dynamic, dynamic> expanded,
  AcpReferenceFieldDescriptor field,
) {
  final value = _readPath(expanded, field.path);
  if (value == null || value is Map || value is List) {
    return null;
  }

  final formatted = switch (field.format) {
    AcpReferenceValueFormat.plain =>
      value is bool ? (value ? 'Yes' : 'No') : value.toString().trim(),
    AcpReferenceValueFormat.monthYear => _formatMonthYear(value),
  };
  if (formatted == null || formatted.isEmpty) {
    return null;
  }
  return '${field.prefix}$formatted${field.suffix}'.trim();
}

String? _formatMonthYear(Object value) {
  final parsed = value is DateTime
      ? value
      : DateTime.tryParse(value.toString().trim());
  if (parsed == null) {
    return null;
  }
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[parsed.month - 1]} ${parsed.year}';
}

void _addUnique(
  List<String> values,
  Set<String> normalizedValues,
  String value,
) {
  final normalized = value.toLowerCase();
  if (normalizedValues.add(normalized)) {
    values.add(value);
  }
}
