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
    this.hintText,
    this.helpText,
    this.suffixIcon = Icons.manage_search_outlined,
    this.emptyMessage = 'No matching options found.',
    this.enabled = true,
    super.key,
  });

  final Key fieldKey;
  final String optionKeyPrefix;
  final String labelText;
  final String? hintText;
  final String? helpText;
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
  final TextEditingController _controller = TextEditingController();
  bool _showResults = false;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: widget.fieldKey,
          controller: _controller,
          enabled: enabled,
          decoration: appFormInputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            helpText: widget.helpText,
            suffixIcon: Icon(widget.suffixIcon),
          ),
          onTap: enabled
              ? () {
                  setState(() {
                    _showResults = true;
                    _showAllResults = true;
                  });
                }
              : null,
          onChanged: enabled
              ? (_) {
                  setState(() {
                    _showResults = true;
                    _showAllResults = false;
                  });
                }
              : null,
        ),
        if (_showResults && enabled) ...[
          const SizedBox(height: 8),
          _buildResults(),
        ],
      ],
    );
  }

  Widget _buildResults() {
    final results = _filteredOptions();
    if (results.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppUiPalette.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(widget.emptyMessage),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppUiPalette.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: results.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final option = results[index];
            final optionKey = widget.optionKey(option);
            final isSelected = optionKey == widget.selectedOptionKey;
            return ListTile(
              key: Key('${widget.optionKeyPrefix}-$optionKey'),
              selected: isSelected,
              leading: Icon(
                isSelected
                    ? Icons.check_circle_outline
                    : Icons.manage_search_outlined,
              ),
              title: Text(widget.optionTitle(option)),
              subtitle: Text(widget.optionSubtitle(option)),
              onTap: () => _select(option),
            );
          },
        ),
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
    setState(() {
      _controller.text = widget.optionTitle(option);
      _showResults = false;
      _showAllResults = false;
    });
    widget.onSelected(option);
  }

  void _syncControllerWithSelection() {
    final selectedKey = widget.selectedOptionKey;
    if (selectedKey == null || selectedKey.trim().isEmpty) {
      _controller.clear();
      _showResults = false;
      _showAllResults = false;
      return;
    }

    for (final option in widget.options) {
      if (widget.optionKey(option) == selectedKey) {
        _controller.text = widget.optionTitle(option);
        _showResults = false;
        _showAllResults = false;
        return;
      }
    }
  }
}
