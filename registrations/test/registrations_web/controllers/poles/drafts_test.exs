defmodule RegistrationsWeb.Poles.DraftsTest do
  use RegistrationsWeb.ConnCase

  alias Registrations.Accounts
  alias Registrations.Poles

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
        |> post("/poles/drafts/poles", %{
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
        |> post("/poles/drafts/poles", %{
          "barcode" => "AUTHORED-#{System.unique_integer([:positive])}",
          "latitude" => 49.89,
          "longitude" => -97.13,
          "label" => "Test pole",
          "notes" => "by the bus stop",
          "accuracy_m" => 7.4
        })
        |> json_response(201)

      assert body["status"] == "draft"
      assert body["creator_id"] == user.id
      assert body["accuracy_m"] == 7.4
    end

    test "creates an unassigned draft puzzlet", %{conn: conn, user: user} do
      body =
        conn
        |> post("/poles/drafts/puzzlets", %{
          "instructions" => "What's the colour?",
          "answer" => "red",
          "difficulty" => 3
        })
        |> json_response(201)

      assert body["status"] == "draft"
      assert body["creator_id"] == user.id
      assert body["pole_id"] == nil
    end

    test "lists my drafts", %{conn: conn, user: user} do
      {:ok, _} =
        Poles.create_pole(%{
          barcode: "MINE-#{System.unique_integer([:positive])}",
          latitude: 49.89,
          longitude: -97.13,
          creator_id: user.id,
          status: :draft
        })

      body = conn |> get("/poles/drafts/mine") |> json_response(200)
      assert length(body["poles"]) >= 1
      assert Enum.all?(body["poles"], &(&1["creator_id"] == user.id))
    end

    test "rejects edits to a validated pole", %{conn: conn, user: user} do
      {:ok, pole} =
        Poles.create_pole(%{
          barcode: "VAL-#{System.unique_integer([:positive])}",
          latitude: 49.89,
          longitude: -97.13,
          creator_id: user.id,
          status: :validated
        })

      body =
        conn
        |> patch("/poles/drafts/poles/#{pole.id}", %{"label" => "edited"})
        |> json_response(403)

      assert body["error"]["code"] == "forbidden"
    end

    test "rejects edits to someone else's draft", %{conn: conn} do
      stranger = insert(:user, email: "stranger#{System.unique_integer([:positive])}@example.com")

      {:ok, pole} =
        Poles.create_pole(%{
          barcode: "OTHERS-#{System.unique_integer([:positive])}",
          latitude: 49.89,
          longitude: -97.13,
          creator_id: stranger.id,
          status: :draft
        })

      body =
        conn
        |> patch("/poles/drafts/poles/#{pole.id}", %{"label" => "hijack"})
        |> json_response(403)

      assert body["error"]["code"] == "forbidden"
    end
  end
end
