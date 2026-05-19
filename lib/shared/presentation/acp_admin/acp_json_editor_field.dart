// coverage:ignore-file

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_json_codec.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_json_editor_bridge_stub.dart'
    if (dart.library.html) 'package:mugen_ui/shared/presentation/acp_admin/acp_json_editor_bridge_web.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_json_editor_command_controller.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

class AcpJsonEditorField extends StatefulWidget {
  const AcpJsonEditorField({
    required this.controller,
    required this.labelText,
    super.key,
    this.editorKey,
    this.hintText,
    this.maxLines = 10,
    this.minLines = 6,
    this.validator,
  });

  final TextEditingController controller;
  final Key? editorKey;
  final String? hintText;
  final String labelText;
  final int maxLines;
  final int minLines;
  final FormFieldValidator<String>? validator;

  @override
  State<AcpJsonEditorField> createState() => _AcpJsonEditorFieldState();
}

class _AcpJsonEditorFieldState extends State<AcpJsonEditorField> {
  static const double _lineHeight = 20;
  static const double _verticalPadding = 24;

  final AcpJsonEditorCommandController _commandController =
      AcpJsonEditorCommandController();
  String? _actionErrorText;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant AcpJsonEditorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }

    oldWidget.controller.removeListener(_handleControllerChanged);
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _commandController.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: widget.controller.text,
      validator: (value) => widget.validator?.call(value ?? ''),
      builder: (fieldState) {
        final errorText = fieldState.errorText ?? _actionErrorText;
        final borderColor = errorText == null
            ? AppUiPalette.border
            : AppUiPalette.danger;
        final visibleLines = _visibleLines(widget.controller.text);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 6, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.labelText,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: AppUiPalette.textSecondary),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.undo),
                          onPressed: _commandController.undo,
                          tooltip: 'Undo JSON edit',
                        ),
                        IconButton(
                          icon: const Icon(Icons.redo),
                          onPressed: _commandController.redo,
                          tooltip: 'Redo JSON edit',
                        ),
                        IconButton(
                          icon: const Icon(Icons.format_align_left),
                          onPressed: () => _format(fieldState),
                          tooltip: 'Format JSON',
                        ),
                        IconButton(
                          icon: const Icon(Icons.compress),
                          onPressed: () => _compact(fieldState),
                          tooltip: 'Compact JSON',
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppUiPalette.border),
                  SizedBox(
                    height: _heightForLines(visibleLines),
                    child: AcpJsonCodeEditor(
                      key: widget.editorKey,
                      commandController: _commandController,
                      onChanged: (value) =>
                          _handleEditorChanged(fieldState, value),
                      placeholder: widget.hintText,
                      value: widget.controller.text,
                    ),
                  ),
                ],
              ),
            ),
            if (errorText != null)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 6),
                child: Text(
                  errorText,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppUiPalette.danger),
                ),
              ),
          ],
        );
      },
    );
  }

  void _compact(FormFieldState<String> fieldState) {
    _transformJson(fieldState, (value) => jsonEncode(value));
  }

  void _format(FormFieldState<String> fieldState) {
    _transformJson(fieldState, AcpJsonCodec.prettyPrint);
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleEditorChanged(FormFieldState<String> fieldState, String value) {
    if (_actionErrorText != null) {
      setState(() {
        _actionErrorText = null;
      });
    }
    _setControllerText(value);
    fieldState.didChange(value);
  }

  void _setControllerText(String value) {
    if (widget.controller.text == value) {
      return;
    }

    widget.controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _transformJson(
    FormFieldState<String> fieldState,
    String Function(Object? value) transform,
  ) {
    final raw = widget.controller.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _actionErrorText = null;
      });
      _setControllerText('');
      fieldState.didChange('');
      return;
    }

    final result = AcpJsonCodec.parse(raw);
    if (result.isFailure) {
      setState(() {
        _actionErrorText = result.failure!.message;
      });
      fieldState.validate();
      return;
    }

    final nextValue = transform(result.data);
    setState(() {
      _actionErrorText = null;
    });
    _setControllerText(nextValue);
    fieldState.didChange(nextValue);
    fieldState.validate();
  }

  double _heightForLines(int lines) {
    return lines * _lineHeight + _verticalPadding;
  }

  int _visibleLines(String value) {
    final lineCount = '\n'.allMatches(value).length + 1;
    return math.max(widget.minLines, math.min(widget.maxLines, lineCount));
  }
}
