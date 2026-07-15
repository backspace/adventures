defmodule Registrations.Landgrab.TeamPuzzletsTest do
  use Registrations.DataCase

  import Ecto.Query

  alias Registrations.Landgrab
  alias Registrations.Landgrab.Notification
  alias Registrations.Landgrab.Puzzlet
  alias Registrations.Landgrab.TeamPuzzlet
  alias Registrations.Repo

  defp pole, do: insert(:pole)

  defp validated_puzzlet(pole, attrs) do
    insert(:puzzlet, Keyword.merge([pole: pole, status: :validated, answer: "Foo"], attrs))
  end

  describe "assign / capacity / resume via scan" do
    setup do
      team = insert(:team)
      user = insert(:user, team_id: team.id)
      %{team: team, user: user}
    end

    test "scanning persists the team's active puzzlet", %{team: team, user: user} do
      p = pole()
      validated_puzzlet(p, difficulty: 1)

      assert {:ok, payload} = Landgrab.scan_payload(p.barcode, team.id, user.id)
      assert payload.active_puzzlet

      assert [resumed] = Landgrab.list_active_puzzlets_for_team(team.id)
      assert resumed.active_puzzlet.id == payload.active_puzzlet.id
    end

    test "re-scanning the same pole resumes (not at capacity)", %{team: team, user: user} do
      p = pole()
      validated_puzzlet(p, difficulty: 1)

      assert {:ok, _} = Landgrab.scan_payload(p.barcode, team.id, user.id)
      assert {:ok, again} = Landgrab.scan_payload(p.barcode, team.id, user.id)
      assert again.active_puzzlet
      assert length(Landgrab.list_active_puzzlets_for_team(team.id)) == 1
    end

    test "scanning a second pole is refused at capacity (N=1)", %{team: team, user: user} do
      p1 = pole()
      validated_puzzlet(p1, difficulty: 1)
      p2 = pole()
      validated_puzzlet(p2, difficulty: 1)

      assert {:ok, _} = Landgrab.scan_payload(p1.barcode, team.id, user.id)
      assert {:error, :at_capacity, active, ^p2} = Landgrab.scan_payload(p2.barcode, team.id, user.id)
      assert length(active) == 1
      # No second row created.
      assert Repo.aggregate(from(tp in TeamPuzzlet, where: tp.team_id == ^team.id), :count) == 1
    end

    test "abandoning frees the slot", %{team: team, user: user} do
      p = pole()
      pz = validated_puzzlet(p, difficulty: 1)

      Landgrab.scan_payload(p.barcode, team.id, user.id)
      Landgrab.abandon_active_puzzlet(team.id, pz.id)

      assert Landgrab.list_active_puzzlets_for_team(team.id) == []
    end
  end

  describe "resolution on capture (contention)" do
    test "capturing clears the captor's row, notifies rivals, and flags has_next" do
      p = pole()
      easy = validated_puzzlet(p, difficulty: 1)
      _hard = validated_puzzlet(p, difficulty: 2)

      captor = insert(:team)
      captor_user = insert(:user, team_id: captor.id)
      rival = insert(:team)
      rival_user = insert(:user, team_id: rival.id)

      # Both teams pick up the difficulty-1 puzzlet.
      Landgrab.scan_payload(p.barcode, captor.id, captor_user.id)
      Landgrab.scan_payload(p.barcode, rival.id, rival_user.id)

      assert {:ok, %{result: :captured}} =
               Landgrab.record_attempt(Repo.get(Puzzlet, easy.id), captor.id, captor_user.id, "Foo")

      # Both teams' active rows for the captured puzzlet are gone.
      assert Landgrab.list_active_puzzlets_for_team(captor.id) == []
      assert Landgrab.list_active_puzzlets_for_team(rival.id) == []

      # The rival is told, with has_next true (difficulty-2 remains).
      taken = Repo.one(from(n in Notification, where: n.type == "puzzlet_taken"))
      assert taken.recipient_team_id == rival.id
      assert taken.metadata["has_next"] == true
      assert taken.metadata["pole_id"] == p.id
    end

    test "has_next is false when the captured puzzlet was the pole's last" do
      p = pole()
      only = validated_puzzlet(p, difficulty: 1)

      captor = insert(:team)
      captor_user = insert(:user, team_id: captor.id)
      rival = insert(:team)
      rival_user = insert(:user, team_id: rival.id)

      Landgrab.scan_payload(p.barcode, rival.id, rival_user.id)

      Landgrab.record_attempt(Repo.get(Puzzlet, only.id), captor.id, captor_user.id, "Foo")

      taken = Repo.one(from(n in Notification, where: n.type == "puzzlet_taken"))
      assert taken.metadata["has_next"] == false
    end
  end

  describe "resolution on lockout" do
    test "using the last guess frees the team's slot" do
      p = pole()
      pz = validated_puzzlet(p, difficulty: 1)
      team = insert(:team)
      user = insert(:user, team_id: team.id)

      Landgrab.scan_payload(p.barcode, team.id, user.id)
      puzzlet = Repo.get(Puzzlet, pz.id)

      # Exhaust the 3 guesses.
      for _ <- 1..Landgrab.max_attempts_per_puzzlet() do
        Landgrab.record_attempt(puzzlet, team.id, user.id, "wrong")
      end

      assert Landgrab.list_active_puzzlets_for_team(team.id) == []
    end
  end

  describe "assign_active_puzzlet_for_pole (try the next one)" do
    test "assigns the pole's next puzzlet without a rescan" do
      p = pole()
      easy = validated_puzzlet(p, difficulty: 1)
      _hard = validated_puzzlet(p, difficulty: 2)

      team = insert(:team)
      user = insert(:user, team_id: team.id)
      other = insert(:team)
      other_user = insert(:user, team_id: other.id)

      # Rival captures the easy one; our team had nothing yet.
      Landgrab.record_attempt(Repo.get(Puzzlet, easy.id), other.id, other_user.id, "Foo")

      assert {:ok, puzzlet} = Landgrab.assign_active_puzzlet_for_pole(team.id, user.id, p.id)
      assert puzzlet.difficulty == 2
      assert [%{active_puzzlet: %{difficulty: 2}}] = Landgrab.list_active_puzzlets_for_team(team.id)
    end
  end
end
