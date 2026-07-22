// Textareas marked `data-autogrow` grow to fit their content as you type,
// so a short message stays compact and a long one doesn't need scrolling.
// The element's initial height (from its `rows`) is kept as a floor, so it
// never shrinks below that even when emptied.
function fit(el, minHeight) {
  el.style.height = "auto";
  el.style.height = `${Math.max(minHeight, el.scrollHeight)}px`;
}

function setup(el) {
  // Rendered height before we touch it reflects the `rows` attribute — use
  // it as the minimum. `box-sizing` may vary, so read it live.
  const minHeight = el.clientHeight;
  // No scrollbar flicker while we drive the height ourselves.
  el.style.overflowY = "hidden";
  el.style.resize = "vertical";
  const resize = () => fit(el, minHeight);
  el.addEventListener("input", resize);
  resize(); // fit whatever's already there (e.g. editing an existing message)
}

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("textarea[data-autogrow]").forEach(setup);
});
