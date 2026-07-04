// coverage:ignore-file

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

const double adminPageGutter = 16;
const double adminSectionGap = 12;
const double adminControlHeight = 36;
const double adminInputHeight = 40;
const double adminRowMinHeight = 44;
const double adminRowMaxHeight = 52;
const double adminRadius = 8;
const double adminCompactRadius = 6;

class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.primaryAction,
  });

  final String title;
  final String subtitle;
  final Widget? primaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: adminSectionGap),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 280, maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppUiPalette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppUiPalette.textSecondary,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          ?primaryAction,
        ],
      ),
    );
  }
}

class AdminSurface extends StatelessWidget {
  const AdminSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppUiPalette.surface,
        borderRadius: BorderRadius.circular(adminRadius),
        border: Border.all(color: AppUiPalette.border),
      ),
      child: child,
    );
  }
}

class AdminToolbar extends StatelessWidget {
  const AdminToolbar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }
}

class AdminTabItem {
  const AdminTabItem({
    required this.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.count,
    this.tooltip,
  });

  final Key key;
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final int? count;
  final String? tooltip;
}

class AdminTabs extends StatelessWidget {
  const AdminTabs({super.key, required this.items});

  final List<AdminTabItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final item in items) ...[
              _AdminTabButton(item: item),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdminTabButton extends StatelessWidget {
  const _AdminTabButton({required this.item});

  final AdminTabItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = item.selected
        ? AppUiPalette.textPrimary
        : AppUiPalette.textSecondary;
    final child = Material(
      color: item.selected ? AppUiPalette.accentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(adminCompactRadius),
      child: InkWell(
        key: item.key,
        borderRadius: BorderRadius.circular(adminCompactRadius),
        onTap: item.selected ? null : item.onSelected,
        child: Container(
          constraints: const BoxConstraints(minHeight: 34),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(adminCompactRadius),
            border: Border(
              bottom: BorderSide(
                color: item.selected ? AppUiPalette.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: foreground,
                  fontWeight: item.selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (item.count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: item.selected
                        ? AppUiPalette.surface
                        : AppUiPalette.surfaceMuted,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppUiPalette.border),
                  ),
                  child: Text(
                    '${item.count}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppUiPalette.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    final message = item.tooltip?.trim();
    if (message == null || message.isEmpty) {
      return child;
    }

    return Tooltip(message: message, child: child);
  }
}

class AdminEmptyStateData {
  const AdminEmptyStateData({
    required this.title,
    required this.message,
    this.primaryAction,
    this.secondaryAction,
  });

  final String title;
  final String message;
  final Widget? primaryAction;
  final Widget? secondaryAction;
}

class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({super.key, required this.data});

  final AdminEmptyStateData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 28,
                color: AppUiPalette.textSecondary,
              ),
              const SizedBox(height: 10),
              Text(
                data.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppUiPalette.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                data.message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppUiPalette.textSecondary,
                  height: 1.3,
                ),
              ),
              if (data.primaryAction != null || data.secondaryAction != null)
                const SizedBox(height: 14),
              if (data.primaryAction != null || data.secondaryAction != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (data.primaryAction != null) data.primaryAction!,
                    if (data.secondaryAction != null) data.secondaryAction!,
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminGridColumn<T> {
  const AdminGridColumn({
    required this.key,
    required this.label,
    required this.cell,
    this.flex = 1,
    this.width,
  });

  final String key;
  final String label;
  final Widget Function(BuildContext context, T row) cell;
  final int flex;
  final double? width;
}

enum AdminGridActionStyle { normal, destructive }

class AdminGridAction<T> {
  const AdminGridAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.key,
    this.style = AdminGridActionStyle.normal,
  });

  final Key? key;
  final IconData icon;
  final String tooltip;
  final VoidCallback? Function(T row) onPressed;
  final AdminGridActionStyle style;
}

class AdminDataGrid<T> extends StatelessWidget {
  const AdminDataGrid({
    super.key,
    required this.rows,
    required this.columns,
    this.actions = const [],
    this.actionsBuilder,
    this.actionsWidth,
    this.rowKey,
    this.onRowSelected,
    this.isRowSelected,
    this.isLoading = false,
    this.hasActiveFilter = false,
    required this.emptyState,
    required this.filteredEmptyState,
    this.minWidth = 920,
    this.footer,
  });

  final List<T> rows;
  final List<AdminGridColumn<T>> columns;
  final List<AdminGridAction<T>> actions;
  final Widget Function(BuildContext context, T row)? actionsBuilder;
  final double? actionsWidth;
  final String Function(T row)? rowKey;
  final ValueChanged<T>? onRowSelected;
  final bool Function(T row)? isRowSelected;
  final bool isLoading;
  final bool hasActiveFilter;
  final AdminEmptyStateData emptyState;
  final AdminEmptyStateData filteredEmptyState;
  final double minWidth;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final body = Stack(
      children: [
        Positioned.fill(
          child: rows.isEmpty && !isLoading
              ? AdminEmptyState(
                  data: hasActiveFilter ? filteredEmptyState : emptyState,
                )
              : _buildTable(context),
        ),
        if (isLoading)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );

    if (footer == null) {
      return body;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: body),
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppUiPalette.border)),
          ),
          child: footer!,
        ),
      ],
    );
  }

  Widget _buildTable(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : minWidth;
        final tableWidth = math.max(availableWidth, minWidth);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: SingleChildScrollView(
              child: DataTable(
                horizontalMargin: 14,
                columnSpacing: 18,
                dataRowMinHeight: adminRowMinHeight,
                dataRowMaxHeight: adminRowMaxHeight,
                headingRowHeight: adminRowMinHeight,
                headingRowColor: const WidgetStatePropertyAll<Color?>(
                  AppUiPalette.surfaceMuted,
                ),
                headingTextStyle: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(
                      color: AppUiPalette.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                columns: [
                  for (final column in columns)
                    DataColumn(
                      columnWidth: column.width == null
                          ? FlexColumnWidth(math.max(column.flex.toDouble(), 1))
                          : FixedColumnWidth(column.width!),
                      label: Expanded(child: _AdminHeaderText(column.label)),
                    ),
                  if (actions.isNotEmpty || actionsBuilder != null)
                    DataColumn(
                      columnWidth: actionsWidth == null
                          ? const IntrinsicColumnWidth()
                          : FixedColumnWidth(actionsWidth!),
                      label: const Expanded(child: _AdminHeaderText('Actions')),
                    ),
                ],
                rows: [
                  for (final row in rows)
                    DataRow(
                      key: rowKey == null
                          ? null
                          : ValueKey<String>(rowKey!(row)),
                      selected: isRowSelected?.call(row) ?? false,
                      onSelectChanged: onRowSelected == null
                          ? null
                          : (_) => onRowSelected!(row),
                      color: WidgetStateProperty.resolveWith<Color?>((states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppUiPalette.accentSoft;
                        }
                        if (states.contains(WidgetState.hovered)) {
                          return AppUiPalette.surfaceMuted.withValues(
                            alpha: 0.6,
                          );
                        }
                        return null;
                      }),
                      cells: [
                        for (final column in columns)
                          DataCell(column.cell(context, row)),
                        if (actions.isNotEmpty || actionsBuilder != null)
                          DataCell(
                            actionsBuilder?.call(context, row) ??
                                _AdminRowActions<T>(row: row, actions: actions),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AdminHeaderText extends StatelessWidget {
  const _AdminHeaderText(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(value, overflow: TextOverflow.ellipsis);
  }
}

class AdminCellText extends StatelessWidget {
  const AdminCellText(this.value, {super.key, this.maxLines = 1});

  final String value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final text = value.trim();
    return Tooltip(
      message: text,
      child: Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis),
    );
  }
}

class _AdminRowActions<T> extends StatelessWidget {
  const _AdminRowActions({required this.row, required this.actions});

  final T row;
  final List<AdminGridAction<T>> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (final action in actions)
          AdminIconButton(
            key: action.key,
            icon: action.icon,
            tooltip: action.tooltip,
            destructive: action.style == AdminGridActionStyle.destructive,
            onPressed: action.onPressed(row),
          ),
      ],
    );
  }
}

class AdminPaginationState {
  const AdminPaginationState({
    required this.visibleCount,
    required this.totalCount,
    required this.page,
    required this.pages,
    required this.pageSize,
    required this.pageSizes,
    required this.onPageSizeChanged,
    required this.onFirstPage,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onLastPage,
    this.label = 'Rows',
  });

  final int visibleCount;
  final int totalCount;
  final int page;
  final int pages;
  final int pageSize;
  final List<int> pageSizes;
  final ValueChanged<int> onPageSizeChanged;
  final VoidCallback? onFirstPage;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final VoidCallback? onLastPage;
  final String label;
}

class AdminGridFooter extends StatelessWidget {
  const AdminGridFooter({super.key, required this.state});

  final AdminPaginationState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = state.pages <= 0 ? 1 : state.pages;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              state.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppUiPalette.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 32,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(adminCompactRadius),
                  border: Border.all(color: AppUiPalette.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: state.pageSize,
                      icon: const Icon(Icons.expand_more, size: 18),
                      items: state.pageSizes
                          .map(
                            (value) => DropdownMenuItem<int>(
                              value: value,
                              child: Text('$value'),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          state.onPageSizeChanged(value);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              '${state.visibleCount} of ${state.totalCount}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppUiPalette.textSecondary,
              ),
            ),
            const SizedBox(width: 16),
            AdminIconButton(
              icon: Icons.first_page,
              tooltip: 'First page',
              onPressed: state.onFirstPage,
            ),
            AdminIconButton(
              icon: Icons.chevron_left,
              tooltip: 'Previous page',
              onPressed: state.onPreviousPage,
            ),
            const SizedBox(width: 6),
            Text(
              '${state.page} / $pages',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            AdminIconButton(
              icon: Icons.chevron_right,
              tooltip: 'Next page',
              onPressed: state.onNextPage,
            ),
            AdminIconButton(
              icon: Icons.last_page,
              tooltip: 'Last page',
              onPressed: state.onLastPage,
            ),
          ],
        ),
      ),
    );
  }
}

