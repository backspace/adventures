defmodule Registrations.Landgrab.WithdrawPuzzletTest do
  use Registrations.DataCase

  import Ecto.Query

  alias Registrations.Landgrab
  alias Registrations.Landgrab.Notification
  alias Registrations.Landgrab.Puzzlet
  alias Registrations.Repo

  defp working_team(pole) do
    team = insert(:team)
    user = insert(:user, team_id: team.id)
    {:ok, _} = Landgrab.scan_payload(pole.barcode, team.id, user.id)
    team
  end

  test "withdrawing notifies teams working it, frees their slot, and marks it withdrawn" do
    pole = insert(:pole)
    easy = insert(:puzzlet, pole: pole, status: :validated, difficulty: 1, answer: "Foo")
    _hard = insert(:puzzlet, pole: pole, status: :validated, difficulty: 2, answer: "Bar")
    team = working_team(pole)

    assert {:ok, %Puzzlet{status: :withdrawn}} = Landgrab.withdraw_puzzlet(easy.id)

    # The team's active row for the withdrawn puzzlet is gone...
    assert Landgrab.list_active_puzzlets_for_team(team.id) == []

    # ...and they were told, with has_next true (difficulty-2 remains) — the
    # same shape as a rival capture, so the client offers "try the next one".
    n = Repo.one(from(n in Notification, where: n.type == "puzzlet_withdrawn"))
    assert n.recipient_team_id == team.id
    assert n.sender_team_id == nil
    assert n.metadata["has_next"] == true
    assert n.metadata["pole_id"] == pole.id
    assert n.metadata["puzzlet_id"] == easy.id
  end

  test "has_next is false when the withdrawn puzzlet was the pole's last" do
    pole = insert(:pole)
    only = insert(:puzzlet, pole: pole, status: :validated, difficulty: 1, answer: "Foo")
    working_team(pole)

    {:ok, _} = Landgrab.withdraw_puzzlet(only.id)

    n = Repo.one(from(n in Notification, where: n.type == "puzzlet_withdrawn"))
    assert n.metadata["has_next"] == false
  end

  test "a withdrawn puzzlet is skipped by a pole's active selection" do
    pole = insert(:pole)
    easy = insert(:puzzlet, pole: pole, status: :validated, difficulty: 1, answer: "Foo")
    hard = insert(:puzzlet, pole: pole, status: :validated, difficulty: 2, answer: "Bar")

    {:ok, _} = Landgrab.withdraw_puzzlet(easy.id)

    team = insert(:team)
    user = insert(:user, team_id: team.id)
    {:ok, payload} = Landgrab.scan_payload(pole.barcode, team.id, user.id)
    assert payload.active_puzzlet.id == hard.id
  end

  test "answering a withdrawn puzzlet reports :withdrawn, not :not_active" do
    pole = insert(:pole)
    puzzlet = insert(:puzzlet, pole: pole, status: :validated, answer: "Foo")
    team = insert(:team)
    user = insert(:user, team_id: team.id)
    {:ok, _} = Landgrab.scan_payload(pole.barcode, team.id, user.id)

    {:ok, _} = Landgrab.withdraw_puzzlet(puzzlet.id)

    # The team_puzzlet row is gone, so a naive check would say :not_active;
    # the status guard must win so the player gets a truthful message.
    fresh = Repo.get(Registrations.Landgrab.Puzzlet, puzzlet.id)
    assert {:error, :withdrawn} = Landgrab.record_attempt(fresh, team.id, user.id, "Foo")
  end

  test "withdrawing an already-withdrawn puzzlet errors" do
    pole = insert(:pole)
    p = insert(:puzzlet, pole: pole, status: :validated, answer: "Foo")

    {:ok, _} = Landgrab.withdraw_puzzlet(p.id)
    assert {:error, :already_withdrawn} = Landgrab.withdraw_puzzlet(p.id)
  end
end
