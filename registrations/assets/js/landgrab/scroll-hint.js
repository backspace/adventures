// Scroll-fade the "more below" chevron. Cheap to update directly on
// scroll — browsers already throttle scroll events to ~60Hz and a
// single style write is well within that budget, so no rAF needed.
(function () {
  const hint = document.querySelector('.landgrab-scroll-hint');
  if (!hint) return;
  // Fade is complete by ~quarter-viewport of scrolling — quick enough
  // that the cue gets out of the way as soon as the user engages,
  // slow enough that a single mouse-wheel tick doesn't snap it off.
  function fadeDistance() { return Math.max(120, window.innerHeight * 0.25); }
  function update() {
    const o = Math.max(0, 1 - window.scrollY / fadeDistance());
    hint.style.opacity = String(o);
  }
  window.addEventListener('scroll', update, { passive: true });
  window.addEventListener('resize', update);
  update();
})();
