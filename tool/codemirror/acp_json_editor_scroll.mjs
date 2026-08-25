export function shouldContainEditorWheel(scroller) {
  return scroller.scrollHeight - scroller.clientHeight > 1;
}

export function containEditorWheel(event, scroller) {
  if (!shouldContainEditorWheel(scroller)) {
    return false;
  }
  event.stopPropagation();
  return true;
}
