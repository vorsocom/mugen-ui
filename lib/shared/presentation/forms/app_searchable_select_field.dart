import 'package:flutter/material.dart';

import 'package:mugen_ui/shared/presentation/theme/app_form_style.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

class AppSearchableSelectField<T> extends StatefulWidget {
  const AppSearchableSelectField({
    required this.fieldKey,
    required this.optionKeyPrefix,
    required this.labelText,
    required this.options,
    required this.selectedOptionKey,
    required this.optionKey,
    required this.optionTitle,
    required this.optionSubtitle,
    required this.optionSearchText,
    required this.onSelected,
    required this.helpText,
    this.hintText,
    this.helpKey,
    this.suffixIcon = Icons.manage_search_outlined,
    this.emptyMessage = 'No matching options found.',
    this.enabled = true,
    super.key,
  }) : assert(helpText != '', 'helpText must not be blank.');

  final Key fieldKey;
  final String optionKeyPrefix;
  final String labelText;
  final String? hintText;
  final Key? helpKey;
  final String helpText;
  final IconData suffixIcon;
  final List<T> options;
  final String? selectedOptionKey;
  final String Function(T option) optionKey;
  final String Function(T option) optionTitle;
  final String Function(T option) optionSubtitle;
  final String Function(T option) optionSearchText;
  final ValueChanged<T> onSelected;
  final String emptyMessage;
  final bool enabled;

  @override
  State<AppSearchableSelectField<T>> createState() =>
      _AppSearchableSelectFieldState<T>();
}

class _AppSearchableSelectFieldState<T>
    extends State<AppSearchableSelectField<T>> {
  static const double _resultsMaxHeight = 264;
  static const double _resultTileHeight = 64;

  final TextEditingController _controller = TextEditingController();
  final MenuController _menuController = MenuController();
  String _committedText = '';
  bool _showAllResults = false;

  @override
  void initState() {
    super.initState();
    _syncControllerWithSelection();
  }

  @override
  void didUpdateWidget(covariant AppSearchableSelectField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedOptionKey != widget.selectedOptionKey ||
        oldWidget.options != widget.options) {
      _syncControllerWithSelection();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && widget.options.isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        return MenuAnchor(
          controller: _menuController,
          useRootOverlay: true,
          consumeOutsideTap: false,
          onClose: _restoreCommittedText,
          alignmentOffset: const Offset(0, 6),
          style: MenuStyle(
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            elevation: const WidgetStatePropertyAll(8),
            shadowColor: WidgetStatePropertyAll(
              AppUiPalette.drawer.withValues(alpha: 0.16),
            ),
          ),
          menuChildren: [
            SizedBox(
              key: Key('${widget.optionKeyPrefix}-results'),
              width: constraints.maxWidth,
              child: _buildResults(),
            ),
          ],
          builder: (context, menuController, child) {
            return TextFormField(
              key: widget.fieldKey,
              controller: _controller,
              enabled: enabled,
              decoration: appFormInputDecoration(
                labelText: widget.labelText,
                hintText: widget.hintText,
                helpKey: widget.helpKey,
                helpText: widget.helpText,
                suffixIcon: IconButton(
                  tooltip: 'Show ${widget.labelText} options',
                  onPressed: enabled ? _toggleMenu : null,
                  icon: Icon(widget.suffixIcon),
                ),
              ),
              onTap: enabled ? _showAllOptions : null,
              onChanged: enabled ? (_) => _filterOptions() : null,
            );
          },
        );
      },
    );
  }

  Widget _buildResults() {
    final results = _filteredOptions();
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(widget.emptyMessage),
      );
    }

    final resultsHeight = (results.length * _resultTileHeight).clamp(
      _resultTileHeight,
      _resultsMaxHeight,
    );
    return SizedBox(
      height: resultsHeight,
      child: ListView.separated(
        primary: false,
        padding: EdgeInsets.zero,
        itemCount: results.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final option = results[index];
          final optionKey = widget.optionKey(option);
          final optionTitle = widget.optionTitle(option);
          final optionSubtitle = widget.optionSubtitle(option);
          final isSelected = optionKey == widget.selectedOptionKey;
          return Tooltip(
            message: '$optionTitle\n$optionSubtitle',
            waitDuration: const Duration(milliseconds: 400),
            child: ListTile(
              key: Key('${widget.optionKeyPrefix}-$optionKey'),
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              horizontalTitleGap: 10,
              selected: isSelected,
              leading: Icon(
                isSelected
                    ? Icons.check_circle_outline
                    : Icons.manage_search_outlined,
              ),
              title: Text(
                optionTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                optionSubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _select(option),
            ),
          );
        },
      ),
    );
  }

  List<T> _filteredOptions() {
    if (_showAllResults) {
      return widget.options;
    }

    final tokens = _controller.text
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) {
      return widget.options;
    }

    return widget.options
        .where((option) {
          final searchText = widget.optionSearchText(option).toLowerCase();
          return tokens.every(searchText.contains);
        })
        .toList(growable: false);
  }

  void _select(T option) {
    _committedText = widget.optionTitle(option);
    _controller.text = _committedText;
    _showAllResults = false;
    _menuController.close();
    widget.onSelected(option);
  }

  void _showAllOptions() {
    setState(() {
      _showAllResults = true;
    });
    if (!_menuController.isOpen) {
      _menuController.open();
    }
  }

  void _filterOptions() {
    setState(() {
      _showAllResults = false;
    });
    if (!_menuController.isOpen) {
      _menuController.open();
    }
  }

  void _toggleMenu() {
    if (_menuController.isOpen) {
      _menuController.close();
      return;
    }
    _showAllOptions();
  }

  void _restoreCommittedText() {
    _showAllResults = false;
    _controller.text = _committedText;
  }

  void _syncControllerWithSelection() {
    final selectedKey = widget.selectedOptionKey;
    if (selectedKey == null || selectedKey.trim().isEmpty) {
      _committedText = '';
      _controller.clear();
      _showAllResults = false;
      return;
    }

    for (final option in widget.options) {
      if (widget.optionKey(option) == selectedKey) {
        _committedText = widget.optionTitle(option);
        _controller.text = _committedText;
        _showAllResults = false;
        return;
      }
    }
  }
}
