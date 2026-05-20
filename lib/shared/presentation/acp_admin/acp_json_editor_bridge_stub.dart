// coverage:ignore-file

import 'package:flutter/material.dart';

import 'package:mugen_ui/shared/presentation/acp_admin/acp_json_editor_command_controller.dart';

class AcpJsonCodeEditor extends StatefulWidget {
  const AcpJsonCodeEditor({
    required this.commandController,
    required this.onChanged,
    required this.value,
    super.key,
    this.placeholder,
  });

  final AcpJsonEditorCommandController commandController;
  final ValueChanged<String> onChanged;
  final String? placeholder;
  final String value;

  @override
  State<AcpJsonCodeEditor> createState() => _AcpJsonCodeEditorState();
}

class _AcpJsonCodeEditorState extends State<AcpJsonCodeEditor> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _syncingFromWidget = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _controller.addListener(_handleTextChanged);
    _attachCommands();
  }

  @override
  void didUpdateWidget(covariant AcpJsonCodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.commandController != widget.commandController) {
      oldWidget.commandController.detach();
      _attachCommands();
    }
    if (widget.value != _controller.text) {
      _syncingFromWidget = true;
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
      _syncingFromWidget = false;
    }
  }

  @override
  void dispose() {
    widget.commandController.detach();
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration.collapsed(hintText: widget.placeholder),
      expands: true,
      focusNode: _focusNode,
      keyboardType: TextInputType.multiline,
      maxLines: null,
      minLines: null,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        height: 1.5,
      ),
    );
  }

  void _attachCommands() {
    widget.commandController.attach(
      focus: _focusNode.requestFocus,
      redo: () {},
      undo: () {},
    );
  }

  void _handleTextChanged() {
    if (_syncingFromWidget) {
      return;
    }

    widget.onChanged(_controller.text);
  }
}
