defmodule Registrations.Landgrab.AccessibilityTag do
  @moduledoc """
  Authoritative list of accessibility tags that can be attached to
  poles, puzzlets, regions, and (as of the self-identification
  feature) users. Stored as a `text[]` column; validated against this
  list at changeset time so unknown values can't sneak in from API
  clients.

  ## Two runtimes, two voices

  The mobile app has an independent copy of the tag identifiers in
  `landgrab_app/lib/models/accessibility.dart`, and a parity test
  (`test/registrations/landgrab/accessibility_tag_parity_test.exs`)
  fails if the two lists drift.

  Labels and explanations, however, are **deliberately not shared**:

  * On the site, participants read them **in-storyline**, so labels
    live in `priv/gettext/en/LC_MESSAGES/landgrab.po` under
    `accessibility_tag.<tag>.label` / `.help` — same file as the
    other participant-facing strings. Access them via `phrase/1` in
    templates and views.
  * In the mobile app, authors read them **out of storyline** while
    managing content. Those labels stay hardcoded in Dart.

  Different audience, different voice; the parity test on the tag
  list is enough to keep the schema in agreement.
  """

  @all ~w(
    stairs
    strenuous
    steep
    heights
    uneven_surface
    narrow_path
    dim_lighting
    crouch_required
    reach_required
    requires_hearing
    requires_vision
    requires_nfc
  )

  def all, do: @all

  def valid?(tag) when is_binary(tag), do: tag in @all
  def valid?(_), do: false

  def reject_unknown(tags) when is_list(tags) do
    Enum.filter(tags, &valid?/1)
  end

  def reject_unknown(_), do: []
end
