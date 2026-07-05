// Rivers are real OSM data baked into the SVG by the template. Poles
// are scattered at random non-water positions each page load, then
// fade in grey before being "claimed" by successive team colours in
// a rolling flip animation.
(function () {
  const svg = document.querySelector('.landgrab-map');
  if (!svg) return;

  // ViewBox width/height come from the SVG itself — the browser
  // parses the `viewBox` attribute into an SVGRect for us, so no
  // server → JS interpolation is needed.
  const VBW = svg.viewBox.baseVal.width;
  const VBH = svg.viewBox.baseVal.height;
  const rivers = Array.from(svg.querySelectorAll('.landgrab-rivers path'));
  const polesLayer = svg.querySelector('.landgrab-poles');
  const SVG_NS = 'http://www.w3.org/2000/svg';

  const probe = svg.createSVGPoint();
  function inWater(x, y) {
    probe.x = x; probe.y = y;
    return rivers.some(r => r.isPointInStroke(probe));
  }

  // A pole "clears" water only if the whole disc — center + edge —
  // is on land. Otherwise a pole near a riverbank can still bleed
  // into the water because `isPointInStroke` only tests the centre.
  const POLE_RADIUS = 6;
  function poleClearsWater(x, y) {
    if (inWater(x, y)) return false;
    const samples = 12;
    for (let i = 0; i < samples; i++) {
      const theta = (i / samples) * Math.PI * 2;
      const ex = x + POLE_RADIUS * Math.cos(theta);
      const ey = y + POLE_RADIUS * Math.sin(theta);
      if (inWater(ex, ey)) return false;
    }
    return true;
  }

  // Restrict pole placement to the geographic "downtown" side of the
  // two rivers: west of the Red, north of the Assiniboine. We sample
  // each river path once into an array of viewBox-space points; for a
  // candidate we find the sample with the nearest Y (Red — river runs
  // mostly N–S) or nearest X (Assiniboine — runs E–W) and compare.
  function sampleRivers(nameFragment) {
    const paths = svg.querySelectorAll(
      '.landgrab-rivers path[data-river-name*="' + nameFragment + '"]'
    );
    const points = [];
    for (const path of paths) {
      const len = path.getTotalLength();
      for (let s = 0; s <= len; s += 3) {
        points.push(path.getPointAtLength(s));
      }
    }
    return points;
  }
  const redSamples = sampleRivers('Red River');
  const assiniboineSamples = sampleRivers('Assiniboine');
  // Buffer = half stroke width (Elixir-side: Red 46/2=23, Assini 36/2=18)
  // + pole radius + a few units of breathing room so poles don't crowd
  // the bank.
  const RED_BUFFER = 23 + POLE_RADIUS + 4;
  const ASSINIBOINE_BUFFER = 18 + POLE_RADIUS + 4;
  // If the closest sample is further than this in the orthogonal axis,
  // the river doesn't really pass near this row/column — no constraint
  // from that river applies.
  const RIVER_REACH = 30;

  function westOfRed(x, y) {
    if (redSamples.length === 0) return true;
    let nearest = null;
    let bestDy = Infinity;
    for (const p of redSamples) {
      const dy = Math.abs(p.y - y);
      if (dy < bestDy) { bestDy = dy; nearest = p; }
    }
    if (bestDy > RIVER_REACH) return true;
    return x < nearest.x - RED_BUFFER;
  }

  function northOfAssiniboine(x, y) {
    if (assiniboineSamples.length === 0) return true;
    let nearest = null;
    let bestDx = Infinity;
    for (const p of assiniboineSamples) {
      const dx = Math.abs(p.x - x);
      if (dx < bestDx) { bestDx = dx; nearest = p; }
    }
    if (bestDx > RIVER_REACH) return true;
    return y < nearest.y - ASSINIBOINE_BUFFER;
  }

  function inAllowedRegion(x, y) {
    return westOfRed(x, y) && northOfAssiniboine(x, y);
  }

  // Target pole count at full-viewBox visible (i.e. when the screen
  // aspect matches 8:5). Narrower visible regions get fewer poles via
  // sqrt scaling so the *spacing between* poles stays roughly steady
  // across aspect ratios, rather than the *count*.
  const POLE_COUNT_BASE = 18;
  const POLE_COUNT_MIN = 8;
  // Intersex-Inclusive Progress Pride flag — the six rainbow stripes
  // (top→bottom) followed by the chevron colours (outer→inner: black,
  // brown for BIPOC; light blue, pink, white for trans).
  const TEAMS = [
    '#e40303', // red
    '#ff8c00', // orange
    '#ffed00', // yellow
    '#008026', // green
    '#004dff', // blue
    '#750787', // purple
    '#000000', // black
    '#613915', // brown
    '#73d7ee', // light blue (trans)
    '#ffafc7', // pink (trans)
    '#ffffff'  // white (trans)
  ];
  // Player claims a fixed colour for the session (rerolled on
  // refresh). AI captures never use this colour, so a player-coloured
  // pole unambiguously means "I did that" — the player can read
  // territory at a glance.
  const PLAYER_COLOR = TEAMS[Math.floor(Math.random() * TEAMS.length)];
  const AI_TEAMS = TEAMS.filter(function (c) { return c !== PLAYER_COLOR; });
  // Initial-wave timing: each pole gets claimed between these bounds,
  // spread uniformly. Longer than a fast attract-loop so the page
  // feels like a deliberate territory game, not a hurried sales demo.
  const INITIAL_MIN_MS = 1500;
  const INITIAL_MAX_MS = 12000;
  // Periodic flip timing: after a pole's first capture, it gets
  // re-captured by a different team within this window, and again,
  // and again — so the map keeps shifting while the page is open.
  const FLIP_MIN_MS = 12000;
  const FLIP_MAX_MS = 40000;
  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // With `preserveAspectRatio="xMaxYMax slice"`, the SVG anchors the
  // bottom-right corner to the screen and crops top/left when the
  // viewport's aspect is taller than the viewBox's 8:5. Figure out
  // which viewBox region is actually on-screen so we only scatter
  // poles where the user can see them.
  function visibleViewBox() {
    const r = svg.getBoundingClientRect();
    const scale = Math.max(r.width / VBW, r.height / VBH);
    const visW = Math.min(VBW, r.width / scale);
    const visH = Math.min(VBH, r.height / scale);
    return { x: VBW - visW, y: VBH - visH, w: visW, h: visH };
  }

  const visible = visibleViewBox();
  // Scale count by sqrt(area) so pole-to-pole spacing stays steady as
  // the visible region shrinks (portrait), rather than the raw count.
  const poleCount = Math.max(
    POLE_COUNT_MIN,
    Math.round(POLE_COUNT_BASE * Math.sqrt((visible.w * visible.h) / (VBW * VBH)))
  );
  // Keep poles a small margin inside the visible rect so they don't
  // hug the edges of the cropped viewport.
  const PLACE_MARGIN = 30;
  const minX = visible.x + PLACE_MARGIN;
  const maxX = visible.x + visible.w - PLACE_MARGIN;
  const minY = visible.y + PLACE_MARGIN;
  const maxY = visible.y + visible.h - PLACE_MARGIN;

  const poles = [];
  for (let i = 0; i < poleCount; i++) {
    let x, y, ok = false;
    for (let t = 0; t < 80; t++) {
      x = minX + Math.random() * (maxX - minX);
      y = minY + Math.random() * (maxY - minY);
      if (poleClearsWater(x, y) && inAllowedRegion(x, y)) { ok = true; break; }
    }
    if (!ok) continue;
    const circle = document.createElementNS(SVG_NS, 'circle');
    circle.setAttribute('cx', x);
    circle.setAttribute('cy', y);
    circle.setAttribute('r', POLE_RADIUS);
    circle.classList.add('landgrab-pole');
    polesLayer.appendChild(circle);
    poles.push({ circle, x, y, color: null });
  }

  function spawnPing(x, y, color) {
    if (reduced) return;
    // A static-transform wrapper sets the ping's position so the CSS
    // keyframe animation on the inner circle is free to drive
    // `transform: scale(...)` without us having to recompute the
    // translate — the inner circle scales from its own (0,0) origin,
    // which is the pole's centre after the wrapper's translate.
    const g = document.createElementNS(SVG_NS, 'g');
    g.setAttribute('transform', 'translate(' + x + ' ' + y + ')');
    const ping = document.createElementNS(SVG_NS, 'circle');
    ping.setAttribute('cx', '0');
    ping.setAttribute('cy', '0');
    ping.setAttribute('r', POLE_RADIUS);
    // Ping stroke is derived from `--pole-color` in CSS via the same
    // `color-mix` used for the pole's own border, so dark colours
    // (black especially) still show a visible ring against the dark
    // page background instead of vanishing into it.
    ping.style.setProperty('--pole-color', color);
    ping.classList.add('landgrab-ping');
    g.appendChild(ping);
    polesLayer.appendChild(g);
    ping.addEventListener('animationend', function () { g.remove(); }, { once: true });
  }

  function pickNextColor(current) {
    // Any AI team other than the current one. Excluding `current`
    // keeps a flip visible — re-picking the same colour would no-op.
    // AI_TEAMS already excludes the player's colour, so the AI can
    // never hand a pole to the player.
    const choices = AI_TEAMS.filter(function (c) { return c !== current; });
    return choices[Math.floor(Math.random() * choices.length)];
  }

  // Fraction of poles currently owned by the player. Used to modulate
  // how aggressively the AI recaptures player-held poles.
  function playerDominance() {
    if (poles.length === 0) return 0;
    let owned = 0;
    for (const p of poles) if (p.color === PLAYER_COLOR) owned++;
    return owned / poles.length;
  }

  // Delay multiplier applied to player-owned poles' scheduled flips.
  // At low dominance the player is left alone (multiplier = 1); as
  // dominance climbs past `CATCHUP_THRESHOLD`, the delay collapses on
  // a cubic curve so a mild lead barely stings but a runaway lead
  // gets aggressively contested.
  const CATCHUP_THRESHOLD = 0.4;
  const CATCHUP_FLOOR = 0.15;
  function catchupMultiplier() {
    const d = playerDominance();
    if (d < CATCHUP_THRESHOLD) return 1;
    const t = (d - CATCHUP_THRESHOLD) / (1 - CATCHUP_THRESHOLD);
    const eased = t * t * t;
    return 1 - eased * (1 - CATCHUP_FLOOR);
  }

  // Per-pole timer registry so we can pause/resume cleanly when the
  // tab is backgrounded. Without this, browsers throttle setTimeout
  // on hidden tabs and then flush a flurry of late captures when the
  // user returns — every queued flip firing inside a second.
  const timers = new Map();

  function scheduleCapture(pole) {
    const isInitial = pole.color === null;
    const color = isInitial
      ? AI_TEAMS[Math.floor(Math.random() * AI_TEAMS.length)]
      : pickNextColor(pole.color);
    let delay = isInitial
      ? INITIAL_MIN_MS + Math.random() * (INITIAL_MAX_MS - INITIAL_MIN_MS)
      : FLIP_MIN_MS + Math.random() * (FLIP_MAX_MS - FLIP_MIN_MS);
    // Only player-held poles feel the catch-up pressure. AI-vs-AI
    // churn stays at its baseline cadence, so the "world fighting
    // back" reads as targeted at the player rather than a global
    // speed-up.
    if (pole.color === PLAYER_COLOR) {
      delay *= catchupMultiplier();
    }
    const id = setTimeout(function () {
      timers.delete(pole);
      capture(pole, color);
    }, delay);
    timers.set(pole, id);
  }

  function capture(pole, color) {
    pole.color = color;
    // Use inline style rather than the `fill` attribute: the
    // .landgrab-pole CSS rule sets `fill: grey` for the initial paint,
    // and a stylesheet `fill` beats an SVG presentation attribute on
    // the same element. Inline style outranks both, and the
    // `transition: fill` rule still applies, smoothing the change.
    pole.circle.style.fill = color;
    // The stroke is `color-mix(--pole-color, white)` in CSS — update
    // the custom property so the outline tracks the pole's colour.
    pole.circle.style.setProperty('--pole-color', color);
    spawnPing(pole.x, pole.y, color);
    scheduleCapture(pole);
    checkDomination();
  }

  // Whether we've already celebrated the current 100%-player state.
  // Reset the moment an AI flip drops us below 100%, so achieving
  // full dominance again on the next attempt fires a fresh flash.
  let dominatedFired = false;

  function checkDomination() {
    const total = poles.length;
    if (total === 0) return;
    let owned = 0;
    for (const p of poles) if (p.color === PLAYER_COLOR) owned++;
    if (owned === total && !dominatedFired) {
      dominatedFired = true;
      celebrate();
    } else if (owned < total) {
      dominatedFired = false;
    }
  }

  function celebrate() {
    if (reduced) return;
    // Full-viewport flash tinted by the player's mixed border colour
    // (via `--pole-color` + the same `color-mix` used on pole
    // outlines) so even black or white player colours read as a
    // brightness pulse rather than a null flash.
    const flash = document.createElement('div');
    flash.className = 'landgrab-domination-flash';
    flash.style.setProperty('--pole-color', PLAYER_COLOR);
    document.body.appendChild(flash);
    flash.addEventListener('animationend', function () { flash.remove(); }, { once: true });

    // Every pole pings at once — the "you did it" beat before the
    // world starts flipping them back.
    for (const pole of poles) {
      spawnPing(pole.x, pole.y, PLAYER_COLOR);
    }
  }

  function startOrResume() {
    for (const pole of poles) {
      if (!timers.has(pole)) scheduleCapture(pole);
    }
  }

  function pause() {
    for (const id of timers.values()) clearTimeout(id);
    timers.clear();
  }

  // Pause while the tab is hidden (no work, no throttled-queue
  // buildup); on return, give each pole a fresh staggered delay so
  // the resumption looks like a natural continuation rather than a
  // synchronised burst.
  document.addEventListener('visibilitychange', function () {
    if (document.hidden) {
      pause();
    } else {
      startOrResume();
    }
  });

  // Click / tap on a pole → capture it for the player. Delegated on
  // the poles layer so newly-added poles pick up the handler for
  // free. `capture()` calls `scheduleCapture()` at its tail, which
  // now applies the catch-up multiplier if the pole is player-held,
  // so a player-triggered capture immediately queues the AI's
  // counter-attack at the appropriate speed.
  polesLayer.addEventListener('pointerdown', function (e) {
    const target = e.target.closest('.landgrab-pole');
    if (!target) return;
    const pole = poles.find(function (p) { return p.circle === target; });
    if (!pole) return;
    // Player takes priority over any pending AI flip on this pole.
    const pending = timers.get(pole);
    if (pending !== undefined) {
      clearTimeout(pending);
      timers.delete(pole);
    }
    capture(pole, PLAYER_COLOR);
  });

  // Also honour the case of being opened in a background tab: skip
  // the initial wave until the user actually focuses the page.
  if (!document.hidden) startOrResume();
})();
