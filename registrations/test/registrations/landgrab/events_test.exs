defmodule Registrations.Landgrab.EventsTest do
  use Registrations.DataCase, async: true

  alias Registrations.Landgrab.Event
  alias Registrations.Landgrab.Events
  alias Registrations.Repo

  defp insert_event(attrs) do
    %Event{}
    |> Event.changeset(Map.merge(%{name: "LANDGRAB"}, attrs))
    |> Repo.insert!()
  end

  describe "shift_schedule/3" do
    setup do
      start = ~U[2026-07-25 17:00:00Z]
      eg_start = ~U[2026-07-25 18:00:00Z]
      eg_end = ~U[2026-07-25 18:30:00Z]
      lib_start = ~U[2026-07-25 18:10:00Z]
      lib_end = ~U[2026-07-25 18:20:00Z]

      event =
        insert_event(%{
          start_time: start,
          endgame_latitude: 49.9,
          endgame_longitude: -97.1,
          endgame_starts_at: eg_start,
          endgame_ends_at: eg_end,
          endgame_initial_radius_m: 2000.0,
          endgame_final_radius_m: 150.0,
          liberation_starts_at: lib_start,
          liberation_rollout_ends_at: lib_end
        })

      %{
        event: event,
        times: %{
          start: start,
          eg_start: eg_start,
          eg_end: eg_end,
          lib_start: lib_start,
          lib_end: lib_end
        }
      }
    end

    test "before the event begins, the whole timeline (start included) slides",
         %{event: event, times: t} do
      # "Now" is before everything, so every milestone is still upcoming.
      {:ok, shifted} = Events.shift_schedule(event, 300, ~U[2026-07-25 16:00:00Z])

      assert DateTime.compare(shifted.start_time, DateTime.add(t.start, 300)) == :eq
      assert DateTime.compare(shifted.endgame_starts_at, DateTime.add(t.eg_start, 300)) == :eq
      assert DateTime.compare(shifted.endgame_ends_at, DateTime.add(t.eg_end, 300)) == :eq
      assert DateTime.compare(shifted.liberation_starts_at, DateTime.add(t.lib_start, 300)) == :eq

      assert DateTime.compare(shifted.liberation_rollout_ends_at, DateTime.add(t.lib_end, 300)) ==
               :eq
    end

    test "already-passed milestones (and the begun start) stay put; only future ones move",
         %{event: event, times: t} do
      # Mid-event: start and the shrink start are past; the rest are upcoming.
      {:ok, shifted} = Events.shift_schedule(event, 300, ~U[2026-07-25 18:05:00Z])

      # Past — untouched.
      assert DateTime.compare(shifted.start_time, t.start) == :eq
      assert DateTime.compare(shifted.endgame_starts_at, t.eg_start) == :eq

      # Future — moved.
      assert DateTime.compare(shifted.endgame_ends_at, DateTime.add(t.eg_end, 300)) == :eq
      assert DateTime.compare(shifted.liberation_starts_at, DateTime.add(t.lib_start, 300)) == :eq

      assert DateTime.compare(shifted.liberation_rollout_ends_at, DateTime.add(t.lib_end, 300)) ==
               :eq
    end

    test "leaves nil milestones nil" do
      event = insert_event(%{start_time: ~U[2026-07-25 17:00:00Z]})

      {:ok, shifted} = Events.shift_schedule(event, 300, ~U[2026-07-25 16:00:00Z])

      assert is_nil(shifted.endgame_starts_at)
      assert is_nil(shifted.liberation_starts_at)
    end
  end
end
