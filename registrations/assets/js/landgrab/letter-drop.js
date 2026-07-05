// Per-letter drop driven by Pointer Events — unified across mouse,
// touch, and stylus. Each slot the pointer crosses gets `.is-active`
// and that class sticks for the rest of the gesture, so sweeping
// across the wordmark leaves letters mid-fall on their own staggered
// timers (each transition starts the moment the pointer first
// reached its slot). Release rules differ by input modality: a
// mouse releases on pointerleave (exiting the wordmark), touch and
// pen release on pointerup/pointercancel.
(function () {
  const wordmark = document.querySelector('.landgrab-wordmark-text');
  if (!wordmark) return;
  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (reduced) return;

  const activeSlots = new Set();

  function activate(slot) {
    if (!slot || activeSlots.has(slot)) return;
    slot.classList.add('is-active');
    activeSlots.add(slot);
  }

  function deactivateAll() {
    for (const s of activeSlots) s.classList.remove('is-active');
    activeSlots.clear();
  }

  function slotAt(x, y) {
    const el = document.elementFromPoint(x, y);
    return el ? el.closest('.landgrab-letter-slot') : null;
  }

  wordmark.addEventListener('pointerdown', function (e) {
    // Mouse doesn't need to click first — pointermove handles it.
    // For touch/pen we capture so moves keep flowing past the
    // wordmark's bounding box.
    if (e.pointerType !== 'mouse') {
      wordmark.setPointerCapture(e.pointerId);
    }
    activate(slotAt(e.clientX, e.clientY));
  });

  wordmark.addEventListener('pointermove', function (e) {
    // Touch/pen: only track while the gesture is in flight (finger
    // down). Mouse: track unconditionally while over the wordmark.
    if (e.pointerType !== 'mouse' && !wordmark.hasPointerCapture(e.pointerId)) return;
    activate(slotAt(e.clientX, e.clientY));
  });

  // Mouse leaves the wordmark = end of the gesture; spring all
  // active letters back. Touch/pen ignore this — they release on
  // pointerup/pointercancel instead, so users can drag a finger
  // outside the wordmark and back without resetting.
  wordmark.addEventListener('pointerleave', function (e) {
    if (e.pointerType === 'mouse') deactivateAll();
  });

  function release(e) {
    if (e.pointerType === 'mouse') return;
    deactivateAll();
  }
  wordmark.addEventListener('pointerup', release);
  wordmark.addEventListener('pointercancel', release);
})();
