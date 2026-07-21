defmodule Registrations.Landgrab.ReliefTest do
  use Registrations.DataCase, async: true

  import Registrations.Factory

  alias Registrations.Landgrab
  alias Registrations.Landgrab.Events
  alias Registrations.Landgrab.Notification

  defp message_count,
    do: Repo.aggregate(from(n in Notification, where: n.type == "message"), :count)

  defp turn_relief_on do
    {:ok, _} =
      Events.update(Events.current(), %{
        relief_started_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
  end

  describe "relief_stats/0" do
    test "counts poles and builds an ownership leaderboard, most first" do
      a = insert(:team)
      b = insert(:team)

      # Two poles owned by A (each fully captured), one by B, one uncaptured.
      for _ <- 1..2 do
        pole = insert(:pole)
        z = insert(:puzzlet, pole: pole, status: :validated)
        insert(:ownership_event, puzzlet: z, team: a, pole_id: pole.id)
      end

      b_pole = insert(:pole)
      bz = insert(:puzzlet, pole: b_pole, status: :validated)
      insert(:ownership_event, puzzlet: bz, team: b, pole_id: b_pole.id)

      open_pole = insert(:pole)
      insert(:puzzlet, pole: open_pole, status: :validated)

      stats = Landgrab.relief_stats()

      assert stats.total_poles == 4
      assert stats.in_play == 4
      # Only the uncaptured one has anything left to do.
      assert stats.not_fully_captured == 1
      assert stats.capturable_in_play == 1

      assert [%{team_id: first, owned: 2}, %{owned: 1}] = stats.leaderboard
      assert first == a.id
    end
  end

  describe "relief_active?/0" do
    test "false by default, true once the flag is set" do
      refute Landgrab.relief_active?()
      turn_relief_on()
      assert Landgrab.relief_active?()
    end
  end

  describe "active_puzzlet_for_pole/4 in relief mode" do
    test "off: a puzzlet captured by anyone is not served to another team" do
      pole = insert(:pole)
      puzzlet = insert(:puzzlet, pole: pole, status: :validated)
      other = insert(:team)
      insert(:ownership_event, puzzlet: puzzlet, team: other, pole_id: pole.id)

      team = insert(:team)
      # Global consume-once: nothing left to serve.
      assert Landgrab.active_puzzlet_for_pole(pole, nil, [], team.id) == nil
    end

    test "on: a puzzlet another team solved is still served to a fresh team" do
      turn_relief_on()
      pole = insert(:pole)
      puzzlet = insert(:puzzlet, pole: pole, status: :validated)
      other = insert(:team)
      insert(:ownership_event, puzzlet: puzzlet, team: other, pole_id: pole.id)

      team = insert(:team)
      served = Landgrab.active_puzzlet_for_pole(pole, nil, [], team.id)
      assert served && served.id == puzzlet.id
    end

    test "on: the team's own solved puzzlet is not re-served; the next is" do
      turn_relief_on()
      pole = insert(:pole)
      p1 = insert(:puzzlet, pole: pole, status: :validated, difficulty: 1)
      p2 = insert(:puzzlet, pole: pole, status: :validated, difficulty: 2)
      team = insert(:team)
      insert(:ownership_event, puzzlet: p1, team: team, pole_id: pole.id)

      served = Landgrab.active_puzzlet_for_pole(pole, nil, [], team.id)
      assert served && served.id == p2.id
    end
  end

  describe "pole_exhausted_for_team?/2" do
    test "true only once the team has solved every playable puzzlet" do
      pole = insert(:pole)
      p1 = insert(:puzzlet, pole: pole, status: :validated)
      p2 = insert(:puzzlet, pole: pole, status: :validated)
      team = insert(:team)

      refute Landgrab.pole_exhausted_for_team?(pole, team.id)

      insert(:ownership_event, puzzlet: p1, team: team, pole_id: pole.id)
      refute Landgrab.pole_exhausted_for_team?(pole, team.id)

      insert(:ownership_event, puzzlet: p2, team: team, pole_id: pole.id)
      assert Landgrab.pole_exhausted_for_team?(pole, team.id)
    end

    test "another team's solves don't exhaust it for you" do
      pole = insert(:pole)
      p = insert(:puzzlet, pole: pole, status: :validated)
      other = insert(:team)
      insert(:ownership_event, puzzlet: p, team: other, pole_id: pole.id)

      team = insert(:team)
      refute Landgrab.pole_exhausted_for_team?(pole, team.id)
    end
  end

  # The reported bug: relief served a second team the puzzlet another team had
  # captured, but answering was rejected `already_captured` because the WRITE
  # path still applied the global guard. The write path must be relief-aware too.
  describe "record_attempt/4 with a puzzlet another team already captured" do
    setup do
      pole = insert(:pole)
      puzzlet = insert(:puzzlet, pole: pole, status: :validated, answer: "x")
      first = insert(:team)
      # Deterministically older than the second team's capture below, so
      # newest-wins ownership is unambiguous.
      insert(:ownership_event,
        puzzlet: puzzlet,
        team: first,
        pole_id: pole.id,
        inserted_at: DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)
      )

      second = insert(:team)
      user = insert(:user, team_id: second.id)
      insert(:team_puzzlet, team: second, puzzlet: puzzlet, pole: pole)
      %{pole: pole, puzzlet: puzzlet, second: second, user: user}
    end

    test "off: the second team is rejected (global consume-once)", ctx do
      assert {:error, :already_captured} =
               Landgrab.record_attempt(ctx.puzzlet, ctx.second.id, ctx.user.id, "x")
    end

    test "on: the second team can capture it", ctx do
      turn_relief_on()

      assert {:ok, %{result: :captured}} =
               Landgrab.record_attempt(ctx.puzzlet, ctx.second.id, ctx.user.id, "x")

      assert Landgrab.current_owner_team_id_for_pole(ctx.pole) == ctx.second.id
    end

    # (A team can't double-solve one puzzlet — enforced by the per-team unique
    # index, covered deterministically in OwnershipEventTest.)
  end

  describe "set_relief_active/1 announcements" do
    setup do
      # send_organiser_message fans to teams with at least one member.
      t1 = insert(:team)
      insert(:user, team_id: t1.id)
      t2 = insert(:team)
      insert(:user, team_id: t2.id)
      :ok
    end

    test "enabling notifies every team once; re-enabling doesn't re-notify" do
      assert message_count() == 0

      {:ok, true} = Landgrab.set_relief_active(true)
      assert message_count() == 2

      # Already on → no fresh announcement.
      {:ok, true} = Landgrab.set_relief_active(true)
      assert message_count() == 2
    end

    test "the announcement carries the relief copy with gameplay terms" do
      {:ok, true} = Landgrab.set_relief_active(true)
      note = Repo.one(from(n in Notification, where: n.type == "message", limit: 1))
      assert note.body =~ "revisited"
      assert note.body =~ "zones"
      assert note.metadata["sender_name"] == "SYSTEM"
    end

    test "disabling doesn't notify" do
      {:ok, false} = Landgrab.set_relief_active(false)
      assert message_count() == 0
    end
  end
end
