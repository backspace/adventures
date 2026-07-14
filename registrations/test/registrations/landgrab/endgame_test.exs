defmodule Registrations.Landgrab.EndgameTest do
  use Registrations.DataCase

  alias Registrations.Landgrab
  alias Registrations.Landgrab.Event
  alias Registrations.Landgrab.Events
  alias Registrations.Landgrab.Notification
  alias Registrations.Landgrab.Pole
  alias Registrations.Repo

  # Wrap party at the Forks; radius shrinks 2000 m → 100 m over an hour.
  @party_lat 49.8874
  @party_lng -97.1305
  @starts ~U[2026-07-25 22:00:00Z]
  @ends ~U[2026-07-25 23:00:00Z]

  defp configure_endgame do
    {:ok, event} =
      Events.update(Events.current(), %{
        endgame_latitude: @party_lat,
        endgame_longitude: @party_lng,
        endgame_starts_at: @starts,
        endgame_ends_at: @ends,
        endgame_initial_radius_m: 2000.0,
        endgame_final_radius_m: 100.0
      })

    event
  end

  # ~1500 m north of the party centre.
  defp far_pole do
    %Pole{
      id: Ecto.UUID.generate(),
      latitude: @party_lat + 1500 / 111_000.0,
      longitude: @party_lng
    }
  end

  describe "Event.endgame_zone/2" do
    test "nil before the start and when unconfigured" do
      assert Event.endgame_zone(Events.current(), @starts) == nil

      event = configure_endgame()
      assert Event.endgame_zone(event, ~U[2026-07-25 21:59:59Z]) == nil
    end

    test "interpolates linearly and clamps at the final radius" do
      event = configure_endgame()

      assert Event.endgame_zone(event, @starts).radius_m == 2000.0

      halfway = Event.endgame_zone(event, ~U[2026-07-25 22:30:00Z])
      assert_in_delta halfway.radius_m, 1050.0, 0.001

      after_end = Event.endgame_zone(event, ~U[2026-07-26 01:00:00Z])
      assert after_end.radius_m == 100.0
    end
  end

  describe "pole_outside_endgame_zone?/2" do
    test "false before the shrink starts, true once the boundary passes" do
      configure_endgame()
      pole = far_pole()

      refute Landgrab.pole_outside_endgame_zone?(pole, ~U[2026-07-25 21:00:00Z])
      # At start the radius (2000 m) still covers the 1500 m pole.
      refute Landgrab.pole_outside_endgame_zone?(pole, @starts)
      # By 30 min the radius is ~1050 m — the pole is out of play.
      assert Landgrab.pole_outside_endgame_zone?(pole, ~U[2026-07-25 22:30:00Z])
    end

    test "never excludes a locationless pole" do
      configure_endgame()
      pole = %Pole{id: Ecto.UUID.generate(), latitude: nil, longitude: nil}

      refute Landgrab.pole_outside_endgame_zone?(pole, ~U[2026-07-25 22:59:00Z])
    end
  end

  describe "maybe_announce_endgame/1" do
    test "noop when unconfigured or before the start" do
      assert Landgrab.maybe_announce_endgame(@starts) == :noop

      configure_endgame()
      assert Landgrab.maybe_announce_endgame(~U[2026-07-25 21:00:00Z]) == :noop
      assert Repo.aggregate(Notification, :count) == 0
    end

    test "announces exactly once as SYSTEM" do
      team = insert(:team)
      insert(:user, email: "endgame#{System.unique_integer([:positive])}@example.com", team_id: team.id)
      configure_endgame()

      assert {:announced, 1} = Landgrab.maybe_announce_endgame(~U[2026-07-25 22:00:30Z])

      [notification] = Repo.all(Notification)
      assert notification.type == "message"
      assert notification.recipient_team_id == team.id
      assert notification.metadata["sender_name"] == "SYSTEM"
      assert notification.body =~ "contraction"

      # The stamp survives; polling again never re-sends.
      assert Landgrab.maybe_announce_endgame(~U[2026-07-25 22:01:30Z]) == :noop
      assert Repo.aggregate(Notification, :count) == 1
    end
  end
end
