defmodule Registrations.Landgrab.Event do
  @moduledoc """
  Represents the Landgrab event. One row per logical event; the current event is
  the most recently inserted one. `start_time` is the moment gameplay begins —
  before that, the app shows pre-event authoring/validation UI; after that, the
  app shows gameplay.

  The endgame fields describe a capture boundary that shrinks toward
  the wrap-party location: from `endgame_initial_radius_m` at
  `endgame_starts_at` down (linearly) to `endgame_final_radius_m` at
  `endgame_ends_at`, centred on `endgame_latitude`/`endgame_longitude`.
  Poles outside the current radius can't be captured, which herds
  everyone toward the party. The radius is a pure function of the
  clock — `endgame_zone/2` — so server enforcement and the client's
  map circle can never disagree.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @schema_prefix "landgrab"
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "events" do
    field(:name, :string)
    field(:start_time, :utc_datetime)

    field(:endgame_latitude, :float)
    field(:endgame_longitude, :float)
    field(:endgame_starts_at, :utc_datetime)
    field(:endgame_ends_at, :utc_datetime)
    field(:endgame_initial_radius_m, :float)
    field(:endgame_final_radius_m, :float)
    field(:endgame_announced_at, :utc_datetime)

    # Relief valve: non-null once a supervisor re-opens stakes (per-team
    # consumption) because the event is running ahead of content.
    field(:relief_started_at, :utc_datetime)

    # Liberation phase: invitations trickle out team-by-team across this
    # window (nil rollout end = every team at the start instant). Per-team
    # invited/answered state lives on the team itself.
    field(:liberation_starts_at, :utc_datetime)
    field(:liberation_rollout_ends_at, :utc_datetime)

    # Bedab's final-location messages, sent stance-gated once the endgame
    # shrink begins: teams that JOINED the liberation get the precise spot,
    # everyone else the vaguer nudge. DB fields (supervisor-edited in the
    # app's Endgame tab) rather than code strings, so the location stays
    # changeable as the event unfolds. The stamp makes sending one-shot.
    field(:final_message_joined, :string)
    field(:final_message_others, :string)
    field(:final_messages_sent_at, :utc_datetime)

    # Admin-authored HTML shown on the public LANDGRAB page below the "visiting
    # scholar Sabuk" line. Blank = nothing shown; rendered raw, so it's trusted
    # admin markup.
    field(:homepage_html, :string)

    timestamps()
  end

  @endgame_fields ~w(endgame_latitude endgame_longitude endgame_starts_at endgame_ends_at endgame_initial_radius_m endgame_final_radius_m)a

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :name,
      :start_time,
      :relief_started_at,
      :liberation_starts_at,
      :liberation_rollout_ends_at,
      :final_message_joined,
      :final_message_others,
      :homepage_html | @endgame_fields
    ])
    |> validate_required([:name])
    |> validate_number(:endgame_initial_radius_m, greater_than: 0)
    |> validate_number(:endgame_final_radius_m, greater_than: 0)
    |> validate_endgame_complete()
    |> validate_endgame_window()
    |> validate_liberation_window()
  end

  def started?(%__MODULE__{start_time: nil}, _now), do: false

  def started?(%__MODULE__{start_time: start_time}, now) do
    DateTime.compare(now, start_time) != :lt
  end

  @doc """
  Whether the game is over. The endgame shrink-window's end
  (`endgame_ends_at`) doubles as the game's end: once it passes,
  relics can no longer be captured (stakes can still be scanned and
  relics viewed). An event without an endgame configured never ends.
  """
  def ended?(%__MODULE__{endgame_ends_at: nil}, _now), do: false

  def ended?(%__MODULE__{endgame_ends_at: ends_at}, now) do
    DateTime.compare(now, ends_at) != :lt
  end

  @doc """
  The endgame zone as of `now`, or nil when not configured or not yet
  begun. Returns `%{latitude, longitude, radius_m}` with the radius
  interpolated linearly between the initial and final values across
  the shrink window (clamped to the final radius afterwards).
  """
  def endgame_zone(%__MODULE__{} = event, now) do
    if endgame_configured?(event) and DateTime.compare(now, event.endgame_starts_at) != :lt do
      %{
        latitude: event.endgame_latitude,
        longitude: event.endgame_longitude,
        radius_m: interpolated_radius(event, now)
      }
    end
  end

  def endgame_configured?(%__MODULE__{} = event) do
    Enum.all?(@endgame_fields, fn field -> Map.get(event, field) != nil end)
  end

  defp interpolated_radius(event, now) do
    total = DateTime.diff(event.endgame_ends_at, event.endgame_starts_at)
    elapsed = DateTime.diff(now, event.endgame_starts_at)

    progress =
      cond do
        total <= 0 -> 1.0
        elapsed >= total -> 1.0
        true -> elapsed / total
      end

    event.endgame_initial_radius_m +
      (event.endgame_final_radius_m - event.endgame_initial_radius_m) * progress
  end

  # All-or-nothing: a partially-configured endgame is a config
  # mistake, not a smaller feature.
  defp validate_endgame_complete(changeset) do
    values = Enum.map(@endgame_fields, &get_field(changeset, &1))

    if Enum.any?(values, &is_nil/1) and not Enum.all?(values, &is_nil/1) do
      add_error(changeset, :endgame_latitude, "endgame needs all six fields (or none)")
    else
      changeset
    end
  end

  defp validate_endgame_window(changeset) do
    starts = get_field(changeset, :endgame_starts_at)
    ends = get_field(changeset, :endgame_ends_at)

    if starts && ends && DateTime.compare(ends, starts) != :gt do
      add_error(changeset, :endgame_ends_at, "must be after the endgame start")
    else
      changeset
    end
  end

  defp validate_liberation_window(changeset) do
    starts = get_field(changeset, :liberation_starts_at)
    ends = get_field(changeset, :liberation_rollout_ends_at)

    cond do
      is_nil(starts) and not is_nil(ends) ->
        add_error(changeset, :liberation_starts_at, "is required when a rollout end is set")

      starts && ends && DateTime.compare(ends, starts) != :gt ->
        add_error(changeset, :liberation_rollout_ends_at, "must be after the liberation start")

      true ->
        changeset
    end
  end
end
