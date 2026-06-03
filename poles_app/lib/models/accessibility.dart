/// Authoritative list of accessibility tag values. Must match
/// `Registrations.Poles.AccessibilityTag.all/0` on the backend.
const List<String> kAccessibilityTags = [
  'stairs',
  'steep',
  'uneven_surface',
  'narrow_path',
  'dim_lighting',
  'crouch_required',
  'reach_required',
  'requires_hearing',
  'requires_vision',
];

/// Tags shown first in the chip selector for a pole (location-related).
/// Others appear after the user taps "Show all."
const Set<String> kPolePrimaryTags = {
  'steep',
  'uneven_surface',
  'narrow_path',
  'dim_lighting',
};

/// Tags shown first for a puzzlet (task-related, plus stairs since the
/// route to find a puzzlet often involves them).
const Set<String> kPuzzletPrimaryTags = {
  'stairs',
  'crouch_required',
  'reach_required',
  'requires_hearing',
  'requires_vision',
};

/// Tags shown first for a region. Regions are physical containers, so the
/// location-related tags lead.
const Set<String> kRegionPrimaryTags = {
  'stairs',
  'steep',
  'narrow_path',
  'dim_lighting',
};

/// Human-readable label for a tag value.
String accessibilityTagLabel(String tag) => switch (tag) {
      'stairs' => 'Stairs',
      'steep' => 'Steep incline',
      'uneven_surface' => 'Uneven surface',
      'narrow_path' => 'Narrow path',
      'dim_lighting' => 'Dim lighting',
      'crouch_required' => 'Crouch required',
      'reach_required' => 'Reach required',
      'requires_hearing' => 'Requires hearing',
      'requires_vision' => 'Requires vision',
      _ => tag,
    };

/// Longer explanation of what a tag means, shown when the author taps the
/// info icon next to a chip. Phrased in terms of what a player has to do —
/// applies whether the constraint is on the way to the spot or at the spot
/// itself.
String accessibilityTagExplanation(String tag) => switch (tag) {
      'stairs' =>
        'Players will need to use stairs at some point. A hard rule for wheelchair and mobility-aid users.',
      'steep' =>
        'Players will encounter a significant incline — a steep hill or steep ramp. Some people can manage stairs but not long inclines, and vice versa.',
      'uneven_surface' =>
        'The route crosses gravel, cobblestones, grass, dirt, or broken pavement. Generally unfriendly for wheelchairs, walkers, and strollers.',
      'narrow_path' =>
        'Players will pass through a path or doorway too narrow for wheelchairs or strollers.',
      'dim_lighting' =>
        'The location or path is poorly lit. Hard for low-vision users and anyone after dark.',
      'crouch_required' =>
        'Players will need to crouch or bend down — to inspect something, look under or behind an object, or read low text.',
      'reach_required' =>
        'Players will need to look up or reach for something elevated.',
      'requires_hearing' =>
        'There\'s an audio component — a sound clue or something the player must listen to.',
      'requires_vision' =>
        'Requires reading fine print, distinguishing colors, or other visual detail beyond what enlarging or contrast adjustment can help with.',
      _ => tag,
    };
