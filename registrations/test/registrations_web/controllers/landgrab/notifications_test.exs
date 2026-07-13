defmodule RegistrationsWeb.Landgrab.NotificationsTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Landgrab.Notification
  alias Registrations.Repo

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

  defp insert_notification(team_id, attrs \\ %{}) do
    %Notification{}
    |> Notification.changeset(
      Map.merge(
        %{type: "attack", recipient_team_id: team_id, body: "A rival team scanned 001", metadata: %{}},
        attrs
      )
    )
    |> Repo.insert!()
  end

  describe "with a team" do
    setup ctx do
      team = insert(:team)
      other_team = insert(:team)
      user = insert(:user, email: unique_email("notif"), team_id: team.id)
      %{conn: authed_conn(ctx, user), team: team, other_team: other_team}
    end

    test "lists own team's notifications newest-first with an unread count", %{
      conn: conn,
      team: team,
      other_team: other_team
    } do
      older = insert_notification(team.id)

      # Backdate so ordering doesn't depend on same-second insert order.
      Repo.update_all(Ecto.Query.where(Notification, id: ^older.id),
        set: [inserted_at: NaiveDateTime.add(older.inserted_at, -60, :second)]
      )

      newer = insert_notification(team.id, %{type: "pole_lost", body: "They captured 001 from you"})
      _elsewhere = insert_notification(other_team.id)

      body = conn |> get("/landgrab/notifications") |> json_response(200)

      assert Enum.map(body["notifications"], & &1["id"]) == [newer.id, older.id]
      assert body["unread"] == 2
      assert [%{"type" => "pole_lost", "body" => "They captured 001 from you"} | _] = body["notifications"]
    end

    test "mark_read clears the unread count without deleting history", %{conn: conn, team: team} do
      insert_notification(team.id)
      insert_notification(team.id)

      assert %{"marked" => 2} = conn |> post("/landgrab/notifications/read") |> json_response(200)

      body = conn |> get("/landgrab/notifications") |> json_response(200)
      assert body["unread"] == 0
      assert length(body["notifications"]) == 2
      assert Enum.all?(body["notifications"], & &1["read_at"])
    end
  end

  test "a teamless user gets an empty history", %{conn: conn} = ctx do
    _ = conn
    user = insert(:user, email: unique_email("solo"))
    conn = authed_conn(ctx, user)

    assert %{"notifications" => [], "unread" => 0} =
             conn |> get("/landgrab/notifications") |> json_response(200)

    assert %{"marked" => 0} = conn |> post("/landgrab/notifications/read") |> json_response(200)
  end
end
