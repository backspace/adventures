defmodule RegistrationsWeb.Poles.PolesApiTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Poles

  setup %{conn: conn} do
    team = insert(:team, name: "Wolves")
    user = insert(:octavia, team: team)

    auth_conn = build_conn()

    auth_conn =
      post(auth_conn, Routes.api_session_path(auth_conn, :create), %{
        "user" => %{"email" => user.email, "password" => "Xenogenesis"}
      })

    token = json_response(auth_conn, 200)["data"]["access_token"]

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", token)

    %{conn: conn, user: user, team: team}
  end

  describe "GET /poles/me" do
    test "returns the current user and team", %{conn: conn, user: user, team: team} do
      conn = get(conn, "/poles/me")
      body = json_response(conn, 200)

      assert body["user"]["id"] == user.id
      assert body["user"]["email"] == user.email
      assert body["team"]["id"] == team.id
      assert body["team"]["name"] == "Wolves"
    end
  end

  describe "GET /poles/poles" do
    test "lists all poles with state", %{conn: conn} do
      pole = insert(:pole, label: "Corner")
      _puzzlet = insert(:puzzlet, pole: pole, answer: "alpha", difficulty: 1)

      body = conn |> get("/poles/poles") |> json_response(200)
      [returned] = body["poles"]

      assert returned["id"] == pole.id
      assert returned["barcode"] == pole.barcode
      assert returned["label"] == "Corner"
      assert returned["current_owner_team_id"] == nil
      assert returned["locked"] == false
    end
  end

  describe "GET /poles/poles/:barcode" do
    test "returns the easiest validated puzzlet for an unscanned pole",
         %{conn: conn} do
      pole = insert(:pole)
      _hard = insert(:puzzlet, pole: pole, answer: "z", difficulty: 9, instructions: "hard")
      easy = insert(:puzzlet, pole: pole, answer: "a", difficulty: 1, instructions: "easy")

      body = conn |> get("/poles/poles/#{pole.barcode}") |> json_response(200)

      assert body["pole"]["id"] == pole.id
      assert body["active_puzzlet"]["id"] == easy.id
      assert body["active_puzzlet"]["instructions"] == "easy"
      assert body["active_puzzlet"]["attempts_remaining"] == Poles.max_attempts_per_puzzlet()
    end

    test "returns nil active_puzzlet when pole is locked", %{conn: conn, team: team} do
      pole = insert(:pole)
      puzzlet = insert(:puzzlet, pole: pole, answer: "a")
      insert(:capture, puzzlet: puzzlet, team: team)

      body = conn |> get("/poles/poles/#{pole.barcode}") |> json_response(200)
      assert body["pole"]["locked"] == true
      assert body["pole"]["current_owner_team_id"] == team.id
      assert body["active_puzzlet"] == nil
    end

    test "returns 404 for unknown barcode", %{conn: conn} do
      body = conn |> get("/poles/poles/NOPE") |> json_response(404)
      assert body["error"]["code"] == "pole_not_found"
    end
  end

  describe "POST /poles/puzzlets/:puzzlet_id/attempts" do
    test "wrong answer returns attempts_remaining", %{conn: conn} do
      pole = insert(:pole)
      puzzlet = insert(:puzzlet, pole: pole, answer: "right")

      body =
        conn
        |> post("/poles/puzzlets/#{puzzlet.id}/attempts", %{"answer" => "wrong"})
        |> json_response(200)

      assert body["correct"] == false
      assert body["attempts_remaining"] == Poles.max_attempts_per_puzzlet() - 1
    end

    test "correct answer captures the pole", %{conn: conn, team: team} do
      pole = insert(:pole)
      puzzlet = insert(:puzzlet, pole: pole, answer: " Right ")

      body =
        conn
        |> post("/poles/puzzlets/#{puzzlet.id}/attempts", %{"answer" => "RIGHT"})
        |> json_response(200)

      assert body["correct"] == true
      assert body["captured"] == true
      assert body["pole"]["current_owner_team_id"] == team.id
      assert body["capture"]["puzzlet_id"] == puzzlet.id
    end

    test "fourth attempt returns 423 locked_out", %{conn: conn, user: user, team: team} do
      pole = insert(:pole)
      puzzlet = insert(:puzzlet, pole: pole, answer: "right")

      Enum.each(1..3, fn _ ->
        Poles.record_attempt(puzzlet, team.id, user.id, "wrong")
      end)

      body =
        conn
        |> post("/poles/puzzlets/#{puzzlet.id}/attempts", %{"answer" => "right"})
        |> json_response(423)

      assert body["error"]["code"] == "locked_out"
    end

    test "second team gets 409 if puzzlet already captured", %{conn: conn} do
      pole = insert(:pole)
      puzzlet = insert(:puzzlet, pole: pole, answer: "right")
      other_team = insert(:team)
      insert(:capture, puzzlet: puzzlet, team: other_team)

      body =
        conn
        |> post("/poles/puzzlets/#{puzzlet.id}/attempts", %{"answer" => "right"})
        |> json_response(409)

      assert body["error"]["code"] == "already_captured"
    end
  end

  describe "auth" do
    test "rejects unauthenticated requests" do
      conn = build_conn() |> put_req_header("accept", "application/json")
      conn = get(conn, "/poles/me")
      assert response(conn, 401)
    end
  end
end
