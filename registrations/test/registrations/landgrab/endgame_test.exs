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
      # The words live in landgrab.po and may be tweaked freely; the
      # contract is that the announcement IS the PlayerStrings one.
      assert notification.body == Registrations.Landgrab.PlayerStrings.endgame_announcement()

      # The stamp survives; polling again never re-sends.
      assert Landgrab.maybe_announce_endgame(~U[2026-07-25 22:01:30Z]) == :noop
      assert Repo.aggregate(Notification, :count) == 1
    end
  end

  describe "maybe_send_final_location_messages/1" do
    defp member_team(response \\ nil) do
      team = insert(:team)

      team =
        if response,
          do: team |> Ecto.Changeset.change(liberation_response: response) |> Repo.update!(),
          else: team

      insert(:user, email: "final#{System.unique_integer([:positive])}@example.com", team_id: team.id)
      team
    end

    defp set_messages(joined, others) do
      {:ok, _} =
        Events.update(Events.current(), %{
          final_message_joined: joined,
          final_message_others: others
        })
    end

    test "noop before the shrink begins, and without any body set" do
      member_team()
      configure_endgame()
      set_messages("Come to the spot.", "Ask around.")

      # Shrink hasn't started.
      assert Landgrab.maybe_send_final_location_messages(~U[2026-07-25 21:00:00Z]) == :noop

      # Shrink started but nothing written yet.
      set_messages(nil, "  ")
      assert Landgrab.maybe_send_final_location_messages(~U[2026-07-25 22:00:30Z]) == :noop
      assert Repo.aggregate(Notification, :count) == 0
    end

    test "sends the stance-gated body from Bedab, exactly once" do
      joined = member_team("accepted")
      declined = member_team("declined")
      undecided = member_team()
      configure_endgame()
      set_messages("Meet at the precise spot.", "Something is happening. Ask around.")

      # Only once the shrink has fully run (endgame_ends_at = 23:00), not mid-shrink.
      assert {:sent, 3} = Landgrab.maybe_send_final_location_messages(~U[2026-07-25 23:00:00Z])

      body_for = fn team_id ->
        Repo.one(from(n in Notification, where: n.recipient_team_id == ^team_id)).body
      end

      assert body_for.(joined.id) == "Meet at the precise spot."
      assert body_for.(declined.id) == "Something is happening. Ask around."
      assert body_for.(undecided.id) == "Something is happening. Ask around."

      [first | _] = Repo.all(Notification)
      assert first.metadata["sender_name"] == "Bedab"

      # One-shot: the stamp survives later polls and later edits.
      set_messages("Changed my mind.", "Changed too.")
      assert Landgrab.maybe_send_final_location_messages(~U[2026-07-25 23:05:00Z]) == :noop
      assert Repo.aggregate(Notification, :count) == 3
    end

    test "a blank body skips those teams (and only those)" do
      member_team("accepted")
      other = member_team()
      configure_endgame()
      set_messages(nil, "The vague nudge.")

      assert {:sent, 1} = Landgrab.maybe_send_final_location_messages(~U[2026-07-25 23:00:00Z])
      [notification] = Repo.all(Notification)
      assert notification.recipient_team_id == other.id
    end

    test "waits for the shrink to end, even with bodies set mid-shrink" do
      member_team()
      configure_endgame()

      # No bodies yet, mid-shrink — nothing to send.
      assert Landgrab.maybe_send_final_location_messages(~U[2026-07-25 22:00:30Z]) == :noop

      # Bodies written mid-shrink still hold until the shrink actually ends.
      set_messages("Late but here.", "Late nudge.")
      assert Landgrab.maybe_send_final_location_messages(~U[2026-07-25 22:30:00Z]) == :noop

      # Once endgame_ends_at (23:00) passes, they go out.
      assert {:sent, 1} = Landgrab.maybe_send_final_location_messages(~U[2026-07-25 23:00:00Z])
    end
  end

  describe "out-of-play takes priority over own-creation" do
    # scan_payload/3 and record_attempt/4 check the boundary against the
    # real clock, so configure an endgame that is shrinking right now.
    defp shrinking_now do
      now = DateTime.utc_now()

      {:ok, _event} =
        Events.update(Events.current(), %{
          endgame_latitude: @party_lat,
          endgame_longitude: @party_lng,
          endgame_starts_at: DateTime.add(now, -3600, :second),
          endgame_ends_at: DateTime.add(now, 3600, :second),
          endgame_initial_radius_m: 2000.0,
          endgame_final_radius_m: 100.0
        })

      :ok
    end

    # ~1500 m north of the party centre — outside the ~1050 m mid-shrink
    # radius — created by the scanning user.
    defp far_own_pole(creator) do
      insert(:pole,
        creator: creator,
        latitude: @party_lat + 1500 / 111_000.0,
        longitude: @party_lng
      )
    end

    test "scan of an out-of-play stake reports outside_zone, not own_creation" do
      shrinking_now()
      creator = insert(:user, email: "oz#{System.unique_integer([:positive])}@example.com")
      team = insert(:team)
      pole = far_own_pole(creator)
      insert(:puzzlet, pole: pole, answer: "x")

      assert {:error, :outside_zone, _pole} =
               Landgrab.scan_payload(pole.barcode, team.id, creator.id)
    end

    test "answering an out-of-play relic reports outside_zone, not own_creation" do
      shrinking_now()
      creator = insert(:user, email: "oz#{System.unique_integer([:positive])}@example.com")
      team = insert(:team)
      pole = far_own_pole(creator)
      puzzlet = insert(:puzzlet, pole: pole, answer: "x")

      assert {:error, :outside_zone} =
               Landgrab.record_attempt(puzzlet, team.id, creator.id, "x")
    end
  end
end
