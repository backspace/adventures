defmodule RegistrationsWeb.Landgrab.DraftsTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Accounts
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

  describe "without the author role" do
    setup ctx do
      user = insert(:user, email: "noauth#{System.unique_integer([:positive])}@example.com")
      %{conn: authed_conn(ctx, user), user: user}
    end

    test "POST /poles/drafts/poles is forbidden", %{conn: conn} do
      body =
        conn
        |> post("/landgrab/drafts/poles", %{
          "barcode" => "AUTHOR-1",
          "latitude" => 49.89,
          "longitude" => -97.13
        })
        |> json_response(403)

      assert body["error"]["code"] == "forbidden"
    end
  end

  describe "with the author role" do
    setup ctx do
      user = insert(:user, email: "author#{System.unique_integer([:positive])}@example.com")
      Accounts.assign_role(user.id, "author")
      %{conn: authed_conn(ctx, user), user: user}
    end

    test "creates a draft pole", %{conn: conn, user: user} do
      body =
        conn
        |> post("/landgrab/drafts/poles", %{
          "barcode" => "AUTHORED-#{System.unique_integer([:positive])}",
          "latitude" => 49.89,
          "longitude" => -97.13,
          "label" => "Test pole",
          "notes" => "by the bus stop",
          "accuracy_m" => 7.4,
          "manual_offset_m" => 42.0
        })
        |> json_response(201)

      assert body["status"] == "draft"
      assert body["creator_id"] == user.id
      assert body["accuracy_m"] == 7.4
      assert body["manual_offset_m"] == 42.0
    end

    test "records the manual offset when the marker was dragged", %{conn: conn, user: user} do
      {:ok, pole} =
        Landgrab.create_pole(%{
          barcode: "OFFSET-#{System.unique_integer([:positive])}",
          latitude: 49.89,
          longitude: -97.13,
          accuracy_m: 9.0,
          creator_id: user.id,
          status: "draft"
        })

      body =
        conn
        |> patch("/landgrab/drafts/poles/#{pole.id}", %{"manual_offset_m" => 63.5})
        |> json_response(200)

      assert body["manual_offset_m"] == 63.5
    end

    test "creates an unassigned draft puzzlet with location", %{conn: conn, user: user} do
      body =
        conn
        |> post("/landgrab/drafts/puzzlets", %{
          "instructions" => "What's the colour?",
          "answer" => "red",
          "difficulty" => 3,
          "latitude" => 49.89,
          "longitude" => -97.13,
          "accuracy_m" => 7.4
        })
        |> json_response(201)

      assert body["status"] == "draft"
      assert body["creator_id"] == user.id
      assert body["pole_id"] == nil
      assert body["latitude"] == 49.89
      assert body["longitude"] == -97.13
      assert body["accuracy_m"] == 7.4
    end

    test "lists my drafts", %{conn: conn, user: user} do
      {:ok, _} =
        Landgrab.create_pole(%{
          barcode: "MINE-#{System.unique_integer([:positive])}",
          latitude: 49.89,
          longitude: -97.13,
          creator_id: user.id,
          status: :draft
        })

      body = conn |> get("/landgrab/drafts/mine") |> json_response(200)
      assert length(body["poles"]) >= 1
      assert Enum.all?(body["poles"], &(&1["creator_id"] == user.id))
    end

    test "rejects edits to a validated pole", %{conn: conn, user: user} do
      {:ok, pole} =
        Landgrab.create_pole(%{
          barcode: "VAL-#{System.unique_integer([:positive])}",
          latitude: 49.89,
          longitude: -97.13,
          creator_id: user.id,
          status: :validated
        })

      body =
        conn
        |> patch("/landgrab/drafts/poles/#{pole.id}", %{"label" => "edited"})
        |> json_response(403)

      assert body["error"]["code"] == "forbidden"
    end

    test "rejects edits to someone else's draft", %{conn: conn} do
      stranger = insert(:user, email: "stranger#{System.unique_integer([:positive])}@example.com")

      {:ok, pole} =
        Landgrab.create_pole(%{
          barcode: "OTHERS-#{System.unique_integer([:positive])}",
          latitude: 49.89,
          longitude: -97.13,
          creator_id: stranger.id,
          status: :draft
        })

      body =
        conn
        |> patch("/landgrab/drafts/poles/#{pole.id}", %{"label" => "hijack"})
        |> json_response(403)

      assert body["error"]["code"] == "forbidden"
    end

    test "rejects edits to a validated puzzlet", %{conn: conn, user: user} do
      {:ok, puzzlet} =
        Landgrab.create_puzzlet(%{
          instructions: "i",
          answer: "a",
          difficulty: 1,
          creator_id: user.id,
          status: :validated
        })

      body =
        conn
        |> patch("/landgrab/drafts/puzzlets/#{puzzlet.id}", %{"answer" => "edited"})
        |> json_response(403)

      assert body["error"]["code"] == "forbidden"
    end

    test "rejects edits to someone else's draft puzzlet", %{conn: conn} do
      stranger = insert(:user, email: "stranger#{System.unique_integer([:positive])}@example.com")

      {:ok, puzzlet} =
        Landgrab.create_puzzlet(%{
          instructions: "i",
          answer: "a",
          difficulty: 1,
          creator_id: stranger.id,
          status: :draft
        })

      body =
        conn
        |> patch("/landgrab/drafts/puzzlets/#{puzzlet.id}", %{"answer" => "hijack"})
        |> json_response(403)

      assert body["error"]["code"] == "forbidden"
    end

    test "rejects deletes of a validated pole", %{conn: conn, user: user} do
      {:ok, pole} =
        Landgrab.create_pole(%{
          barcode: "VALD-#{System.unique_integer([:positive])}",
          latitude: 49.89,
          longitude: -97.13,
          creator_id: user.id,
          status: :validated
        })

      body = conn |> delete("/landgrab/drafts/poles/#{pole.id}") |> json_response(403)
      assert body["error"]["code"] == "forbidden"
    end

    test "rejects deletes of a validated puzzlet", %{conn: conn, user: user} do
      {:ok, puzzlet} =
        Landgrab.create_puzzlet(%{
          instructions: "i",
          answer: "a",
          difficulty: 1,
          creator_id: user.id,
          status: :validated
        })

      body = conn |> delete("/landgrab/drafts/puzzlets/#{puzzlet.id}") |> json_response(403)
      assert body["error"]["code"] == "forbidden"
    end

    test "rejects deletes of someone else's draft puzzlet", %{conn: conn} do
      stranger = insert(:user, email: "del-stranger#{System.unique_integer([:positive])}@example.com")

      {:ok, puzzlet} =
        Landgrab.create_puzzlet(%{
          instructions: "i",
          answer: "a",
          difficulty: 1,
          creator_id: stranger.id,
          status: :draft
        })

      body = conn |> delete("/landgrab/drafts/puzzlets/#{puzzlet.id}") |> json_response(403)
      assert body["error"]["code"] == "forbidden"
    end

    test "allows the author to delete their own draft", %{conn: conn, user: user} do
      {:ok, pole} =
        Landgrab.create_pole(%{
          barcode: "DEL-#{System.unique_integer([:positive])}",
          latitude: 49.89,
          longitude: -97.13,
          creator_id: user.id,
          status: :draft
        })

      conn |> delete("/landgrab/drafts/poles/#{pole.id}") |> response(204)
    end

    test "GET /landgrab/drafts/nearby returns puzzlets and poles inside the bounding box",
         %{conn: conn, user: user} do
      # Anchor at Portage & Main-ish; 250m default radius covers roughly
      # ±0.00225° lat and ±0.0035° lng at this latitude.
      {:ok, near_pole} =
        Landgrab.create_pole(%{
          barcode: "NEAR-#{System.unique_integer([:positive])}",
          latitude: 49.895,
          longitude: -97.138,
          creator_id: user.id,
          status: :draft
        })

      {:ok, far_pole} =
        Landgrab.create_pole(%{
          barcode: "FAR-#{System.unique_integer([:positive])}",
          # ~2km south — well outside the 250m radius.
          latitude: 49.875,
          longitude: -97.138,
          creator_id: user.id,
          status: :draft
        })

      {:ok, near_puzzlet} =
        Landgrab.create_puzzlet(%{
          instructions: "near",
          answer: "n",
          difficulty: 2,
          latitude: 49.8952,
          longitude: -97.1378,
          creator_id: user.id,
          status: :draft
        })

      {:ok, _far_puzzlet} =
        Landgrab.create_puzzlet(%{
          instructions: "far",
          answer: "f",
          difficulty: 1,
          latitude: 49.875,
          longitude: -97.138,
          creator_id: user.id,
          status: :draft
        })

      {:ok, _no_location_puzzlet} =
        Landgrab.create_puzzlet(%{
          instructions: "unplaced",
          answer: "u",
          difficulty: 1,
          creator_id: user.id,
          status: :draft
        })

      body =
        conn
        |> get("/landgrab/drafts/nearby?lat=49.895&lng=-97.138")
        |> json_response(200)

      pole_ids = Enum.map(body["poles"], & &1["id"])
      puzzlet_ids = Enum.map(body["puzzlets"], & &1["id"])

      assert near_pole.id in pole_ids
      refute far_pole.id in pole_ids
      assert near_puzzlet.id in puzzlet_ids
      # Puzzlets without a location shouldn't appear even inside the box.
      assert length(body["puzzlets"]) == 1
    end

    test "GET /landgrab/drafts/nearby with a bad lat rejects with 400", %{conn: conn} do
      assert conn
             |> get("/landgrab/drafts/nearby?lat=nope&lng=-97.138")
             |> response(400)
    end
  end
end
