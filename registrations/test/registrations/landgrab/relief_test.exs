defmodule Registrations.Landgrab.ReliefTest do
  use Registrations.DataCase, async: true

  import Registrations.Factory

  alias Registrations.Landgrab
  alias Registrations.Landgrab.Events

  defp turn_relief_on do
    {:ok, _} =
      Events.update(Events.current(), %{
        relief_started_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
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
end
