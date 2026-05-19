// coverage:ignore-file

import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'package:mugen_ui/shared/presentation/acp_admin/acp_json_editor_command_controller.dart';

@JS('MugenAcpJsonEditor.create')
external _CodeMirrorJsonEditorHandle _createCodeMirrorJsonEditor(
  web.HTMLElement parent,
  _CodeMirrorJsonEditorOptions options,
);

extension type _CodeMirrorJsonEditorOptions._(JSObject _) implements JSObject {
  external factory _CodeMirrorJsonEditorOptions({
    JSFunction onChange,
    String placeholder,
    String value,
  });
}

extension type _CodeMirrorJsonEditorHandle._(JSObject _) implements JSObject {
  external void destroy();
  external void focus();
  external String getValue();
  external void redo();
  external void setValue(String value);
  external void undo();
}

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
  static int _nextViewId = 0;

  late final String _viewType;
  late final JSFunction _onChange;
  _CodeMirrorJsonEditorHandle? _editor;

  @override
  void initState() {
    super.initState();
    _viewType = 'mugen-acp-json-editor-${_nextViewId++}';
    _onChange = _handleEditorChanged.toJS;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final host = web.HTMLDivElement()
        ..className = 'mugen-acp-json-editor-host'
        ..style.width = '100%'
        ..style.height = '100%';
      _createEditor(host);
      return host;
    });
  }

  @override
  void didUpdateWidget(covariant AcpJsonCodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.commandController != widget.commandController) {
      oldWidget.commandController.detach();
      _attachCommands();
    }

    final editor = _editor;
    if (editor != null && widget.value != editor.getValue()) {
      editor.setValue(widget.value);
    }
  }

  @override
  void dispose() {
    widget.commandController.detach();
    _editor?.destroy();
    _editor = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }

  void _attachCommands() {
    final editor = _editor;
    if (editor == null) {
      return;
    }

    widget.commandController.attach(
      focus: () => editor.focus(),
      redo: () => editor.redo(),
      undo: () => editor.undo(),
    );
  }

  void _createEditor(web.HTMLElement host) {
    final editor = _createCodeMirrorJsonEditor(
      host,
      _CodeMirrorJsonEditorOptions(
        onChange: _onChange,
        placeholder: widget.placeholder ?? '',
        value: widget.value,
      ),
    );
    _editor = editor;
    _attachCommands();
  }

  void _handleEditorChanged(JSString value) {
    widget.onChanged(value.toDart);
  }
}
