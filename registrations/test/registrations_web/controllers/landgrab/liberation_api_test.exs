defmodule RegistrationsWeb.Landgrab.LiberationApiTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Accounts

  defp authed_conn(%{conn: conn}, %{} = user) do
    auth_conn =
      post(build_conn(), Routes.api_session_path(build_conn(), :create), %{
        "user" => %{"email" => user.email, "password" => "Xenogenesis"}
      })

    token = json_response(auth_conn, 200)["data"]["access_token"]

    conn
    |> put_req_header("accept", "application/json")
    |> put_req_header("content-type", "application/json")
    |> put_req_header("authorization", token)
  end

  defp unique_email(prefix), do: "#{prefix}#{System.unique_integer([:positive])}@example.com"

  describe "as a supervisor" do
    setup ctx do
      supervisor = insert(:user, email: unique_email("super"))
      Accounts.assign_role(supervisor.id, "validation_supervisor")
      %{conn: authed_conn(ctx, supervisor)}
    end

    test "round-trips the rollout window and reports progress", %{conn: conn} do
      # A member team so the counts have something to count. (The supervisor
      # user is teamless, so it doesn't appear.)
      team = insert(:team)
      insert(:user, email: unique_email("member"), team_id: team.id)

      initial = conn |> get("/landgrab/supervision/liberation") |> json_response(200)
      assert initial["starts_at"] == nil
      assert initial["team_count"] == 1
      assert initial["invited"] == 0

      updated =
        conn
        |> put("/landgrab/supervision/liberation", %{
          "starts_at" => "2026-07-25T21:00:00Z",
          "rollout_ends_at" => "2026-07-25T21:30:00Z"
        })
        |> json_response(200)

      assert updated["starts_at"] == "2026-07-25T21:00:00Z"
      assert updated["rollout_ends_at"] == "2026-07-25T21:30:00Z"

      cleared =
        conn
        |> put("/landgrab/supervision/liberation", %{})
        |> json_response(200)

      assert cleared["starts_at"] == nil
    end

    test "round-trips Bedab's accounting message (time + body)", %{conn: conn} do
      initial = conn |> get("/landgrab/supervision/liberation") |> json_response(200)
      assert initial["accounting_at"] == nil
      assert initial["accounting_body"] == nil
      assert initial["accounting_sent_at"] == nil

      updated =
        conn
        |> put("/landgrab/supervision/liberation", %{
          "accounting_at" => "2026-07-25T21:00:00Z",
          "accounting_body" => "The reckoning is at hand."
        })
        |> json_response(200)

      assert updated["accounting_at"] == "2026-07-25T21:00:00Z"
      assert updated["accounting_body"] == "The reckoning is at hand."
      # Not sent yet — the UI keys its editable/locked state off this.
      assert updated["accounting_sent_at"] == nil
    end

    test "reports each member team's stage and members for the breakdown", %{conn: conn} do
      accepted =
        insert(:team,
          name: "Alpha",
          liberation_invited_at: ~U[2026-07-25 21:00:00Z],
          liberation_response: "accepted"
        )

      insert(:user, email: "acc-a@example.com", name: "Ada", team_id: accepted.id)

      invited = insert(:team, name: "Bravo", liberation_invited_at: ~U[2026-07-25 21:00:00Z])
      insert(:user, email: "inv-b@example.com", team_id: invited.id)

      uninvited = insert(:team, name: "Charlie")
      insert(:user, email: "un-c@example.com", team_id: uninvited.id)

      # A memberless team must not appear (empty QR teams aren't in the game).
      insert(:team, name: "Empty")

      body = conn |> get("/landgrab/supervision/liberation") |> json_response(200)

      assert body["team_count"] == 3
      teams = body["teams"]
      assert length(teams) == 3
      by_name = Map.new(teams, &{&1["name"], &1})

      assert by_name["Alpha"]["status"] == "accepted"
      assert by_name["Bravo"]["status"] == "invited"
      assert by_name["Charlie"]["status"] == "uninvited"
      refute Map.has_key?(by_name, "Empty")

      # Members carry through so a team chip can reveal who's on it.
      assert [%{"email" => "acc-a@example.com", "name" => "Ada"}] = by_name["Alpha"]["members"]
    end

    test "adds a declined team to the subversion via the override", %{conn: conn} do
      declined =
        insert(:team,
          name: "Delta",
          liberation_invited_at: ~U[2026-07-25 21:00:00Z],
          liberation_response: "declined"
        )

      insert(:user, email: "d@example.com", team_id: declined.id)

      body =
        conn
        |> post("/landgrab/supervision/liberation/teams/#{declined.id}/join")
        |> json_response(200)

      # The refreshed status shows the team as accepted now.
      team = Enum.find(body["teams"], &(&1["id"] == declined.id))
      assert team["status"] == "accepted"
      assert body["accepted"] == 1
      assert body["declined"] == 0

      # The team gets a passive-voice notification that they're now in.
      note =
        Registrations.Repo.get_by(Registrations.Landgrab.Notification,
          recipient_team_id: declined.id,
          type: "liberation_joined"
        )

      assert note
      assert note.body =~ "coalition"
      refute note.body =~ ~r/organiser/i
    end

    test "join override 404s for an unknown team", %{conn: conn} do
      conn
      |> post("/landgrab/supervision/liberation/teams/#{Ecto.UUID.generate()}/join")
      |> json_response(404)
    end

    test "rejects a rollout end at or before the start", %{conn: conn} do
      body =
        conn
        |> put("/landgrab/supervision/liberation", %{
          "starts_at" => "2026-07-25T21:00:00Z",
          "rollout_ends_at" => "2026-07-25T21:00:00Z"
        })
        |> json_response(422)

      assert body["errors"]["liberation_rollout_ends_at"]
    end
  end

  test "non-supervisors are forbidden", ctx do
    player = insert(:user, email: unique_email("player"))
    conn = authed_conn(ctx, player)

    conn |> get("/landgrab/supervision/liberation") |> json_response(403)

    conn
    |> put("/landgrab/supervision/liberation", %{"starts_at" => "2026-07-25T21:00:00Z"})
    |> json_response(403)
  end
end
