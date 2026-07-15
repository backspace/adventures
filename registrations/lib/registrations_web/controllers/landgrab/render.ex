defmodule RegistrationsWeb.Landgrab.Render do
  @moduledoc """
  Shared JSON shapes for pole state and active puzzlets, used by both
  the scan (`PoleController`) and active-puzzlet endpoints so a
  resumed puzzlet renders identically to a freshly-scanned one.
  """

  def pole_state(%{pole: pole, current_owner_team_id: owner, locked?: locked}) do
    %{
      id: pole.id,
      barcode: pole.barcode,
      label: pole.label,
      latitude: pole.latitude,
      longitude: pole.longitude,
      current_owner_team_id: owner,
      locked: locked
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
      previous_wrong_answers: previous_wrong_answers
    }
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
