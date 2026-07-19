defmodule RegistrationsWeb.Landgrab.PolesApiTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Landgrab

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
      conn = get(conn, "/landgrab/me")
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

      body = conn |> get("/landgrab/poles") |> json_response(200)
      [returned] = body["poles"]

      assert returned["id"] == pole.id
      # The scannable barcode must never be exposed to players — knowing it
      # would let someone claim a stake without being there.
      refute Map.has_key?(returned, "barcode")
      # A labelled stake surfaces its label as its display name.
      assert returned["name"] == "Corner"
      assert returned["current_owner_team_id"] == nil
      assert returned["locked"] == false
    end

    test "an unlabelled stake gets a generated name, not its barcode", %{conn: conn} do
      pole = insert(:pole, label: nil)
      _puzzlet = insert(:puzzlet, pole: pole, answer: "alpha", difficulty: 1)

      body = conn |> get("/landgrab/poles") |> json_response(200)
      [returned] = body["poles"]

      refute Map.has_key?(returned, "barcode")
      assert is_binary(returned["name"])
      assert returned["name"] != pole.barcode
      # Stable adjective-noun-number handle, with a 3-digit number.
      assert returned["name"] =~ ~r/^[a-z]+-[a-z]+-\d{3}$/
    end

    test "generated stake names are unique across stakes", %{conn: conn} do
      for _ <- 1..25, do: insert(:pole, label: nil)

      names =
        conn
        |> get("/landgrab/poles")
        |> json_response(200)
        |> Map.fetch!("poles")
        |> Enum.map(& &1["name"])

      assert length(names) == 25
      assert length(Enum.uniq(names)) == 25
    end
  end

  describe "GET /poles/poles/:barcode" do
    test "returns the easiest validated puzzlet for an unscanned pole",
         %{conn: conn} do
      pole = insert(:pole)
      _hard = insert(:puzzlet, pole: pole, answer: "z", difficulty: 9, instructions: "hard")
      easy = insert(:puzzlet, pole: pole, answer: "a", difficulty: 1, instructions: "easy")

      body = conn |> get("/landgrab/poles/#{pole.barcode}") |> json_response(200)

      assert body["pole"]["id"] == pole.id
      assert body["active_puzzlet"]["id"] == easy.id
      assert body["active_puzzlet"]["instructions"] == "easy"
      assert body["active_puzzlet"]["attempts_remaining"] == Landgrab.max_attempts_per_puzzlet()
    end

    test "active_puzzlet region carries the description/notes up the hierarchy",
         %{conn: conn} do
      parent =
        insert(:poles_region,
          name: "777 Main St",
          entry_instructions: "Buzz suite 100 at the front door"
        )

      child =
        insert(:poles_region,
          name: "4th floor",
          parent_region: parent,
          accessibility_notes: "Elevator is at the east end"
        )

      pole = insert(:pole)
      insert(:puzzlet, pole: pole, answer: "a", difficulty: 1, region: child)

      body = conn |> get("/landgrab/poles/#{pole.barcode}") |> json_response(200)
      region = body["active_puzzlet"]["region"]

      assert region["name"] == "4th floor"
      assert region["breadcrumb"] == "777 Main St > 4th floor"
      # Ordered root -> self; empty rows (none here) dropped.
      assert [top, leaf] = region["stanzas"]
      assert top["source"] == "777 Main St"
      assert top["entry_instructions"] == "Buzz suite 100 at the front door"
      assert leaf["source"] == "4th floor"
      assert leaf["notes"] == "Elevator is at the east end"
    end

    test "active_puzzlet region is null when the puzzlet has no region",
         %{conn: conn} do
      pole = insert(:pole)
      insert(:puzzlet, pole: pole, answer: "a", difficulty: 1)

      body = conn |> get("/landgrab/poles/#{pole.barcode}") |> json_response(200)
      assert body["active_puzzlet"]["region"] == nil
    end

    test "returns nil active_puzzlet when pole is locked", %{conn: conn, team: team} do
      pole = insert(:pole)
      puzzlet = insert(:puzzlet, pole: pole, answer: "a")
      insert(:capture, puzzlet: puzzlet, team: team)

      body = conn |> get("/landgrab/poles/#{pole.barcode}") |> json_response(200)
      assert body["pole"]["locked"] == true
      assert body["pole"]["current_owner_team_id"] == team.id
      assert body["active_puzzlet"] == nil
    end

    test "returns 404 for unknown barcode", %{conn: conn} do
      body = conn |> get("/landgrab/poles/NOPE") |> json_response(404)
      assert body["error"]["code"] == "pole_not_found"
    end

    test "returns 409 when this team is the current owner", %{conn: conn, team: team} do
      pole = insert(:pole)
      puzzlet = insert(:puzzlet, pole: pole, answer: "a", difficulty: 1)
      _other = insert(:puzzlet, pole: pole, answer: "b", difficulty: 5)
      insert(:capture, puzzlet: puzzlet, team: team)

      body = conn |> get("/landgrab/poles/#{pole.barcode}") |> json_response(409)
      assert body["error"]["code"] == "already_owner"
      assert body["pole"]["id"] == pole.id
    end

    test "returns 423 when this team has used all guesses on the active puzzlet",
         %{conn: conn, user: user, team: team} do
      pole = insert(:pole)
      puzzlet = insert(:puzzlet, pole: pole, answer: "right", difficulty: 1)
      insert(:team_puzzlet, team: team, puzzlet: puzzlet, pole: pole)

      Enum.each(1..3, fn _ ->
        Landgrab.record_attempt(puzzlet, team.id, user.id, "wrong")
      end)

      body = conn |> get("/landgrab/poles/#{pole.barcode}") |> json_response(423)
      assert body["error"]["code"] == "team_locked_out"
      assert body["pole"]["id"] == pole.id
    end
  end

  describe "POST /poles/puzzlets/:puzzlet_id/attempts" do
    test "wrong answer returns attempts_remaining", %{conn: conn, team: team} do
      pole = insert(:pole)
      puzzlet = insert(:puzzlet, pole: pole, answer: "right")
      insert(:team_puzzlet, team: team, puzzlet: puzzlet, pole: pole)

      body =
        conn
        |> post("/landgrab/puzzlets/#{puzzlet.id}/attempts", %{"answer" => "wrong"})
        |> json_response(200)

      assert body["correct"] == false
      assert body["attempts_remaining"] == Landgrab.max_attempts_per_puzzlet() - 1
      assert body["previous_wrong_answers"] == ["wrong"]
    end

    test "previous_wrong_answers accumulates across attempts",
         %{conn: conn, team: team} do
      pole = insert(:pole)
      puzzlet = insert(:puzzlet, pole: pole, answer: "right")
      insert(:team_puzzlet, team: team, puzzlet: puzzlet, pole: pole)

      post(conn, "/landgrab/puzzlets/#{puzzlet.id}/attempts", %{"answer" => "first"})
      post(conn, "/landgrab/puzzlets/#{puzzlet.id}/attempts", %{"answer" => "first"})

      body =
        conn
        |> post("/landgrab/puzzlets/#{puzzlet.id}/attempts", %{"answer" => "second"})
        |> json_response(200)

      assert body["previous_wrong_answers"] == ["first", "second"]
    end

    test "correct answer captures the pole", %{conn: conn, team: team} do
      pole = insert(:pole)
      puzzlet = insert(:puzzlet, pole: pole, answer: " Right ")
      insert(:team_puzzlet, team: team, puzzlet: puzzlet, pole: pole)

      body =
        conn
        |> post("/landgrab/puzzlets/#{puzzlet.id}/attempts", %{"answer" => "RIGHT"})
        |> json_response(200)

      assert body["correct"] == true
      assert body["captured"] == true
      assert body["pole"]["current_owner_team_id"] == team.id
      assert body["capture"]["puzzlet_id"] == puzzlet.id
    end

    test "fourth attempt returns 423 locked_out", %{conn: conn, user: user, team: team} do
      pole = insert(:pole)
      puzzlet = insert(:puzzlet, pole: pole, answer: "right")
      insert(:team_puzzlet, team: team, puzzlet: puzzlet, pole: pole)

      Enum.each(1..3, fn _ ->
        Landgrab.record_attempt(puzzlet, team.id, user.id, "wrong")
      end)

      body =
        conn
        |> post("/landgrab/puzzlets/#{puzzlet.id}/attempts", %{"answer" => "right"})
        |> json_response(423)

      assert body["error"]["code"] == "locked_out"
    end

    test "rejects 409 when this team already owns the pole", %{conn: conn, team: team} do
      pole = insert(:pole)
      easy = insert(:puzzlet, pole: pole, answer: "a", difficulty: 1)
      hard = insert(:puzzlet, pole: pole, answer: "b", difficulty: 5)
      insert(:capture, puzzlet: easy, team: team)

      body =
        conn
        |> post("/landgrab/puzzlets/#{hard.id}/attempts", %{"answer" => "b"})
        |> json_response(409)

      assert body["error"]["code"] == "already_owner"
    end

    test "second team gets 409 if puzzlet already captured",
         %{conn: conn, team: team} do
      pole = insert(:pole)
      puzzlet = insert(:puzzlet, pole: pole, answer: "right")
      insert(:team_puzzlet, team: team, puzzlet: puzzlet, pole: pole)
      other_team = insert(:team)
      insert(:capture, puzzlet: puzzlet, team: other_team)

      body =
        conn
        |> post("/landgrab/puzzlets/#{puzzlet.id}/attempts", %{"answer" => "right"})
        |> json_response(409)

      assert body["error"]["code"] == "already_captured"
    end

    test "rejects 409 not_active when the team never started the puzzlet",
         %{conn: conn} do
      pole = insert(:pole)
      puzzlet = insert(:puzzlet, pole: pole, answer: "right")
      # No team_puzzlet row: the team never scanned to claim this puzzlet.

      body =
        conn
        |> post("/landgrab/puzzlets/#{puzzlet.id}/attempts", %{"answer" => "right"})
        |> json_response(409)

      assert body["error"]["code"] == "not_active"
      # And it didn't sneak through a capture.
      assert Registrations.Repo.aggregate(Registrations.Landgrab.Capture, :count) == 0
    end
  end

  describe "auth" do
    test "rejects unauthenticated requests" do
      conn = put_req_header(build_conn(), "accept", "application/json")
      conn = get(conn, "/landgrab/me")
      assert response(conn, 401)
    end
  end

  describe "creator restrictions" do
    test "scan returns own_creation when user is the pole creator",
         %{conn: conn, user: user} do
      pole = insert(:pole, creator: user)
      _puzzlet = insert(:puzzlet, pole: pole, answer: "x")

      body = conn |> get("/landgrab/poles/#{pole.barcode}") |> json_response(409)
      assert body["error"]["code"] == "own_creation"
    end

    test "scan skips puzzlets the user authored", %{conn: conn, user: user} do
      pole = insert(:pole)
      _theirs = insert(:puzzlet, pole: pole, answer: "x", difficulty: 1, creator: user)
      ok = insert(:puzzlet, pole: pole, answer: "y", difficulty: 5)

      body = conn |> get("/landgrab/poles/#{pole.barcode}") |> json_response(200)
      assert body["active_puzzlet"]["id"] == ok.id
    end

    test "attempt is rejected on a puzzlet the user authored",
         %{conn: conn, user: user, team: team} do
      pole = insert(:pole)
      mine = insert(:puzzlet, pole: pole, answer: "x", creator: user)

      body =
        conn
        |> post("/landgrab/puzzlets/#{mine.id}/attempts", %{"answer" => "x"})
        |> json_response(409)

      assert body["error"]["code"] == "own_creation"
      _ = team
    end

    test "attempt is rejected on a puzzlet whose pole the user authored",
         %{conn: conn, user: user} do
      pole = insert(:pole, creator: user)
      other = insert(:puzzlet, pole: pole, answer: "x")

      body =
        conn
        |> post("/landgrab/puzzlets/#{other.id}/attempts", %{"answer" => "x"})
        |> json_response(409)

      assert body["error"]["code"] == "own_creation"
    end
  end

  describe "user without a team" do
    test "can still scan a pole without crashing", %{conn: _conn} do
      teamless = insert(:octavia, email: "noteam@example.com", team: nil)

      auth_conn =
        post(build_conn(), Routes.api_session_path(build_conn(), :create), %{
          "user" => %{"email" => teamless.email, "password" => "Xenogenesis"}
        })

      token = json_response(auth_conn, 200)["data"]["access_token"]

      teamless_conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("content-type", "application/json")
        |> put_req_header("authorization", token)

      pole = insert(:pole)
      _puzzlet = insert(:puzzlet, pole: pole, answer: "x")

      body = teamless_conn |> get("/landgrab/poles/#{pole.barcode}") |> json_response(200)
      assert body["pole"]["id"] == pole.id
      assert body["active_puzzlet"]["attempts_remaining"] == Landgrab.max_attempts_per_puzzlet()
    end

    test "is rejected when attempting an answer", %{conn: _conn} do
      teamless = insert(:octavia, email: "noteam2@example.com", team: nil)

      auth_conn =
        post(build_conn(), Routes.api_session_path(build_conn(), :create), %{
          "user" => %{"email" => teamless.email, "password" => "Xenogenesis"}
        })

      token = json_response(auth_conn, 200)["data"]["access_token"]

      teamless_conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("content-type", "application/json")
        |> put_req_header("authorization", token)

      pole = insert(:pole)
      puzzlet = insert(:puzzlet, pole: pole, answer: "x")

      body =
        teamless_conn
        |> post("/landgrab/puzzlets/#{puzzlet.id}/attempts", %{"answer" => "x"})
        |> json_response(403)

      assert body["error"]["code"] == "no_team"
    end
  end
end
