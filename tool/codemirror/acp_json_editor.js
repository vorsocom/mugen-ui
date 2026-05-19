import { EditorView, basicSetup } from 'codemirror';
import { undo, redo } from '@codemirror/commands';
import { json } from '@codemirror/lang-json';
import { placeholder } from '@codemirror/view';

const acpJsonEditorTheme = EditorView.theme({
  '&': {
    backgroundColor: '#ffffff',
    color: '#111827',
    fontSize: '13px',
    height: '100%',
  },
  '&.cm-focused': {
    outline: 'none',
  },
  '.cm-scroller': {
    fontFamily:
      'ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace',
    lineHeight: '1.5',
    overflow: 'auto',
  },
  '.cm-content': {
    minHeight: '100%',
    padding: '10px 0',
  },
  '.cm-line': {
    padding: '0 10px',
  },
  '.cm-gutters': {
    backgroundColor: '#f8fafc',
    borderRight: '1px solid #e2e8f0',
    color: '#64748b',
  },
  '.cm-activeLine': {
    backgroundColor: '#f8fafc',
  },
  '.cm-activeLineGutter': {
    backgroundColor: '#eef2ff',
    color: '#1f2937',
  },
  '.cm-placeholder': {
    color: '#94a3b8',
  },
});

function create(parent, options = {}) {
  let suppressChange = false;
  const notifyChange =
    typeof options.onChange === 'function' ? options.onChange : () => {};

  const view = new EditorView({
    doc: options.value || '',
    parent,
    extensions: [
      basicSetup,
      json(),
      placeholder(options.placeholder || ''),
      acpJsonEditorTheme,
      EditorView.updateListener.of((update) => {
        if (suppressChange || !update.docChanged) {
          return;
        }

        notifyChange(update.state.doc.toString());
      }),
    ],
  });

  return {
    destroy() {
      view.destroy();
    },
    focus() {
      view.focus();
    },
    getValue() {
      return view.state.doc.toString();
    },
    redo() {
      redo(view);
    },
    setValue(value) {
      const nextValue = value || '';
      const currentValue = view.state.doc.toString();
      if (nextValue === currentValue) {
        return;
      }

      suppressChange = true;
      view.dispatch({
        changes: {
          from: 0,
          to: currentValue.length,
          insert: nextValue,
        },
      });
      suppressChange = false;
    },
    undo() {
      undo(view);
    },
  };
}

window.MugenAcpJsonEditor = { create };
