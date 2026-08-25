import { EditorView, basicSetup } from 'codemirror';
import { undo, redo } from '@codemirror/commands';
import { json } from '@codemirror/lang-json';
import { placeholder } from '@codemirror/view';
import { containEditorWheel } from './acp_json_editor_scroll.mjs';

const acpJsonEditorTheme = EditorView.theme({
  '&': {
    backgroundColor: '#ffffff',
    color: '#252427',
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
    overscrollBehavior: 'contain',
  },
  '.cm-content': {
    minHeight: '100%',
    padding: '10px 0',
  },
  '.cm-line': {
    padding: '0 10px',
  },
  '.cm-gutters': {
    backgroundColor: '#f0ece5',
    borderRight: '1px solid #d8d1c7',
    color: '#706b68',
  },
  '.cm-activeLine': {
    backgroundColor: '#f0ece5',
  },
  '.cm-activeLineGutter': {
    backgroundColor: '#e8edf2',
    color: '#40546a',
  },
  '.cm-placeholder': {
    color: '#918b85',
  },
  '.cm-cursor, .cm-dropCursor': {
    borderLeftColor: '#40546a',
  },
  '&.cm-focused > .cm-scroller > .cm-selectionLayer .cm-selectionBackground, .cm-selectionBackground': {
    backgroundColor: '#cfd8e1',
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
  const scroller = view.scrollDOM;
  const handleWheel = (event) => containEditorWheel(event, scroller);
  scroller.addEventListener('wheel', handleWheel, { passive: true });

  return {
    destroy() {
      scroller.removeEventListener('wheel', handleWheel);
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
