defmodule RegistrationsWeb.Landgrab.EndgameApiTest do
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

  @config %{
    "latitude" => 49.8874,
    "longitude" => -97.1305,
    "starts_at" => "2026-07-25T22:00:00Z",
    "ends_at" => "2026-07-25T23:00:00Z",
    "initial_radius_m" => 2000,
    "final_radius_m" => 100
  }

  describe "as a supervisor" do
    setup ctx do
      supervisor = insert(:user, email: unique_email("super"))
      Accounts.assign_role(supervisor.id, "validation_supervisor")
      %{conn: authed_conn(ctx, supervisor)}
    end

    test "round-trips the configuration", %{conn: conn} do
      assert %{"endgame" => nil, "announced_at" => nil} =
               conn |> get("/landgrab/supervision/endgame") |> json_response(200)

      updated = conn |> put("/landgrab/supervision/endgame", @config) |> json_response(200)
      assert updated["endgame"]["latitude"] == 49.8874
      assert updated["endgame"]["initial_radius_m"] == 2000.0

      fetched = conn |> get("/landgrab/supervision/endgame") |> json_response(200)
      assert fetched["endgame"]["final_radius_m"] == 100.0
    end

    test "clears with all nulls", %{conn: conn} do
      conn |> put("/landgrab/supervision/endgame", @config) |> json_response(200)

      cleared =
        conn
        |> put("/landgrab/supervision/endgame", %{})
        |> json_response(200)

      assert cleared["endgame"] == nil
    end

    test "rejects a partial configuration", %{conn: conn} do
      body =
        conn
        |> put("/landgrab/supervision/endgame", Map.delete(@config, "final_radius_m"))
        |> json_response(422)

      assert body["errors"] != %{}
    end

    test "rejects an end before the start", %{conn: conn} do
      body =
        conn
        |> put("/landgrab/supervision/endgame", %{@config | "ends_at" => "2026-07-25T21:00:00Z"})
        |> json_response(422)

      assert body["errors"]["endgame_ends_at"]
    end
  end

  test "non-supervisors are forbidden", ctx do
    player = insert(:user, email: unique_email("player"))
    conn = authed_conn(ctx, player)

    conn |> get("/landgrab/supervision/endgame") |> json_response(403)
    conn |> put("/landgrab/supervision/endgame", @config) |> json_response(403)
  end
end
