defmodule RegistrationsWeb.Landgrab.Render do
  @moduledoc """
  Shared JSON shapes for pole state and active puzzlets, used by both
  the scan (`PoleController`) and active-puzzlet endpoints so a
  resumed puzzlet renders identically to a freshly-scanned one.
  """

  alias Registrations.Landgrab.Regions

  def pole_state(%{pole: pole, current_owner_team_id: owner, locked?: locked} = state) do
    %{
      id: pole.id,
      # A human name — the author label, or a stable generated one. The
      # barcode is deliberately NOT sent to players: it's the scannable code,
      # and exposing it would let someone claim a stake without being there.
      name: Registrations.Landgrab.pole_name(pole),
      latitude: pole.latitude,
      longitude: pole.longitude,
      current_owner_team_id: owner,
      # Present on the map's pole list (list_poles_with_state); absent on
      # some single-pole state maps, hence Map.get rather than a match.
      current_owner_team_name: Map.get(state, :current_owner_team_name),
      current_owner_color_index: Map.get(state, :current_owner_color_index),
      locked: locked,
      # True when every remaining puzzlet here conflicts with the viewing team's
      # accessibility needs — the map flags it. Only set on the pole-list path
      # (per-viewer); absent elsewhere, hence the default.
      prohibitive: Map.get(state, :prohibitive, false)
    }
  end

  def puzzlet(nil, _attempts_remaining, _previous_wrong_answers), do: nil

  def puzzlet(puzzlet, attempts_remaining, previous_wrong_answers) do
    %{
      id: puzzlet.id,
      instructions: puzzlet.instructions,
      difficulty: puzzlet.difficulty,
      answer_type: puzzlet.answer_type,
      warning: puzzlet.warning,
      attempts_remaining: attempts_remaining,
      previous_wrong_answers: previous_wrong_answers,
      # Region the puzzlet sits in (if any), plus every ancestor's
      # description/accessibility notes up the hierarchy, so the player
      # sees how to reach the spot and what to expect. `stanzas` is
      # ordered root → self with empty rows already dropped.
      region: region(puzzlet)
    }
  end

  @doc """
  A puzzlet's region context: its name, full breadcrumb, and the inherited
  stanzas (root → self, empty rows dropped). `nil` when the puzzlet has no
  region. Shared by the scan payload and the validator-only map layer.
  """
  def region(puzzlet) do
    case Regions.puzzlet_inheritance_payload(puzzlet) do
      %{region: nil} ->
        nil

      %{region: summary, inherited_stanzas: stanzas} ->
        %{name: summary.name, breadcrumb: summary.breadcrumb, stanzas: stanzas}
    end
  end

  @doc "Full scan/active-puzzlet payload from a `Landgrab` state map."
  def scan_payload(state) do
    %{
      pole: pole_state(state),
      active_puzzlet:
        puzzlet(
          state.active_puzzlet,
          state.attempts_remaining,
          state.previous_wrong_answers
        ),
      # How many *other* teams currently hold an active puzzlet on
      # this pole — lets the app tell the player it's contested.
      contending_teams: Map.get(state, :contending_teams, 0)
    }
  end
end
