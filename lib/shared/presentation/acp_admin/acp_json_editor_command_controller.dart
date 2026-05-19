// coverage:ignore-file

import 'package:flutter/foundation.dart';

class AcpJsonEditorCommandController {
  VoidCallback? _focus;
  VoidCallback? _redo;
  VoidCallback? _undo;

  void attach({
    required VoidCallback focus,
    required VoidCallback redo,
    required VoidCallback undo,
  }) {
    _focus = focus;
    _redo = redo;
    _undo = undo;
  }

  void detach() {
    _focus = null;
    _redo = null;
    _undo = null;
  }

  void focus() {
    _focus?.call();
  }

  void redo() {
    _redo?.call();
  }

  void undo() {
    _undo?.call();
  }
}
