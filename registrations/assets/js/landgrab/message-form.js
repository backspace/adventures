// Message-form preset sender picker. When a landgrab author edits a
// message, they see a dropdown of pre-configured identities (Sabuk,
// Subordinate) plus an "Other…" option that reveals the freeform
// from_name / from_address inputs. Server-side stays the same —
// the freeform inputs are what actually submit; this JS only
// synchronises them from the dropdown for the preset cases.
//
// Progressive enhancement: the preset container is hidden by
// default (via the `hidden` attribute in the template), so if this
// module never runs the author just sees the classic freeform UI.
(function () {
  const container = document.querySelector('[data-sender-preset]');
  if (!container) return;
  const select = container.querySelector('[data-sender-preset-select]');
  const freeform = document.querySelector('[data-sender-freeform]');
  if (!select || !freeform) return;
  const nameInput = freeform.querySelector('input[name="message[from_name]"]');
  const addressInput = freeform.querySelector('input[name="message[from_address]"]');
  if (!nameInput || !addressInput) return;

  // Preset options are identified by having a `data-address`
  // attribute (the default and "other" options don't).
  function isPresetOption(opt) {
    return opt && Object.prototype.hasOwnProperty.call(opt.dataset, 'address');
  }

  // Match currently-populated name+address against preset options
  // so re-opening an existing message auto-selects the right
  // dropdown entry. Falls back to "other" if the values don't
  // match a known preset, or "" (default) if both are blank.
  function matchExistingPreset() {
    const n = nameInput.value.trim();
    const a = addressInput.value.trim();
    if (!n && !a) return '';
    for (const opt of select.options) {
      if (isPresetOption(opt) && opt.value === n && opt.dataset.address === a) {
        return opt.value;
      }
    }
    return 'other';
  }

  function apply() {
    const opt = select.options[select.selectedIndex];
    if (select.value === 'other') {
      freeform.hidden = false;
    } else if (isPresetOption(opt)) {
      // Sync from the preset and hide the freeform inputs.
      nameInput.value = opt.value;
      addressInput.value = opt.dataset.address;
      freeform.hidden = true;
    } else {
      // Default sender — no identity override; clear and hide.
      nameInput.value = '';
      addressInput.value = '';
      freeform.hidden = true;
    }
  }

  select.value = matchExistingPreset();
  container.hidden = false;
  apply();
  select.addEventListener('change', apply);
})();
