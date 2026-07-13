defmodule RegistrationsWeb.Plugs.ReloadUserTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Repo
  alias RegistrationsWeb.User

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

  test "identity changes after sign-in are seen, not the cached snapshot", ctx do
    # The Pow API token store caches the user struct at sign-in.
    # This user signs in WITH a team, then loses it (as a rehearsal
    # database copy or team rebuild would do). The attempt endpoint
    # must see the current teamless state and return the clean 403 —
    # with the stale cache it passed the team check and 500ed on the
    # attempts FK instead.
    team = insert(:team)
    user = insert(:user, email: unique_email("stale"), team_id: team.id)
    conn = authed_conn(ctx, user)

    Repo.update_all(Ecto.Query.where(User, id: ^user.id), set: [team_id: nil])

    body =
      conn
      |> post("/landgrab/puzzlets/00000000-0000-0000-0000-000000000000/attempts", %{"answer" => "x"})
      |> json_response(403)

    assert body["error"]["code"] == "no_team"
  end

  test "a user deleted after sign-in becomes 401, not a crash", ctx do
    user = insert(:user, email: unique_email("gone"))
    conn = authed_conn(ctx, user)

    Repo.delete!(%User{id: user.id})

    conn
    |> get("/landgrab/poles")
    |> json_response(401)
  end
end
