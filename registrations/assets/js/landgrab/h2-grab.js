// Every h2 on the landgrab page gets its letters split into
// grabbable slots. Pointer-down on a letter starts a drag; the
// inner span translates in real time to follow the pointer. Release
// (pointerup / pointercancel) clears the inline transform, and a
// CSS transition eases the letter back to its slot on a slight
// overshoot curve.
//
// Deliberately looser than the wordmark's letter-drop, which is a
// grand one-shot moment: this is meant to feel fidgety and small,
// something you notice on a second visit rather than the first.
(function () {
  const h2s = document.querySelectorAll('h2');
  if (h2s.length === 0) return;

  for (const h2 of h2s) {
    // If the h2 already contains element children (e.g. a link, an
    // <em>), leave it alone — splitting would lose that markup.
    if (h2.children.length > 0) continue;
    splitH2(h2);
  }

  function splitH2(h2) {
    const text = h2.textContent;
    // Preserve the accessible name — the letter slots become
    // aria-hidden decorative wrappers, so without this the h2's
    // announced text would be empty.
    h2.setAttribute('aria-label', text);
    h2.textContent = '';
    for (const ch of text) {
      if (ch === ' ') {
        // Whitespace between inline-block slots renders as a real
        // gap; keep it as a plain text node between siblings.
        h2.appendChild(document.createTextNode(' '));
        continue;
      }
      const slot = document.createElement('span');
      slot.className = 'landgrab-h2-letter-slot';
      slot.setAttribute('aria-hidden', 'true');
      const letter = document.createElement('span');
      letter.className = 'landgrab-h2-letter';
      letter.textContent = ch;
      slot.appendChild(letter);
      h2.appendChild(slot);
    }
  }

  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (reduced) return;

  // Single-active-letter model. If a second pointer touches another
  // letter mid-drag, it's ignored — the first drag keeps priority.
  // Simpler than multi-drag tracking and, for a subtle easter egg,
  // more than enough.
  let activeLetter = null;
  let activeSlot = null;
  let startX = 0, startY = 0;
  let pointerId = null;

  document.addEventListener('pointerdown', function (e) {
    if (activeLetter) return;
    const slot = e.target.closest('.landgrab-h2-letter-slot');
    if (!slot) return;
    const letter = slot.querySelector('.landgrab-h2-letter');
    if (!letter) return;
    activeSlot = slot;
    activeLetter = letter;
    startX = e.clientX;
    startY = e.clientY;
    pointerId = e.pointerId;
    // Kill the snap-back transition for the duration of the drag so
    // movement tracks the pointer exactly.
    letter.style.transition = 'none';
    // Route further pointer events to the slot so a fast drag off
    // the slot's bounds keeps flowing to us.
    slot.setPointerCapture(e.pointerId);
  });

  document.addEventListener('pointermove', function (e) {
    if (!activeLetter || e.pointerId !== pointerId) return;
    const dx = e.clientX - startX;
    const dy = e.clientY - startY;
    activeLetter.style.transform = 'translate(' + dx + 'px, ' + dy + 'px)';
  });

  function release(e) {
    if (!activeLetter || e.pointerId !== pointerId) return;
    // Clear the inline transition override so the CSS `transition`
    // rule takes over the return trip, and drop the transform so
    // the letter animates back to (0, 0).
    activeLetter.style.transition = '';
    activeLetter.style.transform = '';
    if (activeSlot && activeSlot.hasPointerCapture(pointerId)) {
      activeSlot.releasePointerCapture(pointerId);
    }
    activeLetter = null;
    activeSlot = null;
    pointerId = null;
  }
  document.addEventListener('pointerup', release);
  document.addEventListener('pointercancel', release);
})();
