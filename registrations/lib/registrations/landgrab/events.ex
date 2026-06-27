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
end
