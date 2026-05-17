defmodule Registrations.Poles.Event do
  @moduledoc """
  Represents the Poles event. One row per logical event; the current event is
  the most recently inserted one. `start_time` is the moment gameplay begins —
  before that, the app shows pre-event authoring/validation UI; after that, the
  app shows gameplay.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @schema_prefix "poles"
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "events" do
    field :name, :string
    field :start_time, :utc_datetime

    timestamps()
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:name, :start_time])
    |> validate_required([:name])
  end

  def started?(%__MODULE__{start_time: nil}, _now), do: false
  def started?(%__MODULE__{start_time: start_time}, now) do
    DateTime.compare(now, start_time) != :lt
  end
end