class AdminIconButton extends StatelessWidget {
  const AdminIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = destructive
        ? AppUiPalette.danger
        : enabled
        ? AppUiPalette.textPrimary
        : AppUiPalette.textDisabled;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class AdminStatusChip extends StatelessWidget {
  const AdminStatusChip({super.key, required this.label, this.kind});

  final String label;
  final AdminStatusKind? kind;

  @override
  Widget build(BuildContext context) {
    final resolvedKind = kind ?? AdminStatusKind.fromLabel(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: resolvedKind.background,
        borderRadius: BorderRadius.circular(adminCompactRadius),
        border: Border.all(color: resolvedKind.border),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: resolvedKind.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AdminStatusKind {
  const AdminStatusKind({
    required this.foreground,
    required this.background,
    required this.border,
  });

  final Color foreground;
  final Color background;
  final Color border;

  static final AdminStatusKind success = AdminStatusKind(
    foreground: AppUiPalette.success,
    background: AppUiPalette.success.withValues(alpha: 0.1),
    border: AppUiPalette.success.withValues(alpha: 0.3),
  );

  static final AdminStatusKind warning = AdminStatusKind(
    foreground: AppUiPalette.warning,
    background: AppUiPalette.warningSoft,
    border: AppUiPalette.warning.withValues(alpha: 0.3),
  );

  static final AdminStatusKind danger = AdminStatusKind(
    foreground: AppUiPalette.danger,
    background: AppUiPalette.dangerSoft,
    border: AppUiPalette.danger.withValues(alpha: 0.3),
  );

  static final AdminStatusKind neutral = AdminStatusKind(
    foreground: AppUiPalette.textSecondary,
    background: AppUiPalette.surfaceMuted,
    border: AppUiPalette.border,
  );

  static AdminStatusKind fromLabel(String label) {
    final normalized = label.trim().toLowerCase();
    if (normalized == 'success' ||
        normalized == 'active' ||
        normalized == 'enabled' ||
        normalized == 'sealed' ||
        normalized == 'valid' ||
        normalized == 'permitted') {
      return success;
    }
    if (normalized == 'failed' ||
        normalized == 'failure' ||
        normalized == 'disabled' ||
        normalized == 'denied' ||
        normalized == 'revoked' ||
        normalized == 'deprecated') {
      return danger;
    }
    if (normalized.contains('pending') ||
        normalized.contains('inactive') ||
        normalized.contains('suspend') ||
        normalized.contains('hold')) {
      return warning;
    }
    return neutral;
  }
}

class AdminDetailDrawer extends StatelessWidget {
  const AdminDetailDrawer({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdminSurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null && subtitle!.trim().isNotEmpty)
                        Text(
                          subtitle!,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppUiPalette.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                AdminIconButton(
                  icon: Icons.close,
                  tooltip: 'Close details',
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
