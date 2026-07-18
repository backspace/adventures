defmodule RegistrationsWeb.Landgrab.ActivePuzzletsTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Landgrab

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

  describe "on a team" do
    setup ctx do
      team = insert(:team)
      user = insert(:user, email: unique_email("ap"), team_id: team.id)
      %{conn: authed_conn(ctx, user), team: team, user: user}
    end

    test "index resumes the team's active puzzlet after a scan", %{conn: conn, team: team, user: user} do
      p = insert(:pole)
      insert(:puzzlet, pole: p, status: :validated, difficulty: 1, answer: "Foo")
      Landgrab.scan_payload(p.barcode, team.id, user.id)

      body = conn |> get("/landgrab/active-puzzlets") |> json_response(200)
      assert [entry] = body["active_puzzlets"]
      assert entry["active_puzzlet"]["id"]
      assert entry["pole"]["id"] == p.id
    end

    test "scanning a second pole at capacity returns 409 at_capacity", %{conn: conn, team: team, user: user} do
      p1 = insert(:pole)
      insert(:puzzlet, pole: p1, status: :validated, difficulty: 1, answer: "Foo")
      p2 = insert(:pole)
      insert(:puzzlet, pole: p2, status: :validated, difficulty: 1, answer: "Bar")
      Landgrab.scan_payload(p1.barcode, team.id, user.id)

      body = conn |> get("/landgrab/poles/#{p2.barcode}") |> json_response(409)
      assert body["error"]["code"] == "at_capacity"
      assert [_] = body["active_puzzlets"]
    end

    test "create assigns the next puzzlet for a pole (try the next one)", %{conn: conn, team: team, user: user} do
      p = insert(:pole)
      easy = insert(:puzzlet, pole: p, status: :validated, difficulty: 1, answer: "Foo")
      insert(:puzzlet, pole: p, status: :validated, difficulty: 2, answer: "Bar")

      other = insert(:team)
      other_user = insert(:user, email: unique_email("rival"))
      other_user |> Ecto.Changeset.change(team_id: other.id) |> Registrations.Repo.update!()

      # Rival scans then captures the easy one — answering requires an
      # active row now.
      Landgrab.scan_payload(p.barcode, other.id, other_user.id)
      Landgrab.record_attempt(
        Registrations.Repo.get(Registrations.Landgrab.Puzzlet, easy.id),
        other.id,
        other_user.id,
        "Foo"
      )

      body = conn |> post("/landgrab/active-puzzlets", %{"pole_id" => p.id}) |> json_response(201)
      assert body["active_puzzlet"]["difficulty"] == 2
    end

    test "delete gives up the active puzzlet", %{conn: conn, team: team, user: user} do
      p = insert(:pole)
      pz = insert(:puzzlet, pole: p, status: :validated, difficulty: 1, answer: "Foo")
      Landgrab.scan_payload(p.barcode, team.id, user.id)

      assert %{"ok" => true} = conn |> delete("/landgrab/active-puzzlets/#{pz.id}") |> json_response(200)
      assert Landgrab.list_active_puzzlets_for_team(team.id) == []
    end
  end

  test "teamless user gets an empty list", %{conn: conn} = ctx do
    user = insert(:user, email: unique_email("solo"))
    conn = authed_conn(ctx, user)
    assert %{"active_puzzlets" => []} = conn |> get("/landgrab/active-puzzlets") |> json_response(200)
  end
end
