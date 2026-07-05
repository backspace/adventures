// Defer revealing the LANDGRAB wordmark until Anton has actually
// loaded — otherwise the Helvetica fallback flashes for a frame
// before the swap. CSS hides `.landgrab-wordmark-text` until
// `<html>` gets `.font-anton-loaded`. The 3s timeout matches what
// `font-display: block` would do on its own: show *something*
// eventually even if the font request stalls.
(function () {
  const root = document.documentElement;
  const reveal = function () { root.classList.add('font-anton-loaded'); };
  if (document.fonts && document.fonts.load) {
    document.fonts.load('1em "Anton"').then(reveal, reveal);
    setTimeout(reveal, 3000);
  } else {
    reveal();
  }
})();
