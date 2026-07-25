defmodule Registrations.Landgrab.SupervisorStuckTest do
  use Registrations.DataCase

  alias Registrations.Accounts
  alias Registrations.Landgrab
  alias Registrations.Landgrab.Puzzlet
  alias Registrations.Repo

  defp attempt(puzzlet, team, user, given) do
    Landgrab.record_attempt(Repo.get(Puzzlet, puzzlet.id), team.id, user.id, given)
  end

  describe "supervisor notification on lockout" do
    setup do
      team = insert(:team, name: "Team Zeta")
      user = insert(:user, team_id: team.id)

      supervisor_team = insert(:team, name: "Supervisors")
      supervisor = insert(:user, team_id: supervisor_team.id)
      Accounts.assign_role(supervisor.id, "validation_supervisor")

      pole = insert(:pole, label: "The Forks")

      puzzlet =
        insert(:puzzlet,
          pole: pole,
          status: :validated,
          answer_type: :barcode,
          answer: "012345678905"
        )

      # Answering requires an active row — scan the pole first.
      {:ok, _} = Landgrab.scan_payload(pole.barcode, team.id, user.id)

      %{team: team, user: user, supervisor_team: supervisor_team, pole: pole, puzzlet: puzzlet}
    end

    test "notifies the supervisor's team when a team exhausts its three guesses", ctx do
      %{team: team, user: user, puzzlet: puzzlet, supervisor_team: supervisor_team} = ctx

      assert {:ok, %{result: :incorrect, attempts_remaining: 2}} =
               attempt(puzzlet, team, user, "11111111111")

      assert {:ok, %{result: :incorrect, attempts_remaining: 1}} =
               attempt(puzzlet, team, user, "22222222222")

      # No supervisor is troubled while the team still has a guess left.
      assert Landgrab.list_notifications_for_team(supervisor_team.id) == []

      assert {:ok, %{result: :incorrect, attempts_remaining: 0}} =
               attempt(puzzlet, team, user, "33333333333")

      assert [notification] = Landgrab.list_notifications_for_team(supervisor_team.id)
      assert notification.type == "team_stuck"
      assert notification.recipient_team_id == supervisor_team.id
      assert notification.body =~ "Team Zeta"
      assert notification.body =~ "The Forks"
      assert notification.metadata["stuck_team_id"] == team.id
      assert notification.metadata["puzzlet_id"] == puzzlet.id
      # The correct answer never rides the (publicly broadcast) notification.
      refute notification.body =~ "012345678905"
      refute Map.has_key?(notification.metadata, "answer")

      assert Landgrab.count_unread_notifications(supervisor_team.id) == 1
    end

    test "notifies every supervisor's team, once each", ctx do
      %{team: team, user: user, puzzlet: puzzlet, supervisor_team: first_team} = ctx

      # A second supervisor on their own team, plus a co-supervisor sharing the
      # first team — the shared team should still get exactly one notification.
      second_team = insert(:team, name: "Supervisors Two")
      second = insert(:user, team_id: second_team.id)
      Accounts.assign_role(second.id, "validation_supervisor")

      co = insert(:user, team_id: first_team.id)
      Accounts.assign_role(co.id, "validation_supervisor")

      attempt(puzzlet, team, user, "11111111111")
      attempt(puzzlet, team, user, "22222222222")
      attempt(puzzlet, team, user, "33333333333")

      assert length(Landgrab.list_notifications_for_team(first_team.id)) == 1
      assert length(Landgrab.list_notifications_for_team(second_team.id)) == 1
    end
  end

  describe "supervision_wrong_answers ordering" do
    test "puzzlets are sorted by most recent failure, not by miss count" do
      team = insert(:team)
      user = insert(:user, team_id: team.id)

      pole_a = insert(:pole, label: "Alpha")
      pole_b = insert(:pole, label: "Bravo")
      puzzlet_a = insert(:puzzlet, pole: pole_a, answer: "aaa")
      puzzlet_b = insert(:puzzlet, pole: pole_b, answer: "bbb")

      # Puzzlet A is missed twice, but longer ago. Puzzlet B is missed once,
      # most recently — so B must come first (recency), proving the sort is
      # not by wrong_count (which would put A first).
      insert(:attempt,
        puzzlet: puzzlet_a,
        team: team,
        user: user,
        correct: false,
        answer_given: "a-old",
        inserted_at: ~N[2026-07-01 10:00:00]
      )

      insert(:attempt,
        puzzlet: puzzlet_a,
        team: team,
        user: user,
        correct: false,
        answer_given: "a-new",
        inserted_at: ~N[2026-07-01 10:01:00]
      )

      insert(:attempt,
        puzzlet: puzzlet_b,
        team: team,
        user: user,
        correct: false,
        answer_given: "b-only",
        inserted_at: ~N[2026-07-01 10:05:00]
      )

      %{puzzlets: [first, second]} = Landgrab.supervision_wrong_answers()

      assert first.puzzlet_id == puzzlet_b.id
      assert first.wrong_count == 1
      assert second.puzzlet_id == puzzlet_a.id
      assert second.wrong_count == 2

      # Each row carries the player-facing synthetic name (matches the
      # notification) alongside label/barcode.
      assert first.pole.name == Landgrab.pole_name(Repo.reload!(pole_b))
      assert is_binary(first.pole.name) and first.pole.name != ""

      # Within a puzzlet, attempts also run newest → oldest.
      assert Enum.map(second.attempts, & &1.answer_given) == ["a-new", "a-old"]
    end
  end
end
