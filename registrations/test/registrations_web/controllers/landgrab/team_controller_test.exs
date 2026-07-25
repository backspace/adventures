defmodule RegistrationsWeb.Landgrab.TeamControllerTest do
  @moduledoc """
  The mobile join-by-code endpoint. It sets the caller's team with no
  "already on a team" guard on purpose — Settings lets a player scan another
  team's code to switch last-minute — so these lock both the first-join and the
  switch, plus the case-insensitive code and the unknown-code 404.
  """
  use RegistrationsWeb.ConnCase

  alias Registrations.Repo
  alias RegistrationsWeb.User

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

  test "a teamless user joins a team by code", %{conn: conn} do
    team = insert(:team, name: "Blue Crew", join_code: "JOIN42")
    user = insert(:user)

    body =
      conn
      |> authed_conn(user)
      |> post("/landgrab/team/join", %{"code" => "JOIN42"})
      |> json_response(200)

    assert body["team"]["id"] == team.id
    assert body["team"]["name"] == "Blue Crew"
    assert Repo.get(User, user.id).team_id == team.id
  end

  test "a user already on a team switches to another by code (Settings switch)", %{conn: conn} do
    old = insert(:team, name: "Old", join_code: "OLD001")
    new = insert(:team, name: "New", join_code: "NEW001")
    user = insert(:user, team_id: old.id)

    body =
      conn
      |> authed_conn(user)
      # Lower-case on purpose: the code is normalised (trim + upcase).
      |> post("/landgrab/team/join", %{"code" => "new001"})
      |> json_response(200)

    assert body["team"]["id"] == new.id
    assert Repo.get(User, user.id).team_id == new.id
  end

  test "an unknown code is a 404", %{conn: conn} do
    user = insert(:user, team_id: insert(:team, join_code: "KEEP01").id)

    conn
    |> authed_conn(user)
    |> post("/landgrab/team/join", %{"code" => "NOPE99"})
    |> json_response(404)
  end
end
