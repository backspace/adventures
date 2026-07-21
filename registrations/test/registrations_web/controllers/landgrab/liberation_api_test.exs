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
