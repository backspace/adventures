defmodule RegistrationsWeb.Landgrab.MeControllerTest do
  @moduledoc """
  /me is the app's identity snapshot. It carries the team's `join_code` so a
  member can render an invite QR from Settings; these lock that contract (the
  app reads `team.join_code`) and the teamless shape.
  """
  use RegistrationsWeb.ConnCase

  defp authed_conn(conn, user) do
    auth =
      post(build_conn(), Routes.api_session_path(build_conn(), :create), %{
        "user" => %{"email" => user.email, "password" => "Xenogenesis"}
      })

    token = json_response(auth, 200)["data"]["access_token"]

    conn
    |> put_req_header("accept", "application/json")
    |> put_req_header("authorization", token)
  end

  test "exposes the team's join code (for the invite QR)", %{conn: conn} do
    team = insert(:team, name: "Blue Crew", join_code: "JOIN42")
    user = insert(:user, team_id: team.id)

    body = conn |> authed_conn(user) |> get("/landgrab/me") |> json_response(200)

    assert body["team"]["name"] == "Blue Crew"
    assert body["team"]["join_code"] == "JOIN42"
  end

  test "returns a nil team for a teamless user", %{conn: conn} do
    user = insert(:user)

    body = conn |> authed_conn(user) |> get("/landgrab/me") |> json_response(200)

    assert body["team"] == nil
  end
end
