defmodule Registrations.Landgrab.AccessibilityTag do
  @moduledoc """
  Authoritative list of accessibility tags that can be attached to poles
  and puzzlets. Stored as a `text[]` column; validated against this list at
  changeset time so unknown values can't sneak in from API clients.
  """

  @all ~w(
    stairs
    steep
    uneven_surface
    narrow_path
    dim_lighting
    crouch_required
    reach_required
    requires_hearing
    requires_vision
  )

  def all, do: @all

  def valid?(tag) when is_binary(tag), do: tag in @all
  def valid?(_), do: false

  def reject_unknown(tags) when is_list(tags) do
    Enum.filter(tags, &valid?/1)
  end

  def reject_unknown(_), do: []
end
