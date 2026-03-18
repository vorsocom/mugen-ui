import 'package:flutter/material.dart';

enum AcpScopeMode { none, required, optional }

enum AcpActionTarget { collection, entity }

enum AcpFieldKind { text, multiline, boolean, integer, json, dateTime }

typedef AcpRow = Map<String, dynamic>;

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
}

class AcpColumnDescriptor {
  const AcpColumnDescriptor({
    required this.key,
    required this.label,
    this.flex = 1,
  });

  final String key;
  final String label;
  final int flex;
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
  });

  final String name;
  final String label;
  final AcpActionTarget target;
  final String? confirmMessage;
  final List<AcpFieldDescriptor> fields;
  final bool includeRowVersion;
  final IconData? icon;
  final String? successMessage;
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
  });

  final List<AcpRow> items;
  final int total;
  final int page;
  final int pageSize;

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
