defmodule Registrations.Landgrab.AccommodationTest do
  use Registrations.DataCase, async: true

  import Registrations.Factory

  alias Registrations.Landgrab

  # A prohibitive pole for a stairs-averse team: one puzzlet, in a stairs region.
  defp prohibitive_setup do
    team = insert(:team)
    insert(:user, team_id: team.id, accessibility_tags: ["stairs"])
    region = insert(:poles_region, accessibility_tags: ["stairs"])
    pole = insert(:pole)
    puzzlet = insert(:puzzlet, pole: pole, region_id: region.id, status: :validated)
    %{team: team, pole: pole, puzzlet: puzzlet, region: region}
  end

  describe "accommodate_pole/3" do
    test "claims a prohibitive stake without solving, taking ownership" do
      %{team: team, pole: pole} = prohibitive_setup()

      assert {:ok, ^pole} = Landgrab.accommodate_pole(pole, team.id, nil)
      assert Landgrab.current_owner_team_id_for_pole(pole) == team.id
      # A soft hold — the relic stays unsolved, so the stake isn't locked.
      refute Landgrab.pole_locked?(pole)
    end

    test "refuses when the stake is not prohibitive for the team" do
      # Team with no needs → nothing is prohibitive.
      team = insert(:team)
      insert(:user, team_id: team.id, accessibility_tags: [])
      pole = insert(:pole)
      insert(:puzzlet, pole: pole, status: :validated)

      assert {:error, :not_prohibitive} = Landgrab.accommodate_pole(pole, team.id, nil)
      assert Landgrab.current_owner_team_id_for_pole(pole) == nil
    end

    test "refuses a stake the team already owns" do
      %{team: team, pole: pole} = prohibitive_setup()
      {:ok, _} = Landgrab.accommodate_pole(pole, team.id, nil)

      assert {:error, :already_owner} = Landgrab.accommodate_pole(pole, team.id, nil)
    end

    test "no team can't claim" do
      %{pole: pole} = prohibitive_setup()
      assert {:error, :no_team} = Landgrab.accommodate_pole(pole, nil, nil)
    end
  end

  describe "ownership union (accommodation vs capture, newest wins)" do
    test "a later capture by a team that can solve overrides an accommodation" do
      %{team: cohort, pole: pole, puzzlet: puzzlet} = prohibitive_setup()
      {:ok, _} = Landgrab.accommodate_pole(pole, cohort.id, nil)
      assert Landgrab.current_owner_team_id_for_pole(pole) == cohort.id

      # Another team (no stairs need) solves the relic later → they own it.
      solver = insert(:team)

      insert(:ownership_event,
        puzzlet: puzzlet,
        team: solver,
        pole_id: pole.id,
        inserted_at: DateTime.utc_now() |> DateTime.add(60, :second)
      )

      assert Landgrab.current_owner_team_id_for_pole(pole) == solver.id
    end

    test "a later accommodation overrides an earlier capture" do
      %{team: cohort, pole: pole, puzzlet: puzzlet} = prohibitive_setup()

      # An earlier capture by some team.
      solver = insert(:team)

      insert(:ownership_event,
        puzzlet: puzzlet,
        team: solver,
        pole_id: pole.id,
        inserted_at: DateTime.utc_now() |> DateTime.add(-60, :second)
      )

      # But now the whole pole is captured, so it's no longer prohibitive...
      # give the cohort a *second*, uncaptured, conflicting relic so the pole
      # is still prohibitive for them.
      insert(:puzzlet, pole: pole, region_id: prohibitive_region().id, status: :validated)

      {:ok, _} = Landgrab.accommodate_pole(pole, cohort.id, nil)
      assert Landgrab.current_owner_team_id_for_pole(pole) == cohort.id
    end
  end

  defp prohibitive_region, do: insert(:poles_region, accessibility_tags: ["stairs"])
end
