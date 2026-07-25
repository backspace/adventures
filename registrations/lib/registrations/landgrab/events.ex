defmodule Registrations.Landgrab.Events do
  @moduledoc """
  Context for the Landgrab event row. There is one logical "current event" —
  this module exposes it without enforcing singleton constraints at the DB
  level. If multiple rows exist, the most-recently-inserted one wins.
  """
  import Ecto.Query

  alias Registrations.Landgrab.Event
  alias Registrations.Repo

  @doc """
  Returns the current event, inserting a placeholder if none exists yet so
  admin pages always have something to edit.
  """
  def current do
    case Repo.one(from(e in Event, order_by: [desc: e.inserted_at], limit: 1)) do
      nil ->
        {:ok, event} =
          %Event{}
          |> Event.changeset(%{name: "Landgrab"})
          |> Repo.insert()

        event

      event ->
        event
    end
  end

  def update(%Event{} = event, attrs) do
    event
    |> Event.changeset(attrs)
    |> Repo.update()
  end

  # The scheduled milestones a live "shift the schedule" control moves. Includes
  # start_time (so a push before the simulation begins slides the whole
  # timeline), but NOT the one-shot stamps (endgame announcement, final
  # messages) — those record things that already happened.
  @schedule_fields ~w(start_time endgame_starts_at endgame_ends_at
                      liberation_starts_at liberation_rollout_ends_at)a

  @doc """
  Shift the still-upcoming scheduled milestones by `seconds` (may be negative),
  preserving the intervals between them. Only fields in the FUTURE (after `now`)
  move — an already-passed milestone, or the event's start once it has begun,
  stays put, so a push can't rewrite history or un-start/un-end anything. Nil
  fields stay nil. Returns `{:ok, event}`.
  """
  def shift_schedule(%Event{} = event, seconds, now \\ DateTime.utc_now()) do
    changes =
      for field <- @schedule_fields,
          current = Map.fetch!(event, field),
          current != nil,
          DateTime.compare(current, now) == :gt,
          into: %{} do
        {field, current |> DateTime.add(seconds, :second) |> DateTime.truncate(:second)}
      end

    # Inline changeset rather than update/2 — `import Ecto.Query` shadows a bare
    # `update` call with the query macro.
    event |> Event.changeset(changes) |> Repo.update()
  end
end
