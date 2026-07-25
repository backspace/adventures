defmodule Registrations.Landgrab.AccountingTest do
  use Registrations.DataCase

  alias Registrations.Landgrab
  alias Registrations.Landgrab.Events
  alias Registrations.Landgrab.Notification
  alias Registrations.Repo

  @at ~U[2026-07-25 21:00:00Z]

  defp member_team do
    team = insert(:team)
    insert(:user, email: "acct#{System.unique_integer([:positive])}@example.com", team_id: team.id)
    team
  end

  defp schedule(attrs) do
    {:ok, _} = Events.update(Events.current(), attrs)
  end

  describe "maybe_send_accounting/1" do
    test "noop before the send time, and with no body" do
      member_team()

      # No schedule at all.
      assert Landgrab.maybe_send_accounting(@at) == :noop

      # Time set but not reached.
      schedule(%{accounting_at: @at, accounting_body: "The reckoning."})
      assert Landgrab.maybe_send_accounting(~U[2026-07-25 20:59:59Z]) == :noop

      # Reached, but the body is blank.
      schedule(%{accounting_at: @at, accounting_body: "   "})
      assert Landgrab.maybe_send_accounting(@at) == :noop

      assert Repo.aggregate(Notification, :count) == 0
    end

    test "sends one Takver message to every team once the time passes, exactly once" do
      a = member_team()
      b = member_team()
      c = member_team()
      # A pre-created team nobody joined must not get it.
      insert(:team)

      schedule(%{accounting_at: @at, accounting_body: "The reckoning is at hand."})

      assert {:sent, 3} = Landgrab.maybe_send_accounting(@at)

      for team <- [a, b, c] do
        notification =
          Repo.one(from(n in Notification, where: n.recipient_team_id == ^team.id))

        assert notification.type == "message"
        assert notification.body == "The reckoning is at hand."
        assert notification.metadata["sender_name"] == "Takver"
      end

      assert Repo.aggregate(Notification, :count) == 3
      assert Repo.reload!(Events.current()).accounting_sent_at != nil

      # One-shot: the stamp survives later polls and later edits to the body.
      schedule(%{accounting_body: "Changed my mind."})
      assert Landgrab.maybe_send_accounting(~U[2026-07-25 21:10:00Z]) == :noop
      assert Repo.aggregate(Notification, :count) == 3
    end
  end

  describe "shift_schedule moves accounting_at" do
    test "a +5 minute push slides the still-future send time" do
      schedule(%{accounting_at: @at})

      {:ok, shifted} =
        Events.shift_schedule(Events.current(), 300, ~U[2026-07-25 20:00:00Z])

      assert shifted.accounting_at == ~U[2026-07-25 21:05:00Z]
    end
  end
end
