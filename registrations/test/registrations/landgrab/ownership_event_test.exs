defmodule Registrations.Landgrab.OwnershipEventTest do
  use Registrations.DataCase, async: true

  import Registrations.Factory

  alias Registrations.Landgrab
  alias Registrations.Landgrab.OwnershipEvent
  alias Registrations.Repo

  # Explicit, ordered timestamps so "newest wins" is deterministic (inserts in
  # the same second would otherwise tie).
  defp at(minute), do: ~U[2026-07-20 12:00:00Z] |> DateTime.add(minute * 60, :second)

  describe "current_owner_team_id_for_pole/1 (newest capture wins)" do
    test "nil when the pole has no captures" do
      pole = insert(:pole)
      insert(:puzzlet, pole: pole)
      assert Landgrab.current_owner_team_id_for_pole(pole) == nil
    end

    test "the latest capture among the pole's puzzlets sets the owner" do
      pole = insert(:pole)
      p1 = insert(:puzzlet, pole: pole)
      p2 = insert(:puzzlet, pole: pole)
      a = insert(:team)
      b = insert(:team)

      insert(:ownership_event, puzzlet: p1, team: a, pole_id: pole.id, inserted_at: at(0))
      insert(:ownership_event, puzzlet: p2, team: b, pole_id: pole.id, inserted_at: at(5))

      # b captured later → b owns the pole.
      assert Landgrab.current_owner_team_id_for_pole(pole) == b.id
    end

    test "resolves owners for flips less than a second apart" do
      # inserted_at is microsecond-precise, so two captures on the same pole
      # a microsecond apart order correctly — a second-granular column would
      # have tied and picked a holder nondeterministically.
      pole = insert(:pole)
      p1 = insert(:puzzlet, pole: pole)
      p2 = insert(:puzzlet, pole: pole)
      a = insert(:team)
      b = insert(:team)

      t0 = ~U[2026-07-20 12:00:00.000000Z]
      insert(:ownership_event, puzzlet: p1, team: a, pole_id: pole.id, inserted_at: t0)

      insert(:ownership_event,
        puzzlet: p2,
        team: b,
        pole_id: pole.id,
        inserted_at: DateTime.add(t0, 1, :microsecond)
      )

      assert Landgrab.current_owner_team_id_for_pole(pole) == b.id
    end
  end

  describe "pole_locked?/1" do
    test "false with no captures, false with partial, true when all captured" do
      pole = insert(:pole)
      p1 = insert(:puzzlet, pole: pole, status: :validated)
      p2 = insert(:puzzlet, pole: pole, status: :validated)
      team = insert(:team)

      refute Landgrab.pole_locked?(pole)

      insert(:ownership_event, puzzlet: p1, team: team, pole_id: pole.id)
      refute Landgrab.pole_locked?(pole)

      insert(:ownership_event, puzzlet: p2, team: team, pole_id: pole.id)
      assert Landgrab.pole_locked?(pole)
    end

    test "validator-only puzzlets don't count toward locking" do
      pole = insert(:pole)
      p = insert(:puzzlet, pole: pole, status: :validated)
      _vo = insert(:puzzlet, pole: pole, status: :validated, validator_only: true)
      team = insert(:team)

      insert(:ownership_event, puzzlet: p, team: team, pole_id: pole.id)
      # The single player puzzlet is captured; the VO one is set aside.
      assert Landgrab.pole_locked?(pole)
    end
  end

  describe "solve-completion uniqueness (the relief-valve capacity)" do
    test "a team can't record two captures of the same puzzlet" do
      pole = insert(:pole)
      p = insert(:puzzlet, pole: pole)
      team = insert(:team)
      insert(:ownership_event, puzzlet: p, team: team, pole_id: pole.id)

      {:error, changeset} =
        %OwnershipEvent{}
        |> OwnershipEvent.changeset(%{
          kind: "capture",
          pole_id: pole.id,
          puzzlet_id: p.id,
          team_id: team.id
        })
        |> Repo.insert()

      assert {"has already been taken", _} = changeset.errors[:puzzlet_id]
    end

    test "different teams can each solve the same puzzlet (multi-capture allowed)" do
      pole = insert(:pole)
      p = insert(:puzzlet, pole: pole)
      a = insert(:team)
      b = insert(:team)

      insert(:ownership_event, puzzlet: p, team: a, pole_id: pole.id)
      insert(:ownership_event, puzzlet: p, team: b, pole_id: pole.id)

      count =
        Repo.aggregate(
          from(c in OwnershipEvent, where: c.puzzlet_id == ^p.id),
          :count
        )

      assert count == 2
    end
  end
end
