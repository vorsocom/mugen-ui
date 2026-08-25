import test from 'node:test';
import assert from 'node:assert/strict';

import {
  containEditorWheel,
  shouldContainEditorWheel,
} from './acp_json_editor_scroll.mjs';

test('contains wheel events when editor content overflows', () => {
  let propagationStopped = false;
  const contained = containEditorWheel(
    { stopPropagation: () => { propagationStopped = true; } },
    { clientHeight: 200, scrollHeight: 420 },
  );

  assert.equal(contained, true);
  assert.equal(propagationStopped, true);
});

test('allows form scrolling when editor content fits', () => {
  let propagationStopped = false;
  const contained = containEditorWheel(
    { stopPropagation: () => { propagationStopped = true; } },
    { clientHeight: 200, scrollHeight: 200 },
  );

  assert.equal(contained, false);
  assert.equal(propagationStopped, false);
});

test('ignores subpixel overflow differences', () => {
  assert.equal(
    shouldContainEditorWheel({ clientHeight: 200, scrollHeight: 200.5 }),
    false,
  );
});
