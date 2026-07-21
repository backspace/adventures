defmodule Registrations.Landgrab.LiberationTest do
  use Registrations.DataCase, async: true

  import Registrations.Factory

  alias Registrations.Landgrab
  alias Registrations.Landgrab.Events
  alias Registrations.Landgrab.Notification
  alias RegistrationsWeb.Team

  @now ~U[2026-07-25 20:00:00Z]

  defp configure_liberation(starts_at, rollout_ends_at \\ nil) do
    {:ok, _} =
      Events.update(Events.current(), %{
        liberation_starts_at: starts_at,
        liberation_rollout_ends_at: rollout_ends_at
      })
  end

  defp member_team do
    team = insert(:team)
    insert(:user, team_id: team.id)
    team
  end

  defp invites, do: Repo.all(from(n in Notification, where: n.type == "liberation_invite"))

  describe "maybe_invite_liberation_teams/1" do
    test "noop when no liberation is scheduled" do
      member_team()
      assert Landgrab.maybe_invite_liberation_teams(@now) == :noop
      assert invites() == []
    end

    test "noop before the start time" do
      member_team()
      configure_liberation(DateTime.add(@now, 600, :second))
      assert Landgrab.maybe_invite_liberation_teams(@now) == :noop
    end

    test "with no rollout window, every member team is invited at the start" do
      t1 = member_team()
      t2 = member_team()
      # A pre-created QR team nobody joined must not be invited.
      _empty = insert(:team)

      configure_liberation(@now)
      assert {:invited, 2} = Landgrab.maybe_invite_liberation_teams(@now)

      notes = invites()
      assert length(notes) == 2
      assert Enum.map(notes, & &1.recipient_team_id) |> Enum.sort() == Enum.sort([t1.id, t2.id])

      # The invitation is signed Bedab — the name reveal.
      assert Enum.all?(notes, &(&1.metadata["sender_name"] == "Bedab"))

      # Teams are stamped so they're never re-invited.
      assert Repo.get(Team, t1.id).liberation_invited_at
      assert Repo.get(Team, t2.id).liberation_invited_at
    end

    test "invitations are idempotent — a second poll invites nobody again" do
      member_team()
      configure_liberation(@now)
      assert {:invited, 1} = Landgrab.maybe_invite_liberation_teams(@now)
      assert :noop = Landgrab.maybe_invite_liberation_teams(@now)
      assert length(invites()) == 1
    end

    test "with a rollout window, the trickle spreads teams across it" do
      for _ <- 1..4, do: member_team()
      configure_liberation(@now, DateTime.add(@now, 3600, :second))

      # Slots for 4 teams over 3600s land at 0s, 900s, 1800s, 2700s.
      # At the start, only slot 0 is due.
      assert {:invited, 1} = Landgrab.maybe_invite_liberation_teams(@now)

      # At +1000s, slot 900 has passed — one new invitation.
      assert {:invited, 1} =
               Landgrab.maybe_invite_liberation_teams(DateTime.add(@now, 1000, :second))

      # Well past the window, everyone remaining gets theirs.
      assert {:invited, 2} =
               Landgrab.maybe_invite_liberation_teams(DateTime.add(@now, 7200, :second))

      assert length(invites()) == 4
    end
  end

  describe "respond_to_liberation_invite/3" do
    setup do
      team = member_team()
      configure_liberation(@now)
      {:invited, 1} = Landgrab.maybe_invite_liberation_teams(@now)
      [invite] = invites()
      %{team: team, invite: invite}
    end

    test "records the answer on the team and the notification", %{team: team, invite: invite} do
      assert {:ok, "accepted"} =
               Landgrab.respond_to_liberation_invite(team.id, invite.id, "accepted")

      assert Repo.get(Team, team.id).liberation_response == "accepted"
      updated = Repo.get(Notification, invite.id)
      assert updated.response == "accepted"
      assert updated.responded_at
    end

    test "the first answer is binding", %{team: team, invite: invite} do
      {:ok, _} = Landgrab.respond_to_liberation_invite(team.id, invite.id, "declined")

      assert {:error, :already_responded, "declined"} =
               Landgrab.respond_to_liberation_invite(team.id, invite.id, "accepted")

      assert Repo.get(Team, team.id).liberation_response == "declined"
    end

    test "rejects an unknown response value", %{team: team, invite: invite} do
      assert {:error, :invalid_response} =
               Landgrab.respond_to_liberation_invite(team.id, invite.id, "maybe")
    end

    test "another team can't answer your invitation", %{invite: invite} do
      interloper = member_team()

      assert {:error, :not_found} =
               Landgrab.respond_to_liberation_invite(interloper.id, invite.id, "accepted")
    end

    test "only liberation invites are answerable", %{team: team} do
      other =
        Repo.insert!(%Notification{
          type: "attack",
          recipient_team_id: team.id,
          body: "x"
        })

      assert {:error, :not_found} =
               Landgrab.respond_to_liberation_invite(team.id, other.id, "accepted")
    end
  end
end
