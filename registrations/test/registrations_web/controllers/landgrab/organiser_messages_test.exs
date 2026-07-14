defmodule RegistrationsWeb.Landgrab.OrganiserMessagesTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Accounts
  alias Registrations.Landgrab.Notification
  alias Registrations.Repo

  import Ecto.Query

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

      team_a = insert(:team)
      team_b = insert(:team)
      insert(:user, email: unique_email("a"), team_id: team_a.id)
      insert(:user, email: unique_email("b"), team_id: team_b.id)
      # A memberless team must NOT receive fan-out rows.
      empty_team = insert(:team)

      %{conn: authed_conn(ctx, supervisor), teams: [team_a, team_b], empty_team: empty_team}
    end

    test "creates a draft without sending", %{conn: conn} do
      body =
        conn
        |> post("/landgrab/supervision/messages", %{
          "body" => "The simulation is going well.",
          "sender_name" => "Sabuk's assistant"
        })
        |> json_response(201)

      assert body["sent_at"] == nil
      assert Repo.aggregate(Notification, :count) == 0

      list = conn |> get("/landgrab/supervision/messages") |> json_response(200)
      assert [%{"body" => "The simulation is going well."}] = list["messages"]
    end

    test "create with send: true fans out immediately", %{conn: conn, teams: teams} do
      body =
        conn
        |> post("/landgrab/supervision/messages", %{
          "body" => "Session extended.",
          "sender_name" => "Sabuk",
          "send" => true
        })
        |> json_response(201)

      assert body["sent_at"]
      assert body["team_count"] == 2

      notifications = Repo.all(from(n in Notification, where: n.type == "message"))
      assert length(notifications) == 2
      assert Enum.map(notifications, & &1.recipient_team_id) |> Enum.sort() == Enum.map(teams, & &1.id) |> Enum.sort()
      assert Enum.all?(notifications, &(&1.metadata["sender_name"] == "Sabuk"))
      assert Enum.all?(notifications, &(&1.body == "Session extended."))
    end

    test "sending a draft stamps it and re-sending conflicts", %{conn: conn} do
      created =
        conn
        |> post("/landgrab/supervision/messages", %{"body" => "Prewritten.", "sender_name" => "Sabuk"})
        |> json_response(201)

      sent = conn |> post("/landgrab/supervision/messages/#{created["id"]}/send") |> json_response(200)
      assert sent["sent_at"]
      assert sent["team_count"] == 2

      conflict = conn |> post("/landgrab/supervision/messages/#{created["id"]}/send") |> json_response(409)
      assert conflict["error"]["code"] == "already_sent"

      assert Repo.aggregate(Notification, :count) == 2
    end

    test "rejects an empty body", %{conn: conn} do
      conn
      |> post("/landgrab/supervision/messages", %{"body" => "", "sender_name" => "Sabuk"})
      |> json_response(422)
    end
  end

  test "non-supervisors cannot use the message endpoints", %{conn: _} = ctx do
    player = insert(:user, email: unique_email("player"))
    conn = authed_conn(ctx, player)

    conn |> get("/landgrab/supervision/messages") |> json_response(403)
  end
end
